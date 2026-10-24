# TWRP for the Unihertz Titan 2 (MT6878, GKI 6.1, A/B, vendor_boot recovery).
# SPDX-License-Identifier: GPL-2.0-or-later
DEVICE_PATH := device/unihertz/Titan2

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_SUPPORTS_64_BIT_APPS := true

# Platform
TARGET_BOARD_PLATFORM := mt6878
TARGET_BOOTLOADER_BOARD_NAME := Titan2
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := false

# Kernel: the stock GKI kernel from the user's own boot image (scripts/extract-stock.sh puts it
# into stock/, which is not committed). Only vendor_boot is built; boot stays stock.
TITAN2_STOCK := $(DEVICE_PATH)/prebuilt
# no TARGET_PREBUILT_KERNEL: vendor_boot carries no kernel (and TWRP kernel.mk breaks with a
# prebuilt kernel plus TW_LOAD_VENDOR_MODULES); modules.dep for the ramdisk modules is ours
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_OFFSET := 0x40000000
BOARD_RAMDISK_OFFSET := 0x66f00000
BOARD_KERNEL_TAGS_OFFSET := 0x47c80000
BOARD_DTB_OFFSET := 0x47c80000
BOARD_VENDOR_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE) --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(TITAN2_STOCK)/dtb
BOARD_RAMDISK_USE_LZ4 := true

# Recovery lives in vendor_boot (RECOVERY ramdisk fragment); boot and init_boot stay stock
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_USES_RECOVERY_AS_BOOT :=
TARGET_NO_RECOVERY := true
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 9659482112
BOARD_MAIN_PARTITION_LIST := system system_ext product vendor vendor_dlkm system_dlkm odm_dlkm
BOARD_USES_METADATA_PARTITION := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR := vendor
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# A/B
AB_OTA_UPDATER := true

# AVB: vendor_boot is checked by the stock vbmeta, which our unlocked bootloader ignores
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SUPPRESS_SECURE_ERASE := true

# Android 14 vendor (VNDK 34); recovery props
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# TWRP
TW_THEME := portrait_hdpi
TW_FRAMERATE := 60
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 1600
# no TW_EXTRA_LANGUAGES: its CJK fonts cost ~4 MiB of the LK 64 MiB ramdisk budget (Cyrillic is in Roboto)
TW_DEFAULT_LANGUAGE := en
TW_USE_TOOLBOX := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_FASTBOOTD := true
TW_EXCLUDE_APEX := true
TW_NO_SCREEN_BLANK := true
# the keyboard touchpad reports itself as a touchscreen (ABS_MT, 1440x720): TWRP would take it
# for the screen
TW_INPUT_BLACKLIST := "touchPad"
# MTP over configfs took the whole USB gadget (adb) down; no screen lock while touch is unsure
TW_EXCLUDE_MTP := true
TW_NO_SCREEN_TIMEOUT := true
TW_BACKUP_EXCLUSIONS := /data/fonts
TARGET_USES_MKE2FS := true
TW_HAS_NO_RECOVERY_PARTITION := true
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone0/temp"

# SELinux: permissive in recovery only (see sepolicy/twrp_permissive.te)
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy

# /data decryption: FBE v2 with metadata encryption. KeyMint 3 and Gatekeeper are the TrustKernel
# TEE services of the phone's own vendor partition, started by recovery/root/system/bin/prepdecrypt.sh
# (TWRP runs it before decrypting, patches/bootable_recovery/0001).
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# Libraries TWRP's own recovery list misses for the crypto build (it lists pre-Android 14 names);
# libgatekeeper is for the vendor Gatekeeper (all AOSP, built from source)
TITAN2_RECOVERY_LIBS := \
    libgatekeeper \
    android.system.keystore2-V4-ndk \
    android.hardware.security.keymint-V3-ndk \
    android.hardware.security.rkp-V3-ndk \
    android.hardware.confirmationui-V1-ndk \
    android.security.aaid_aidl-cpp \
    android.system.suspend-V1-ndk \
    android.hardware.gatekeeper-V1-ndk
TARGET_RECOVERY_DEVICE_MODULES += $(TITAN2_RECOVERY_LIBS)
TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(foreach l,$(TITAN2_RECOVERY_LIBS),$(TARGET_OUT_SHARED_LIBRARIES)/$(l).so)
# servicemanager is copied from system with the bootstrap linker path:
# recovery/root/system/bin/bootstrap/linker64 links to the recovery linker

# Not in the stock recovery module list: the main touchscreen (synaptics_tp, in the vendor_boot
# /lib/modules) and the keyboard (aw9523_key with kb_touchpad; synaptics_1403_touch is the keyboard
# touchpad), loaded from the phone's own mounted vendor_dlkm. No module is in our ramdisk.
TW_LOAD_VENDOR_MODULES := "synaptics_tp.ko aw9523_key.ko kb_touchpad.ko synaptics_1403_touch.ko"
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
