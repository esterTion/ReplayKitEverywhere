include $(THEOS)/makefiles/common.mk

ARCHS = arm64 arm64e
TARGET = iphone::9.3:9.0
SYSROOT = $(THEOS)/sdks/iPhoneOS9.3.sd
BUNDLE_NAME = ReplayKitEverywherePrefs
ReplayKitEverywherePrefs_FILES = RKERootListController.m
ReplayKitEverywherePrefs_INSTALL_PATH = /Library/PreferenceBundles
ReplayKitEverywherePrefs_FRAMEWORKS = UIKit
ReplayKitEverywherePrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ReplayKitEverywherePrefs.plist$(ECHO_END)
