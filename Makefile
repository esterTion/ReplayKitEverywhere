include $(THEOS)/makefiles/common.mk

ARCHS = arm64
TARGET = iphone:clang:9.0:9.0
PACKAGE_VERSION = 1.0
TWEAK_NAME = ReplayKitEverywhere
ReplayKitEverywhere_FILES = ReplayKitEverywhere.mm ReplayKitEverywhere_listener.xm
ReplayKitEverywhere_LIBRARIES = activator objcipc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
