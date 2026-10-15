export THEOS ?= $(THEOS)
TARGET := iphone:clang:latest:15.0
# 只编 arm64（thin）：TrollFools 内置 ldid 不支持 fat
ARCHS = arm64
INSTALL_TARGET_PROCESSES = wpsoffice
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = wpsoffline
wpsoffline_FILES = Tweak.x
wpsoffline_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-error
wpsoffline_FRAMEWORKS = UIKit Foundation
include $(THEOS)/makefiles/tweak.mk
