#!/usr/bin/env bash
set -euo pipefail

device_name="${IOS_CI_SIMULATOR_NAME:-BuySell CI iPhone}"
simulator_choice="$(mktemp "${TMPDIR:-/tmp}/buysell-ci-simulator.XXXXXX")"
trap 'rm -f "$simulator_choice"' EXIT

IOS_CI_SIMULATOR_NAME="$device_name" python3 >"$simulator_choice" <<'PY'
import json
import os
import subprocess
import sys

def load_json(*args):
    return json.loads(subprocess.check_output(args, text=True, timeout=90))

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
device_name = os.environ["IOS_CI_SIMULATOR_NAME"]

device_types = load_json("xcrun", "simctl", "list", "devicetypes", "--json").get("devicetypes", [])
preferred_names = ("iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15")
for preferred_name in preferred_names:
    for device_type in device_types:
        if device_type.get("name") == preferred_name:
            try:
                devices = load_json("xcrun", "simctl", "list", "devices", "--json").get("devices", {})
            except Exception:
                devices = {}
            existing_udid = ""
            for device in devices.get(runtime["identifier"], []):
                if device.get("name") == device_name and device.get("isAvailable", True):
                    existing_udid = device.get("udid", "")
                    break
            print(device_type["identifier"], runtime["identifier"], existing_udid)
            raise SystemExit(0)

raise SystemExit("no supported iPhone simulator device type")
PY
read -r device_type runtime_id existing_udid <"$simulator_choice"

udid="$(python3 - "$device_name" "$device_type" "$runtime_id" "${existing_udid:-}" <<'PY'
import subprocess
import sys

device_name, device_type, runtime_id, existing_udid = sys.argv[1:5]
if existing_udid:
    udid = existing_udid
else:
    udid = subprocess.check_output(
        ["xcrun", "simctl", "create", device_name, device_type, runtime_id],
        text=True,
        timeout=60,
    ).strip()

subprocess.run(
    ["xcrun", "simctl", "boot", udid],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    timeout=30,
    check=False,
)

try:
    subprocess.run(
        ["xcrun", "simctl", "bootstatus", udid, "-b"],
        check=True,
        stdout=subprocess.DEVNULL,
        timeout=120,
    )
except subprocess.TimeoutExpired:
    raise SystemExit("timed out waiting for simulator boot")

print(udid)
PY
)"
printf 'id=%s\n' "$udid"
