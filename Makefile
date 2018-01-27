include $(THEOS)/makefiles/common.mk

#DEBUG = 0
#GO_EASY_ON_ME = 1
ARCHS = arm64
TARGET = iphone:clang:9.0:9.0
TWEAK_NAME = ReplayKitEverywhere
ReplayKitEverywhere_FILES = ReplayKitEverywhere.mm ReplayKitEverywhere_listener.xm
ReplayKitEverywhere_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
