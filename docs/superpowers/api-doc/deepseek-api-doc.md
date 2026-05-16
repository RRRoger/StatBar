# DeepSeek API 用量查询接口文档

> 来源：`deepseek_monitor.py` — DeepSeek Monitor 桌面工具

---

## 公共信息

| 项目 | 值 |
|------|-----|
| Base URL | `https://api.deepseek.com` |
| 认证方式 | `Authorization: Bearer {api_key}` |
| Content-Type | `Accept: application/json` |
| 超时时间 | 余额 15s / 用量 10s |

---

## 1. 查询账户余额

### GET `/user/balance`

查询账户的余额信息，支持多币种。

**请求头**

```
Accept: application/json
Authorization: Bearer sk-xxxxxxxxxxxxxxxx
```

**请求示例**

```bash
curl https://api.deepseek.com/user/balance \
  -H "Accept: application/json" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxx"
```

**响应结构**

```json
{
  "is_available": true,
  "balance_infos": [
    {
      "currency": "CNY",
      "total_balance": "100.00",
      "granted_balance": "50.00",
      "topped_up_balance": "50.00"
    },
    {
      "currency": "USD",
      "total_balance": "15.00",
      "granted_balance": "10.00",
      "topped_up_balance": "5.00"
    }
  ]
}
```

**字段说明**

| 字段 | 类型 | 说明 |
|------|------|------|
| `is_available` | boolean | 账户余额是否可用/充足 |
| `balance_infos` | array | 各币种余额列表 |
| `balance_infos[].currency` | string | 货币类型（如 `CNY`、`USD`） |
| `balance_infos[].total_balance` | string | 总余额 |
| `balance_infos[].granted_balance` | string | 赠送余额 |
| `balance_infos[].topped_up_balance` | string | 充值余额 |

**代码位置**: `deepseek_monitor.py:56-63`

```python
def get_balance(self) -> BalanceResponse:
    resp = self.session.get(f"{self.BASE_URL}/user/balance", timeout=15)
    resp.raise_for_status()
    data = resp.json()
    infos = [BalanceInfo(**info) for info in data.get("balance_infos", [])]
    return BalanceResponse(
        is_available=data.get("is_available", False),
        balance_infos=infos
    )
```

---

## 2. 查询本月用量（实验性接口）

### GET `/user/usage`

> ⚠️ 此接口为**非官方文档记录**的接口，通过探测发现，可能随时变更或失效。

查询当前自然月的累计消费金额。

**请求头**

```
Accept: application/json
Authorization: Bearer sk-xxxxxxxxxxxxxxxx
```

**查询参数**

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `start_date` | 否 | 查询起始日期，格式 `YYYY-MM-DD` | `2026-05-01` |

**请求示例**

```bash
curl "https://api.deepseek.com/user/usage?start_date=2026-05-01" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxx"
```

**响应结构**

> 接口返回的具体字段名未确定，代码尝试按优先级匹配以下字段：

```json
{
  "total_cost": 12.34
}
```

**字段匹配优先级**（根级 → 嵌套级）

根级字段，按顺序尝试：
1. `total_cost`
2. `total_amount`
3. `amount`
4. `total_usage`
5. `usage`
6. `cost`

若根级未匹配，则在嵌套对象中继续匹配（按 `data` → `result` → `summary` 顺序）。

**代码位置**: `deepseek_monitor.py:65-95`

```python
def try_fetch_monthly_usage(self) -> Optional[float]:
    now = datetime.datetime.now()
    month_start = now.replace(day=1).strftime("%Y-%m-%d")
    candidates = [
        f"{self.BASE_URL}/user/usage?start_date={month_start}",
        f"{self.BASE_URL}/dashboard/billing/usage",
        f"{self.BASE_URL}/v1/dashboard/billing/usage",
    ]
    for url in candidates:
        try:
            resp = self.session.get(url, timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                cost = (data.get("total_cost") or data.get("total_amount")
                        or data.get("amount") or data.get("total_usage")
                        or data.get("usage") or data.get("cost"))
                if cost is not None:
                    return float(cost)
                # 嵌套检查
                for key in ("data", "result", "summary"):
                    if isinstance(data.get(key), dict):
                        sub = data[key]
                        cost = (sub.get("total_cost") or sub.get("amount")
                                or sub.get("total_amount") or sub.get("cost"))
                        if cost is not None:
                            return float(cost)
            except Exception:
                continue
    return None
```

---

## 备用接口（探测过但未命中）

以下两个 URL 是代码中尝试的备选地址，实际测试时返回 200 的是 `/user/usage`：

| 优先级 | URL | 说明 |
|--------|-----|------|
| 2 | `https://api.deepseek.com/dashboard/billing/usage` | Dashboard 计费接口 |
| 3 | `https://api.deepseek.com/v1/dashboard/billing/usage` | 带版本号的 Dashboard 接口 |

---

## 错误处理

| HTTP 状态码 | 含义 | 工具显示 |
|-------------|------|----------|
| 401 | API Key 无效或未提供 | 提示设置 Key |
| 其他 4xx/5xx | 请求失败 | `HTTP {code}` |
| ConnectionError | 网络不可达 | `网络连接失败` |
| 用量接口非 200 | 接口不可用 | `暂不支持查询` |

---

## Python SDK 封装示例

```python
import requests
import datetime

class DeepSeekClient:
    BASE_URL = "https://api.deepseek.com"

    def __init__(self, api_key: str):
        self.session = requests.Session()
        self.session.headers.update({
            "Accept": "application/json",
            "Authorization": f"Bearer {api_key}"
        })

    def get_balance(self) -> dict:
        """查询余额 ✓ 官方接口"""
        resp = self.session.get(f"{self.BASE_URL}/user/balance", timeout=15)
        resp.raise_for_status()
        return resp.json()

    def get_monthly_usage(self) -> float | None:
        """查询本月用量 ⚠️ 非官方接口"""
        month_start = datetime.datetime.now().replace(day=1).strftime("%Y-%m-%d")
        resp = self.session.get(
            f"{self.BASE_URL}/user/usage",
            params={"start_date": month_start},
            timeout=10
        )
        if resp.status_code != 200:
            return None
        data = resp.json()
        return float(data.get("total_cost") or data.get("total_amount") or 0)
```
