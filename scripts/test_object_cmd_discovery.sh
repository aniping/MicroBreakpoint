#!/usr/bin/env bash
set -euo pipefail

DEBUGGER_URL="${DEBUGGER_URL:-http://127.0.0.1:18601}"
DEMO_URL="${DEMO_URL:-http://127.0.0.1:8080}"

echo "Start a MicroBreakpoint debug session for objectName + cmdName discovery"
curl -sS -X POST "$DEBUGGER_URL/api/sessions" \
  -H "Content-Type: application/json" \
  -d '{"serviceName":"instrument-service-demo","operator":"curl-test","remark":"test objectName + cmdName discovery"}' >/dev/null
curl -sS -X POST "$DEBUGGER_URL/api/debug/start" -H "Content-Type: application/json" -d '{}' >/dev/null

echo "Same Java Demo instType + cmdName, different slotId; Python should show one objectName + cmdName interface"
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=1" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=2" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=3" >/dev/null

echo "Same objectName, different cmdName"
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=start&slotId=1" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=stop&slotId=1" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=reset&slotId=1" >/dev/null

echo "Different objectName, same cmdName"
curl -sS "$DEMO_URL/api/demo/control?instType=SA&cmdName=create&slotId=1" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=SG&cmdName=create&slotId=1" >/dev/null

curl -sS -X POST "$DEBUGGER_URL/api/debug/stop" >/dev/null

echo
echo "Discovered interfaces:"
curl -sS "$DEBUGGER_URL/api/interfaces?page=1&pageSize=100"
echo
echo "期望：Python 已发现接口中 VNA + create 只出现一条，callCount=3 或更多，slotId=1/2/3 在样本或调用记录中可见"
echo "期望：VNA + start、VNA + stop、VNA + reset 分别是不同接口"
echo "期望：SA + create、SG + create 分别是不同接口"
echo "注意：curl 调 Java Demo 使用 instType，但 Python 查询结果应显示 objectName"
