#!/usr/bin/env python3
"""Test DeepSeek API - balance and monthly usage endpoints."""

import requests
import json
import datetime

import os
API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
if not API_KEY:
    print("Set DEEPSEEK_API_KEY environment variable first")
    exit(1)
BASE_URL = "https://api.deepseek.com"

session = requests.Session()
session.headers.update({
    "Accept": "application/json",
    "Authorization": f"Bearer {API_KEY}"
})

# 1. Query balance
print("=== 1. Balance (/user/balance) ===")
try:
    resp = session.get(f"{BASE_URL}/user/balance", timeout=15)
    print(f"HTTP {resp.status_code}")
    data = resp.json()
    print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print(f"Error: {e}")

# 2. Query monthly usage
print("\n=== 2. Monthly Usage (/user/usage) ===")
try:
    month_start = datetime.datetime.now().replace(day=1).strftime("%Y-%m-%d")
    resp = session.get(
        f"{BASE_URL}/user/usage",
        params={"start_date": month_start},
        timeout=10
    )
    print(f"HTTP {resp.status_code}")
    data = resp.json()
    print(json.dumps(data, indent=2, ensure_ascii=False))

    # Try to extract cost
    cost = None
    for key in ("total_cost", "total_amount", "amount", "total_usage", "usage", "cost"):
        if key in data and data[key] is not None:
            cost = float(data[key])
            break
    if cost is None:
        for sub_key in ("data", "result", "summary"):
            if isinstance(data.get(sub_key), dict):
                for key in ("total_cost", "amount", "total_amount", "cost"):
                    if key in data[sub_key] and data[sub_key][key] is not None:
                        cost = float(data[sub_key][key])
                        break
    print(f"\nExtracted cost: {cost}")
except Exception as e:
    print(f"Error: {e}")
