#!/usr/bin/env bash
set -euo pipefail

metadata_file="${1:-${M10_APP_STORE_METADATA:-M10_APP_STORE_METADATA.md}}"
allow_pending="${ALLOW_PENDING_METADATA:-0}"
iphone_screenshot_dir="${M10_APP_STORE_IPHONE_SCREENSHOT_DIR:-${M10_APP_STORE_SCREENSHOT_DIR:-AppStoreAssets/Screenshots/iPhone-16-Pro-Max}}"
iphone_expected_screenshot_width="${M10_APP_STORE_IPHONE_SCREENSHOT_WIDTH:-${M10_APP_STORE_SCREENSHOT_WIDTH:-1320}}"
iphone_expected_screenshot_height="${M10_APP_STORE_IPHONE_SCREENSHOT_HEIGHT:-${M10_APP_STORE_SCREENSHOT_HEIGHT:-2868}}"
ipad_screenshot_dir="${M10_APP_STORE_IPAD_SCREENSHOT_DIR:-AppStoreAssets/Screenshots/iPad-Pro-13-inch-M4}"
ipad_expected_screenshot_width="${M10_APP_STORE_IPAD_SCREENSHOT_WIDTH:-2064}"
ipad_expected_screenshot_height="${M10_APP_STORE_IPAD_SCREENSHOT_HEIGHT:-2752}"
screenshot_capture_test="BuySellAIUITests/testM10AppStoreScreenshotsCanBeCaptured()"
required_screenshots=(
    "01-home.png"
    "02-result.png"
    "03-marketplaces.png"
    "04-listing.png"
)
required_screenshot_count=$(( ${#required_screenshots[@]} * 2 ))
pending_items=()
unconfirmed_metadata_markers=(
    "assumption"
    "assumed"
    "pending"
    "before submission"
    "before final submission"
    "must confirm"
    "needs confirmation"
    "need confirmation"
    "not confirmed"
    "unconfirmed"
    "to confirm"
    "confirm in app store"
    "confirm in app store connect"
)

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

is_placeholder() {
    local value
    local normalized

    value="$(trim "$1")"
    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    case "$normalized" in
        ""|"tbd"|"pending"|"-"|"n/a")
            return 0
            ;;
    esac
    return 1
}

strip_inline_code() {
    local value

    value="$(trim "$1")"
    value="${value#\`}"
    value="${value%\`}"
    printf '%s' "$value"
}

metadata_value() {
    local field="$1"

    awk -F'|' -v field="$field" '
        {
            key = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key == field) {
                value = $3
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' "$metadata_file"
}

pending() {
    pending_items+=("$*")
}

require_value() {
    local field="$1"
    local value

    value="$(metadata_value "$field")"
    if is_placeholder "$value"; then
        pending "metadata '$field' is not recorded"
    fi
}

require_exact() {
    local field="$1"
    local expected="$2"
    local value

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    if [[ "$value" != "$expected" ]]; then
        pending "metadata '$field' is '$value', expected '$expected'"
    fi
}

require_any_term() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" == *"$term"* ]]; then
            return
        fi
    done

    pending "metadata '$field' must mention $label: one of $*"
}

require_terms() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term
    local missing_terms=()

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" != *"$term"* ]]; then
            missing_terms+=("$term")
        fi
    done

    if (( ${#missing_terms[@]} > 0 )); then
        pending "metadata '$field' must mention $label: ${missing_terms[*]}"
    fi
}

require_absent_terms() {
    local field="$1"
    local label="$2"
    shift 2

    local value
    local normalized
    local term

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    for term in "$@"; do
        if [[ "$normalized" == *"$term"* ]]; then
            pending "metadata '$field' must not claim $label without recorded evidence: $term"
        fi
    done
}

require_https_url() {
    local field="$1"
    local value

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    if [[ ! "$value" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
        pending "metadata '$field' must be a full https URL"
    fi
}

require_public_https_url() {
    local field="$1"
    local value
    local status
    local timeout_seconds

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    [[ "$value" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]] || return

    if ! command -v curl >/dev/null 2>&1; then
        pending "metadata '$field' requires curl to verify public URL reachability"
        return
    fi

    timeout_seconds="${M10_METADATA_URL_TIMEOUT:-10}"
    if ! status="$(
        curl -L -sS -o /dev/null -w "%{http_code}" \
            --max-time "$timeout_seconds" \
            "$value" 2>/dev/null
    )"; then
        pending "metadata '$field' must be publicly reachable without authentication"
        return
    fi

    if [[ ! "$status" =~ ^[0-9][0-9][0-9]$ ]] || (( status < 200 || status >= 400 )); then
        pending "metadata '$field' must be publicly reachable without authentication (HTTP $status)"
    fi
}

require_length_at_most() {
    local field="$1"
    local max_bytes="$2"
    local value
    local byte_count

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    byte_count="$(printf '%s' "$value" | wc -c | tr -d '[:space:]')"
    if [[ "$byte_count" -gt "$max_bytes" ]]; then
        pending "metadata '$field' is ${byte_count} bytes, expected <= ${max_bytes}"
    fi
}

require_not_generic_pass() {
    local field="$1"
    local value
    local normalized

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$value")"
    normalized="$(
        sed -E '
            s/^[[:space:]]+|[[:space:]]+$//g
            s/[[:punct:]]+/ /g
            s/[[:space:]]+/ /g
            s/^[[:space:]]+|[[:space:]]+$//g
        ' <<< "$normalized"
    )"
    case "$normalized" in
        "pass"|"passed"|"tested"|"verified"|"done"|"works"|"ok"|"okay"|"all good"|"looks good"|"complete"|"completed")
            pending "metadata '$field' must cite concrete evidence, not '$value'"
            ;;
    esac
}

require_no_unconfirmed_assumption() {
    local field="$1"
    local value
    local normalized
    local marker

    value="$(metadata_value "$field")"
    is_placeholder "$value" && return

    normalized="$(tr '[:upper:]' '[:lower:]' <<< "$(trim "$value")")"
    for marker in "${unconfirmed_metadata_markers[@]}"; do
        if [[ "$normalized" == *"$marker"* ]]; then
            pending "metadata '$field' still contains unconfirmed account-owner/legal wording: $marker"
            return
        fi
    done
}

require_screenshot_assets() {
    local label="$1"
    local directory="$2"
    local expected_width="$3"
    local expected_height="$4"
    local screenshots_value
    local file
    local path
    local format
    local width
    local height

    if ! command -v sips >/dev/null 2>&1; then
        pending "screenshot evidence requires sips to verify PNG dimensions"
        return
    fi

    screenshots_value="$(metadata_value "Screenshots")"

    if ! is_placeholder "$screenshots_value" && [[ "$screenshots_value" != *"$directory"* ]]; then
        pending "metadata 'Screenshots' must reference $label screenshot directory $directory"
    fi

    for file in "${required_screenshots[@]}"; do
        path="${directory%/}/$file"

        if [[ ! -f "$path" ]]; then
            pending "$label screenshot asset is missing at $path"
            continue
        fi

        format="$(sips -g format "$path" 2>/dev/null | awk -F': ' '/format:/ { print $2; exit }')"
        width="$(sips -g pixelWidth "$path" 2>/dev/null | awk -F': ' '/pixelWidth:/ { print $2; exit }')"
        height="$(sips -g pixelHeight "$path" 2>/dev/null | awk -F': ' '/pixelHeight:/ { print $2; exit }')"

        if [[ "$format" != "png" ]]; then
            pending "$label screenshot asset $path is '$format', expected png"
        fi

        if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
            pending "$label screenshot asset $path is ${width:-0}x${height:-0}, expected ${expected_width}x${expected_height}"
        fi

        require_screenshot_visual_quality "$label" "$path"

        if ! is_placeholder "$screenshots_value" && [[ "$screenshots_value" != *"$file"* ]]; then
            pending "metadata 'Screenshots' must reference $label screenshot file $file"
        fi
    done
}

require_screenshot_visual_quality() {
    local label="$1"
    local path="$2"
    local output
    local quality_input
    local sample_path

    quality_input="$path"
    sample_path=""

    if ! command -v python3 >/dev/null 2>&1; then
        pending "$label screenshot asset $path requires python3 for visual quality checks"
        return
    fi

    if command -v sips >/dev/null 2>&1; then
        sample_path="$(mktemp "${TMPDIR:-/tmp}/buysell-screenshot-quality.XXXXXX.png")"
        if sips -Z "${M10_SCREENSHOT_QUALITY_MAX_EDGE:-420}" "$path" --out "$sample_path" >/dev/null 2>&1; then
            quality_input="$sample_path"
        else
            rm -f "$sample_path"
            pending "$label screenshot asset $path could not be downsampled for visual quality check"
            return
        fi
    fi

    if ! output="$(python3 - "$quality_input" <<'PY' 2>&1
import struct
import sys
import zlib

path = sys.argv[1]

def fail(message):
    raise SystemExit(message)

with open(path, "rb") as handle:
    data = handle.read()

if not data.startswith(b"\x89PNG\r\n\x1a\n"):
    fail("not a PNG file")

offset = 8
width = height = bit_depth = color_type = interlace = None
idat = bytearray()

while offset + 8 <= len(data):
    length = struct.unpack(">I", data[offset:offset + 4])[0]
    chunk_type = data[offset + 4:offset + 8]
    chunk_data = data[offset + 8:offset + 8 + length]
    offset += 12 + length

    if chunk_type == b"IHDR":
        width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", chunk_data)
    elif chunk_type == b"IDAT":
        idat.extend(chunk_data)
    elif chunk_type == b"IEND":
        break

if None in (width, height, bit_depth, color_type, interlace):
    fail("PNG header is incomplete")
if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
    fail("unsupported PNG encoding for visual quality check")

channels = 4 if color_type == 6 else 3
bpp = channels
stride = width * channels
raw = zlib.decompress(bytes(idat))
expected = (stride + 1) * height
if len(raw) < expected:
    fail("PNG pixel data is truncated")

def paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c

previous = bytearray(stride)
position = 0
content_pixels = 0
dark_pixel_total = 0
brand_orange_pixels = 0
luminance_total = 0
max_dark_band = 0
current_dark_band = 0
content_threshold = 245 * 10000
dark_threshold = 24 * 10000
brand_orange_threshold = 0.002

for _row_index in range(height):
    filter_type = raw[position]
    position += 1
    row = bytearray(raw[position:position + stride])
    position += stride

    if filter_type == 0:
        pass
    elif filter_type == 1:
        for i in range(bpp, stride):
            row[i] = (row[i] + row[i - bpp]) & 0xFF
    elif filter_type == 2:
        for i, up in enumerate(previous):
            row[i] = (row[i] + up) & 0xFF
    elif filter_type == 3:
        for i, up in enumerate(previous):
            left = row[i - bpp] if i >= bpp else 0
            row[i] = (row[i] + ((left + up) // 2)) & 0xFF
    elif filter_type == 4:
        for i, up in enumerate(previous):
            left = row[i - bpp] if i >= bpp else 0
            upper_left = previous[i - bpp] if i >= bpp else 0
            row[i] = (row[i] + paeth(left, up, upper_left)) & 0xFF
    else:
        fail("unsupported PNG filter")

    row_dark_pixels = 0
    for index in range(0, stride, channels):
        red = row[index]
        green = row[index + 1]
        blue = row[index + 2]
        luminance = (2126 * red) + (7152 * green) + (722 * blue)
        luminance_total += luminance

        if luminance < content_threshold:
            content_pixels += 1
        if luminance < dark_threshold:
            row_dark_pixels += 1
            dark_pixel_total += 1
        if red >= 175 and 45 <= green <= 205 and blue <= 175 and red > green + 22 and red > blue + 50 and green >= blue - 8:
            brand_orange_pixels += 1

    if row_dark_pixels / width > 0.70:
        current_dark_band += 1
        max_dark_band = max(max_dark_band, current_dark_band)
    else:
        current_dark_band = 0

    previous = row

pixel_count = width * height
content_ratio = content_pixels / pixel_count
dark_ratio = dark_pixel_total / pixel_count
brand_orange_ratio = brand_orange_pixels / pixel_count
average_luminance = luminance_total / (pixel_count * 10000)

if content_ratio < 0.015:
    fail("blank or nearly blank screenshot")
if average_luminance < 150:
    fail("screenshot is unexpectedly dark")
if dark_ratio > 0.18:
    fail("screenshot has too many near-black pixels")
if max_dark_band >= 12:
    fail("dark horizontal artifact detected")
if brand_orange_ratio < brand_orange_threshold:
    fail("warm orange brand signal is missing")

print("ok")
PY
    )"; then
        rm -f "$sample_path"
        pending "$label screenshot asset $path failed visual quality check: $output"
        return
    fi

    rm -f "$sample_path"
}

require_screenshot_capture_result() {
    local field="$1"
    local label="$2"
    local result_bundle
    local tests_json

    result_bundle="$(strip_inline_code "$(metadata_value "$field")")"
    if is_placeholder "$result_bundle"; then
        pending "metadata '$field' is not recorded"
        return
    fi

    if [[ ! -d "$result_bundle" ]]; then
        pending "$label screenshot result bundle is missing at $result_bundle"
        return
    fi

    if ! tests_json="$(xcrun xcresulttool get test-results tests --path "$result_bundle" --format json 2>/dev/null)"; then
        pending "$label screenshot result bundle could not be read by xcresulttool"
        return
    fi

    if ! awk -v test_id="\"nodeIdentifier\" : \"${screenshot_capture_test}\"" '
        index($0, test_id) > 0 { found = 1; window = 0 }
        found && /"result" : "Passed"/ { passed = 1; exit }
        found {
            window++
            if (window > 8) {
                exit
            }
        }
        END { exit !(found && passed) }
    ' <<< "$tests_json"; then
        pending "$label screenshot capture test did not pass in $result_bundle"
    fi
}

print_evidence_markers() {
    printf 'file: %s\n' "$metadata_file"
    printf 'app name: %s\n' "$(metadata_value "App name")"
    printf 'bundle id: %s\n' "$(metadata_value "Bundle ID")"
    printf 'version: %s\n' "$(metadata_value "Version number")"
    printf 'privacy policy: %s\n' "$(metadata_value "Privacy Policy URL")"
    printf 'support: %s\n' "$(metadata_value "Support URL")"
    printf 'accessibility url: %s\n' "$(metadata_value "Accessibility URL")"
    printf 'screenshots: %s\n' "$(metadata_value "Screenshots")"
    printf 'legal: %s\n' "$(metadata_value "Account owner legal confirmation")"
    printf 'screenshot sets: iPhone 6.9, iPad 13\n'
    printf 'screenshot directory: %s\n' "$iphone_screenshot_dir"
    printf 'screenshot files: %s\n' "$required_screenshot_count"
    printf 'screenshot dimensions: iPhone 6.9 %sx%s; iPad 13 %sx%s\n' "$iphone_expected_screenshot_width" "$iphone_expected_screenshot_height" "$ipad_expected_screenshot_width" "$ipad_expected_screenshot_height"
    printf 'iphone 6.9 screenshot directory: %s\n' "$iphone_screenshot_dir"
    printf 'iphone 6.9 screenshot dimensions: %sx%s\n' "$iphone_expected_screenshot_width" "$iphone_expected_screenshot_height"
    printf 'ipad 13 screenshot directory: %s\n' "$ipad_screenshot_dir"
    printf 'ipad 13 screenshot dimensions: %sx%s\n' "$ipad_expected_screenshot_width" "$ipad_expected_screenshot_height"
    printf 'screenshot quality: no blank or dark-strip artifacts\n'
    printf 'screenshot brand signal: warm orange present\n'
    printf 'screenshot result bundle: %s\n' "$(strip_inline_code "$(metadata_value "iPhone 6.9 result bundle")")"
    printf 'iphone 6.9 screenshot result bundle: %s\n' "$(strip_inline_code "$(metadata_value "iPhone 6.9 result bundle")")"
    printf 'ipad 13 screenshot result bundle: %s\n' "$(strip_inline_code "$(metadata_value "iPad 13 result bundle")")"
    printf 'screenshot capture test: %s\n' "$screenshot_capture_test"
    printf 'app privacy: %s; tracking: %s\n' "$(metadata_value "App privacy data types")" "$(metadata_value "Data used for tracking")"
    printf 'accessibility labels: %s\n' "$(metadata_value "Accessibility labels")"
    printf 'accessibility evidence: %s\n' "$(metadata_value "Accessibility evidence")"
}

[[ -f "$metadata_file" ]] || fail "missing App Store metadata file at $metadata_file"

required_fields=(
    "App name"
    "Bundle ID"
    "SKU"
    "Primary language"
    "Primary category"
    "Age rating"
    "Made for Kids"
    "DSA trader status"
    "Account owner legal confirmation"
    "License agreement"
    "Version number"
    "Copyright"
    "Subtitle"
    "Description"
    "Keywords"
    "Support URL"
    "Privacy Policy URL"
    "Screenshots"
    "iPhone 6.9 result bundle"
    "iPad 13 result bundle"
    "App Review notes"
    "App privacy data types"
    "Data linked to user"
    "Data used for tracking"
    "Tracking domains"
    "Data use purpose"
    "Account deletion"
    "Export compliance"
    "Accessibility labels"
    "Accessibility URL"
    "Accessibility common tasks"
    "Accessibility evidence"
)

for field in "${required_fields[@]}"; do
    require_value "$field"
    require_not_generic_pass "$field"
done

require_exact "App name" "BuySell AI"
require_exact "Bundle ID" "com.rhodes.buysellai"
require_exact "Made for Kids" "No"
require_exact "Data linked to user" "Yes"
require_exact "Data used for tracking" "No"
require_exact "Tracking domains" "None"
require_exact "Data use purpose" "App Functionality"
require_terms "License agreement" "license agreement" "apple" "standard"
require_terms "Primary category" "primary category" "shopping"
require_any_term "Age rating" "age rating" "4+" "9+" "12+" "17+"
require_any_term "DSA trader status" "Digital Services Act trader status" "trader" "not a trader"
require_terms "Account owner legal confirmation" "account-owner legal confirmation" "app store connect" "account owner" "dsa" "copyright" "age rating" "export compliance"
require_terms "Description" "core product flow" "snap" "photo" "marketplace" "listing"
require_terms "App privacy data types" "App Store privacy data types" "email address" "user id" "photos or videos" "other user content"
require_terms "Account deletion" "in-app account deletion path" "delete account" "settings"
require_terms "Export compliance" "export compliance answer" "itsappusesnonexemptencryption=false" "https"
require_terms "Accessibility labels" "Accessibility Nutrition Labels" "iphone" "ipad" "voiceover" "larger text" "dark interface" "sufficient contrast" "reduced motion" "differentiate without color"
require_absent_terms "Accessibility labels" "unsupported accessibility labels" "voice control"
require_terms "Accessibility common tasks" "common tasks" "first launch" "sign in" "snap" "camera" "result" "marketplace" "listing" "history" "settings" "delete account"
require_terms "Accessibility evidence" "accessibility evidence" "voiceover" "dynamic type" "dark mode" "contrast" "reduce motion" "differentiate without color" "bold text" "reduce transparency" "tap"
require_terms "Screenshots" "screenshot evidence" "screenshot" "iphone" "ipad"
require_terms "App Review notes" "review instructions" "camera" "sign in with apple" "guest" "supabase"
require_https_url "Support URL"
require_https_url "Privacy Policy URL"
require_https_url "Accessibility URL"
require_public_https_url "Support URL"
require_public_https_url "Privacy Policy URL"
require_public_https_url "Accessibility URL"
require_terms "Accessibility URL" "dedicated accessibility page URL" "accessibility"
require_length_at_most "App name" 30
require_length_at_most "Subtitle" 30
require_length_at_most "Keywords" 100
require_no_unconfirmed_assumption "Age rating"
require_no_unconfirmed_assumption "DSA trader status"
require_no_unconfirmed_assumption "Account owner legal confirmation"
require_no_unconfirmed_assumption "Copyright"
require_no_unconfirmed_assumption "Export compliance"
require_screenshot_assets "iPhone 6.9" "$iphone_screenshot_dir" "$iphone_expected_screenshot_width" "$iphone_expected_screenshot_height"
require_screenshot_assets "iPad 13" "$ipad_screenshot_dir" "$ipad_expected_screenshot_width" "$ipad_expected_screenshot_height"
require_screenshot_capture_result "iPhone 6.9 result bundle" "iPhone 6.9"
require_screenshot_capture_result "iPad 13 result bundle" "iPad 13"

if (( ${#pending_items[@]} > 0 )); then
    if [[ "$allow_pending" == "1" ]]; then
        printf 'M10 App Store metadata pending:\n'
        printf ' - %s\n' "${pending_items[@]}"
        printf 'Recorded App Store metadata evidence markers:\n'
        print_evidence_markers
        printf 'Complete the listed App Store Connect metadata items, then rerun without ALLOW_PENDING_METADATA=1.\n'
        exit 0
    fi

    printf 'error: M10 App Store metadata incomplete:\n' >&2
    printf ' - %s\n' "${pending_items[@]}" >&2
    exit 1
fi

printf 'M10 App Store metadata evidence passed\n'
print_evidence_markers
