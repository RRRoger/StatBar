import Foundation
import ScreenCaptureKit

public final class AudioMonitorProvider: NSObject, @unchecked Sendable {
    private let streamOutput: AudioStreamOutput
    nonisolated(unsafe) private var stream: SCStream?

    public override init() {
        streamOutput = AudioStreamOutput()
        super.init()
    }

    public func start() async {
        // Try to get shareable content — this only shows permission dialog once
        // After that, it either works or throws silently
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return }
        guard let display = content.displays.first else { return }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 44100
        config.channelCount = 1
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.width = 2
        config.height = 2
        config.pixelFormat = kCVPixelFormatType_32BGRA

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()
            self.stream = stream
        } catch {
            // Permission denied or other error — silently skip
        }
    }

    public func stop() {
        let s = stream
        stream = nil
        Task.detached { try? await s?.stopCapture() }
    }

    public func currentLevel() -> Float {
        streamOutput.currentLevel
    }

    public func waveform() -> [Float] {
        streamOutput.waveformData
    }
}

final class AudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private(set) var currentLevel: Float = 0
    private(set) var waveformData: [Float] = Array(repeating: 0, count: 12)
    private var sampleIndex: Int = 0
    private let lock = NSLock()

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard sampleBuffer.isValid, sampleBuffer.numSamples > 0 else { return }

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        guard let buffer = buffers.first,
              let data = buffer.mData?.assumingMemoryBound(to: Int16.self) else { return }

        let frameCount = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
        guard frameCount > 0 else { return }

        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = Float(data[i]) / Float(Int16.max)
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))
        let normalized = min(1.0, rms * 3.0)

        lock.lock()
        currentLevel = normalized
        waveformData[sampleIndex % 12] = normalized
        sampleIndex += 1
        lock.unlock()
    }
}
