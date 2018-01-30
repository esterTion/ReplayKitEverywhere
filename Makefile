include $(THEOS)/makefiles/common.mk

#DEBUG = 0
#GO_EASY_ON_ME = 1
ARCHS = arm64
TARGET = iphone::10.1:9.0
TWEAK_NAME = ReplayKitEverywhere rke-replayd
SDKVERSION = 10.1
SYSROOT = $(THEOS)/sdks/iPhoneOS10.1.sdk
ReplayKitEverywhere_FILES = ReplayKitEverywhere.mm ReplayKitEverywhere_listener.xm
ReplayKitEverywhere_LIBRARIES = activator rocketbootstrap
ReplayKitEverywhere_FRAMEWORKS = ReplayKit
ReplayKitEverywhere_PRIVATE_FRAMEWORKS = AppSupport BulletinBoard
rke-replayd_FILES = rke-replayd.xm
rke-replayd_FRAMEWORKS = AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
