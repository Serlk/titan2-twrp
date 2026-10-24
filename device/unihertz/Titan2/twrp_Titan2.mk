# TWRP for the Unihertz Titan 2.
# SPDX-License-Identifier: GPL-2.0-or-later

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/unihertz/Titan2/device.mk)

PRODUCT_DEVICE := Titan2
PRODUCT_NAME := twrp_Titan2
PRODUCT_BRAND := Unihertz
PRODUCT_MODEL := Titan 2
PRODUCT_MANUFACTURER := Unihertz
