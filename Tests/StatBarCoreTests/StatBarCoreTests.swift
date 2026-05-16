import Foundation
import Testing
@testable import StatBarCore

@Test func menuTitleUsesRoundedWholePercentages() {
    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 22.6),
        memory: MemoryMetrics(usedBytes: 65, totalBytes: 100)
    )

    #expect(StatBarFormatter().menuTitle(for: snapshot) == "C 23% M 65%")
}

@Test func percentValuesAreClamped() {
    #expect(CPUMetrics(usage: -4).usage == 0)
    #expect(CPUMetrics(usage: 104).usage == 100)
}

@Test func memoryUsageHandlesZeroTotal() {
    let memory = MemoryMetrics(usedBytes: 20, totalBytes: 0)

    #expect(memory.usage == 0)
}

@Test func memoryUsageComputesPercentOfTotal() {
    let memory = MemoryMetrics(usedBytes: 3, totalBytes: 4)

    #expect(memory.usage == 75)
}

@Test func cpuUsageCalculatorUsesDeltaExcludingIdleTicks() {
    let previous = CPUTickSample(user: 100, system: 50, idle: 850, nice: 0)
    let current = CPUTickSample(user: 150, system: 100, idle: 900, nice: 0)

    let usage = CPUUsageCalculator().usage(previous: previous, current: current)

    #expect(abs(usage - 66.666) < 0.01)
}

@Test func cpuUsageCalculatorHandlesUnchangedSamples() {
    let sample = CPUTickSample(user: 10, system: 20, idle: 30, nice: 40)

    #expect(CPUUsageCalculator().usage(previous: sample, current: sample) == 0)
}

@Test func byteFormatterUsesReadableUnits() {
    let text = StatBarFormatter().bytesText(1_073_741_824)

    #expect(text.contains("1"))
    #expect(text.localizedCaseInsensitiveContains("GB"))
}
