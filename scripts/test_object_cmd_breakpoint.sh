#!/usr/bin/env bash
set -euo pipefail

DEBUGGER_URL="${DEBUGGER_URL:-http://127.0.0.1:18601}"
DEMO_URL="${DEMO_URL:-http://127.0.0.1:8080}"

cleanup() {
  curl -sS -X POST "$DEBUGGER_URL/api/calls/continue-all" >/dev/null || true
  curl -sS -X POST "$DEBUGGER_URL/api/debug/stop" >/dev/null || true
}
trap cleanup EXIT

echo "Seed VNA/create and VNA/start calls"
curl -sS -X POST "$DEBUGGER_URL/api/sessions" \
  -H "Content-Type: application/json" \
  -d '{"serviceName":"instrument-service-demo","operator":"curl-test","remark":"test objectName + cmdName breakpoint"}' >/dev/null
curl -sS -X POST "$DEBUGGER_URL/api/debug/start" -H "Content-Type: application/json" -d '{}' >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=1" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=2" >/dev/null
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=start&slotId=1" >/dev/null
curl -sS -X POST "$DEBUGGER_URL/api/debug/stop" >/dev/null

INTERFACE_ID=$(curl -sS "$DEBUGGER_URL/api/interfaces?page=1&pageSize=100" | python -c "import json,sys; data=json.load(sys.stdin); print(next((i.get('id','') for i in data.get('items',[]) if i.get('object_name')=='VNA' and i.get('cmd_name')=='create'), ''))")
if [[ -z "$INTERFACE_ID" ]]; then
  echo "未找到 VNA + create 的 interfaceId，请检查 /api/interfaces 输出"
  exit 1
fi
echo "InterfaceId: $INTERFACE_ID"

BP_ID=$(curl -sS -X POST "$DEBUGGER_URL/api/interfaces/$INTERFACE_ID/breakpoint" \
  -H "Content-Type: application/json" \
  -d '{"name":"BP VNA create","enabled":true,"hitMode":"always"}' \
  | python -c "import json,sys; print(json.load(sys.stdin).get('breakpointId',''))")

echo "Start debug and verify interface-level breakpoint hits slotId=1 and slotId=2"
curl -sS -X POST "$DEBUGGER_URL/api/debug/start" -H "Content-Type: application/json" -d '{}' >/dev/null

curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=1" &
sleep 1
curl -sS "$DEBUGGER_URL/api/calls?status=paused&page=1&pageSize=20"
echo
curl -sS -X POST "$DEBUGGER_URL/api/calls/continue-all" >/dev/null

curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=2" &
sleep 1
curl -sS "$DEBUGGER_URL/api/calls?status=paused&page=1&pageSize=20"
echo
curl -sS -X POST "$DEBUGGER_URL/api/calls/continue-all" >/dev/null

echo "VNA + start should not hit BP VNA create"
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=start&slotId=1" >/dev/null

if [[ -n "$BP_ID" ]]; then
  curl -sS -X POST "$DEBUGGER_URL/api/breakpoints/$BP_ID/disable" >/dev/null
fi

CALL_ID=$(curl -sS "$DEBUGGER_URL/api/calls?page=1&pageSize=100" | python -c "import json,sys; data=json.load(sys.stdin); print(next((c.get('call_id','') for c in data.get('items',[]) if c.get('object_name')=='VNA' and c.get('cmd_name')=='create' and c.get('slot_id')==1), ''))")
if [[ -z "$CALL_ID" ]]; then
  echo "未找到 VNA + create + slotId=1 的 callId，请检查 /api/calls 输出"
  exit 1
fi

echo "Create sample-level params snapshot breakpoint from callId=$CALL_ID"
curl -sS -X POST "$DEBUGGER_URL/api/calls/$CALL_ID/breakpoint" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"matchMode":"params_snapshot","hitMode":"always"}' >/dev/null

curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=1" &
sleep 1
curl -sS "$DEBUGGER_URL/api/calls?status=paused&page=1&pageSize=20"
echo
curl -sS -X POST "$DEBUGGER_URL/api/calls/continue-all" >/dev/null

echo "slotId=2 should not hit the sample-level slotId=1 breakpoint"
curl -sS "$DEMO_URL/api/demo/control?instType=VNA&cmdName=create&slotId=2" >/dev/null

echo "期望：接口级断点命中 VNA + create 的 slotId=1/2；样本级断点只命中 slotId=1"
