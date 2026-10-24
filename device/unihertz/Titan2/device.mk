# SPDX-License-Identifier: GPL-2.0-or-later
LOCAL_PATH := device/unihertz/Titan2

# A/B with Virtual A/B on dynamic partitions
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
PRODUCT_USE_DYNAMIC_PARTITIONS := true
ENABLE_VIRTUAL_AB := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot init_boot vendor_boot dtbo vbmeta vbmeta_system vbmeta_vendor \
    system system_ext product vendor vendor_dlkm system_dlkm odm_dlkm

# fastbootd in recovery
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

PRODUCT_PROPERTY_OVERRIDES += \
    ro.twrp.vendor_boot=true

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)
