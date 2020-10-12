include $(THEOS)/makefiles/common.mk

#DEBUG = 0
#GO_EASY_ON_ME = 1
ARCHS = arm64 arm64e
TARGET = iphone::11.2:9.0
TWEAK_NAME = ReplayKitEverywhere rke-replayd RKE-loader
SDKVERSION = 11.2
SYSROOT = $(THEOS)/sdks/iPhoneOS11.2.sdk
ReplayKitEverywhere_CFLAGS = -fobjc-arc
ReplayKitEverywhere_FILES = ReplayKitEverywhere_listener.xm
ReplayKitEverywhere_LIBRARIES = activator rocketbootstrap
ReplayKitEverywhere_FRAMEWORKS = ReplayKit
ReplayKitEverywhere_PRIVATE_FRAMEWORKS = PhotoLibraryServices BulletinBoard
rke-replayd_CFLAGS = -fobjc-arc
rke-replayd_FILES = rke-replayd.xm
rke-replayd_FRAMEWORKS = AVFoundation
RKE-loader_CFLAGS = -fobjc-arc
RKE-loader_FILES = RKE-loader.xm
RKE-loader_FRAMEWORKS = Foundation


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
SUBPROJECTS += replaykiteverywhereprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
