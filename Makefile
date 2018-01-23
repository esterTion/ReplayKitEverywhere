include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ReplayKitEverywhere
ReplayKitEverywhere_FILES = ReplayKitEverywhere.mm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
