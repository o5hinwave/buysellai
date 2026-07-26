#!/usr/bin/env bash
set -euo pipefail

device_name="${IOS_CI_SIMULATOR_NAME:-BuySell CI iPhone}"

read -r device_type runtime_id < <(python3 <<'PY'
import json
import subprocess
import sys

def load_json(*args):
    return json.loads(subprocess.check_output(args, text=True))

runtimes = [
    runtime
    for runtime in load_json("xcrun", "simctl", "list", "runtimes", "--json").get("runtimes", [])
    if runtime.get("platform") == "iOS" and runtime.get("isAvailable", False)
]
if not runtimes:
    raise SystemExit("no available iOS simulator runtime")

def version_key(runtime):
    version = str(runtime.get("version", "0"))
    return tuple(int(part) if part.isdigit() else 0 for part in version.split("."))

runtime = sorted(runtimes, key=version_key)[-1]

device_types = load_json("xcrun", "simctl", "list", "devicetypes", "--json").get("devicetypes", [])
preferred_names = ("iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15")
for preferred_name in preferred_names:
    for device_type in device_types:
        if device_type.get("name") == preferred_name:
            print(device_type["identifier"], runtime["identifier"])
            raise SystemExit(0)

raise SystemExit("no supported iPhone simulator device type")
PY
)

udid="$(xcrun simctl create "$device_name" "$device_type" "$runtime_id")"
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b >/dev/null
printf 'id=%s\n' "$udid"
