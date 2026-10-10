#!/bin/bash
#
# Copyright (C) 2019-2026 crDroid Android Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
#

# $1 = TARGET_DEVICE
# $2 = PRODUCT_OUT
# $3 = FILE_NAME

DEVICE="$1"
PRODUCT_OUT="$2"
FILENAME="$3"

# Detect build variant
if [[ "${FILENAME,,}" == *"vanilla"* ]]; then
    BUILD_VARIANT="vanilla"
else
    BUILD_VARIANT="gapps"
fi

# Set OTA json location
if [[ "$BUILD_VARIANT" == "vanilla" ]]; then
    existingOTAjson="./vendor/OTA/builds/vanilla/${DEVICE}.json"
else
    existingOTAjson="./vendor/OTA/builds/${DEVICE}.json"
fi

output="${PRODUCT_OUT}/${DEVICE}.json"

# Cleanup old file
if [ -f "$output" ]; then
    rm "$output"
fi

echo "Generating JSON file data for OTA support..."

# Helper function to extract field from JSON
extract_field() {
    grep "\"$1\":" "$existingOTAjson" \
        | sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" \
        | xargs
}

# Load existing OTA metadata if present
if [ -f "$existingOTAjson" ]; then
    MAINTAINER=$(extract_field "maintainer")
    OEM=$(extract_field "oem")
    DEVICE_NAME=$(extract_field "device")
    BUILDTYPE=$(extract_field "buildtype")
    FORUM=$(extract_field "forum")
    GAPPS=$(extract_field "gapps")
    FIRMWARE=$(extract_field "firmware")
    MODEM=$(extract_field "modem")
    BOOTLOADER=$(extract_field "bootloader")
    RECOVERY=$(extract_field "recovery")
    PAYPAL=$(extract_field "paypal")
    TELEGRAM=$(extract_field "telegram")
    DT=$(extract_field "dt")
    COMMON_DT=$(extract_field "common-dt")
    KERNEL=$(extract_field "kernel")
fi

# Build information
BUILDPROP="$PRODUCT_OUT/system/build.prop"
TIMESTAMP=$(grep "ro.system.build.date.utc" "$BUILDPROP" | cut -d'=' -f2)
OS_PATCH_LEVEL=$(grep -m1 "^ro.build.version.security_patch=" "$BUILDPROP" | cut -d'=' -f2)
OS_SDK_LEVEL=$(grep -m1 "^ro.build.version.sdk=" "$BUILDPROP" | cut -d'=' -f2)

# Extract version robustly from build.prop or filename
VERSION=$(grep -h -m1 "^ro.lunaris.build.version=" "$PRODUCT_OUT/product/etc/build.prop" "$BUILDPROP" 2>/dev/null | cut -d'=' -f2)
if [ -z "$VERSION" ]; then
    RAW_VER=$(echo "$FILENAME" | cut -d'-' -f5 | sed 's/v//')
    V_MAX=$(echo "$RAW_VER" | cut -d'.' -f1)
    V_MIN=$(echo "$RAW_VER" | cut -d'.' -f2)
    VERSION="$V_MAX.$V_MIN"
fi

HF_REPO="MotoTaper/Lunaris-AOSP-Private-OTA"
DOWNLOAD_URL="https://huggingface.co/datasets/${HF_REPO}/resolve/main/${FILENAME}"

MD5=$(md5sum "$PRODUCT_OUT/$FILENAME" | cut -d' ' -f1)
SHA256=$(sha256sum "$PRODUCT_OUT/$FILENAME" | cut -d' ' -f1)
SIZE=$(stat -c "%s" "$PRODUCT_OUT/$FILENAME")

# Generate JSON
cat <<EOF >"$output"
{
  "response": [
    {
      "maintainer": "${MAINTAINER:-Xiaomi-13T-Hype | モトテーパー}",
      "oem": "${OEM:-Xiaomi}",
      "device": "${DEVICE_NAME:-$DEVICE}",
      "filename": "$FILENAME",
      "download": "$DOWNLOAD_URL",
      "timestamp": $TIMESTAMP,
      "md5": "$MD5",
      "sha256": "$SHA256",
      "size": $SIZE,
      "version": "$VERSION",
      "os_patch_level": "${OS_PATCH_LEVEL:-}",
      "os_sdk_level": ${OS_SDK_LEVEL:-0},
      "buildtype": "${BUILDTYPE:-Official}",
      "forum": "${FORUM:-https://github.com/Xiaomi-13T-Hype/android_device_xiaomi_vayu/issues}",
      "gapps": "${GAPPS:-}",
      "firmware": "${FIRMWARE:-}",
      "modem": "${MODEM:-}",
      "bootloader": "${BOOTLOADER:-}",
      "recovery": "${RECOVERY:-}",
      "paypal": "${PAYPAL:-https://www.tbank-online.com/rm/r_bfmwbAMMTz.WSlHwfDIiR/aJY3777024/}",
      "telegram": "${TELEGRAM:-https://t.me/+aErhUEdrIkY4YWY6}",
      "dt": "${DT:-https://github.com/Xiaomi-13T-Hype/android_device_xiaomi_vayu}",
      "common-dt": "${COMMON_DT:-https://github.com/Xiaomi-13T-Hype/android_device_xiaomi_sm8150-common}",
      "kernel": "${KERNEL:-https://github.com/Xiaomi-13T-Hype/android_kernel_xiaomi_sm8150}"
    }
  ]
}
EOF

# Upload ROM ZIP to Hugging Face CDN
HF_BIN=""
for candidate in \
    "/home/Ximi/.local/share/pipx/venvs/huggingface-hub/bin/hf" \
    "/home/Ximi/.local/bin/hf" \
    "/usr/local/bin/hf"; do
    if [ -x "$candidate" ]; then
        HF_BIN="$candidate"
        break
    fi
done

# Configure writable cache and storage for Hugging Face & git in nsjail sandbox
# In Android build sandbox, / (including /home/Ximi) is mounted read-only; only /tmp and $PRODUCT_OUT are writable
export HF_HOME="${PRODUCT_OUT}/.hf_home"
export XDG_CACHE_HOME="${PRODUCT_OUT}/.cache"
export TMPDIR="/tmp"
mkdir -p "$HF_HOME" "$XDG_CACHE_HOME"

# Extract HF token from host cache if not present in environment
if [ -z "$HF_TOKEN" ]; then
    for token_candidate in \
        "$HOME/.cache/huggingface/token" \
        "/home/Ximi/.cache/huggingface/token"; do
        if [ -f "$token_candidate" ]; then
            export HF_TOKEN="$(cat "$token_candidate" 2>/dev/null)"
            break
        fi
    done
fi
if [ -n "$HF_TOKEN" ]; then
    echo "$HF_TOKEN" > "$HF_HOME/token"
fi

# Autodetect proxy for fallback
DETECTED_HTTP_PROXY=""
if [ -n "$HTTPS_PROXY" ]; then
    DETECTED_HTTP_PROXY="$HTTPS_PROXY"
elif [ -n "$https_proxy" ]; then
    DETECTED_HTTP_PROXY="$https_proxy"
elif (echo > /dev/tcp/127.0.0.1/10809) >/dev/null 2>&1; then
    DETECTED_HTTP_PROXY="http://127.0.0.1:10809"
fi

if [ -n "$HF_BIN" ] && [ -f "$PRODUCT_OUT/$FILENAME" ]; then
    echo "========================================================================"
    echo "Uploading $FILENAME to Hugging Face CDN ($HF_REPO)..."
    echo "========================================================================"
    MAX_RETRIES=3
    UPLOAD_SUCCESS=0
    for attempt in $(seq 1 $MAX_RETRIES); do
        echo "[*] Hugging Face upload attempt $attempt of $MAX_RETRIES..."
        if [ $attempt -eq 1 ] || [ -z "$DETECTED_HTTP_PROXY" ]; then
            UPLOAD_CMD=(env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY "$HF_BIN" upload --repo-type dataset "$HF_REPO" "$PRODUCT_OUT/$FILENAME" "$FILENAME")
        else
            UPLOAD_CMD=(env HTTP_PROXY="$DETECTED_HTTP_PROXY" HTTPS_PROXY="$DETECTED_HTTP_PROXY" "$HF_BIN" upload --repo-type dataset "$HF_REPO" "$PRODUCT_OUT/$FILENAME" "$FILENAME")
        fi
        if "${UPLOAD_CMD[@]}"; then
            echo "[+] Upload to Hugging Face successful!"
            UPLOAD_SUCCESS=1
            break
        fi
        echo "[-] Attempt $attempt failed. Retrying in 4 seconds..."
        sleep 4
    done
    if [ $UPLOAD_SUCCESS -ne 1 ]; then
        echo "[-] Warning: Failed to upload ROM ZIP to Hugging Face after $MAX_RETRIES attempts." >&2
    fi
fi

# Automatically update and push to vendor/OTA repository
if [ -d "./vendor/OTA/.git" ]; then
    echo "Synchronizing and pushing OTA updates to GitHub..."
    cp "$output" "$existingOTAjson"
    git -C "./vendor/OTA" add builds/ changelogs/
    git -C "./vendor/OTA" commit -m "OTA: Update ${DEVICE} (${FILENAME})" || true
    
    # Prepare writable git credentials copy for nsjail sandbox
    GIT_CRED_OPT=()
    if [ -f "$HOME/.git-credentials" ]; then
        cp -f "$HOME/.git-credentials" /tmp/git-credentials 2>/dev/null && chmod 600 /tmp/git-credentials 2>/dev/null || true
        GIT_CRED_OPT=(-c credential.helper= -c credential.helper="store --file /tmp/git-credentials")
    elif [ -f "/home/Ximi/.git-credentials" ]; then
        cp -f "/home/Ximi/.git-credentials" /tmp/git-credentials 2>/dev/null && chmod 600 /tmp/git-credentials 2>/dev/null || true
        GIT_CRED_OPT=(-c credential.helper= -c credential.helper="store --file /tmp/git-credentials")
    fi

    PUSH_SUCCESS=0
    for proxy_opt in "http://127.0.0.1:10809" "socks5h://127.0.0.1:10808" ""; do
        CMD=(git -C "./vendor/OTA" "${GIT_CRED_OPT[@]}" -c http.proxy="$proxy_opt" push origin main)
        if "${CMD[@]}"; then
            PUSH_SUCCESS=1
            break
        fi
        sleep 2
    done
    if [ $PUSH_SUCCESS -eq 1 ]; then
        echo "OTA metadata successfully pushed to GitHub!"
    else
        echo "Warning: Failed to push to vendor/OTA" >&2
    fi
elif [ -d "$(dirname "$existingOTAjson")" ]; then
    cp "$output" "$existingOTAjson"
    echo "Synchronized JSON to $existingOTAjson"
fi

if [ ! -f "$existingOTAjson" ]; then
    echo "There is no official support for this device yet"
fi

echo "JSON file generation completed"
