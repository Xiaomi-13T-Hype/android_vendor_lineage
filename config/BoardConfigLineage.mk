# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# Recovery
BOARD_USES_FULL_RECOVERY_IMAGE ?= true

include vendor/lineage/config/BoardConfigKernel.mk

ifeq ($(BOARD_USES_QCOM_HARDWARE),true)
    include hardware/qcom-caf/common/BoardConfigQcom.mk
endif

include vendor/lineage/config/BoardConfigSoong.mk

# Allow network access in build sandbox for OTA metadata push and HF upload
BUILD_BROKEN_USES_NETWORK := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
