TARGET = iphone:clang:latest:6.0
ARCHS = armv7
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = Treble
Treble_FILES = main.m TBStore.m TBPlayer.m TBTheme.m Screens.m
Treble_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AudioToolbox MediaPlayer CoreMedia
Treble_CFLAGS = -fobjc-arc
Treble_USE_MODULES = 0
Treble_LDFLAGS = -Wl,-ld_classic
include $(THEOS_MAKE_PATH)/application.mk
