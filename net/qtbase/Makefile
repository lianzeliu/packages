#
# Copyright (C) 2019-2021
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qtbase
PKG_BASE:=5.15
PKG_BUGFIX:=2
PKG_VERSION:=$(PKG_BASE).$(PKG_BUGFIX)
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-everywhere-src-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:= \
		http://download.qt.io/official_releases/qt/$(PKG_BASE)/$(PKG_VERSION)/submodules \
		http://master.qt.io/archive/qt/$(PKG_BASE)/$(PKG_VERSION)/submodules
PKG_HASH:=909fad2591ee367993a75d7e2ea50ad4db332f05e1c38dd7a5a274e156a4e0f8

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-everywhere-src-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0
PKG_CPE_ID:=cpe:/a:qt:qt

# Force to use strip instead of sstrip
STRIP:=$(TARGET_CROSS)strip $(call qstrip,$(CONFIG_STRIP_ARGS))

include $(INCLUDE_DIR)/package.mk

define Package/qtbase/Default
  SECTION:=libs
  CATEGORY:=Libraries
  SUBMENU:=Qt5
  TITLE:=qtbase
  URL:=http://qt-project.org
  DEPENDS:=+libc +libgcc +libstdcpp \
		+USE_GLIBC:librt +USE_GLIBC:libpthread \
		@!LINUX_2_6_36
endef

define Package/qtbase/description
  This package provides the Qt5 libraries.

  Qt is a cross-platform application development framework for desktop, embedded and mobile.
  Supported Platforms include Linux, OS X, Windows, VxWorks, QNX, Android, iOS, BlackBerry,
  Sailfish OS and others.

  Qt is not a programming language on its own. It is a framework written in C++.

  This package provides the following run-time libraries:
  - core
  - network
  - xml
  - sql
endef

define Package/qtbase
  $(call Package/qtbase/Default)
  HIDDEN:=1
endef

define Package/qtbase/config
menu "qtbase"
	config QT5_INCLUDE_ATOMIC
		bool "Depends on libatomic"
		default y if !(arm_v7 || ARCH_64BIT || TARGET_x86)
		default n
		help
		Check this options to add the libatomic to the dependences.
		- You'd better to confirm whether your compiler need the external libatomic.
		  Otherwise, it is not recommended to modify this option mannually.

	comment "Qtbase Libraries"

	$(foreach lib,$(QTBASE_LIBS),
	config PACKAGE_libqt5$(lib)
		tristate "libqt5$(lib)"
		default m if ALL
		help
		$(Package/libqt5$(lib)/description)
	)
endmenu
endef

PKG_CONFIG_DEPENDS = CONFIG_QT5_INCLUDE_ATOMIC

ifdef CONFIG_USE_GLIBC
  EXTRA_LDFLAGS += -ldl -lrt -lpthread
endif

EXTRA_CFLAGS += $(FPIC) -ffunction-sections -fdata-sections -flto
EXTRA_LDFLAGS += -Wl,--gc-sections,--as-needed

CONFIGURE_ARGS = \
		-sysroot $(STAGING_DIR) \
		-hostprefix $(STAGING_DIR_HOSTPKG) \
		-extprefix $(STAGING_DIR)/usr \
		-prefix /usr \
		-archdatadir /usr/share/Qt5 \
		-datadir /usr/share/Qt5 \
		-device linux-generic-g++ \
		-device-option CROSS_COMPILE="$(TARGET_CROSS)" \
		-device-option COMPILER_FLAGS="$(TARGET_CFLAGS) $(EXTRA_CFLAGS) $(TARGET_CPPFLAGS) $(EXTRA_CPPFLAGS)" \
		-device-option LINKER_FLAGS="$(TARGET_LDFLAGS) $(EXTRA_LDFLAGS)" \
		-confirm-license \
		-opensource \
		-release \
		-shared \
		-optimize-size \
		-strip \
		-no-rpath \
		-no-use-gold-linker \
		-ltcg \
		-system-zlib \
		$(if $(findstring i386,$(ARCH)),-no-sse2 -no-sse4.1) \
		-no-cups \
		-no-dbus \
		-no-libudev \
		-no-pch \
		-no-widgets \
		-no-zstd \
		-no-compile-examples \
		-no-feature-concurrent \
		-no-feature-testlib \
		-make libs \
		-nomake examples \
		-nomake tests \
		-nomake tools \
		\
		-qt-doubleconversion \
		-system-pcre \
		-no-iconv \
		-mimetype-database \
		-no-glib \
		-no-icu \
		-no-slog2 \
		-no-trace \
		\
		-no-gui \
		-no-angle \
		-no-freetype \
		-no-gbm \
		-no-harfbuzz \
		-no-libjpeg \
		-no-libmd4c \
		-no-libpng \
		-no-mtdev \
		-no-opengl \
		-no-openvg \
		-no-tslib \
		-no-vulkan \
		-no-xcb \
		-no-xkbcommon \
		\
		$(if $(CONFIG_PACKAGE_libqt5network),,-no-feature-network) \
		-openssl-linked \
		-no-dtls\
		-no-feature-gssapi \
		\
		$(if $(CONFIG_PACKAGE_libqt5sql),-qt-sqlite,-no-feature-sql -no-sqlite) \
		-no-sql-db2 \
		-no-sql-ibase \
		-no-sql-mysql \
		-no-sql-oci \
		-no-sql-odbc \
		-no-sql-psql \
		-no-sql-sqlite2 \
		-no-sql-tds \
		\
		$(if $(CONFIG_PACKAGE_libqt5xml),,-no-feature-xml) \
		\
		-v

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)
endef

define Build/InstallDev
	$(MAKE) -C $(PKG_BUILD_DIR) install
endef

define Package/qtbase/Default/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/lib/libQt5$(shell echo $(2) | sed -e 's/\b[[:alpha:]]/\u&/g').so* $(1)/usr/lib
endef

# 1: library short name
# 2: dependencies on other qtbase libraries (short name)
# 3: dependencies on other packages
define DefineQtbaseLibrary
  PKG_CONFIG_DEPENDS+=CONFIG_PACKAGE_libqt5$(1)
  QTBASE_LIBS+=$(1)

  define Package/libqt5$(1)
    $(call Package/qtbase/Default)
    TITLE+=$(1) library
    DEPENDS+=$(foreach lib,$(2),+libqt5$(lib)) $(3)
    ABI_VERSION:=5
    HIDDEN:=1
  endef

  define Package/libqt5$(1)/description
    This package contains the qtbase $(1) library.
  endef

  define Package/libqt5$(1)/install
    $(call Package/qtbase/Default/install,$$(1),$(1))
  endef
endef

$(eval $(call DefineQtbaseLibrary,core,,+QT5_INCLUDE_ATOMIC:libatomic +libpcre2-16 +zlib))
$(eval $(call DefineQtbaseLibrary,network,core,+libopenssl +zlib))
$(eval $(call DefineQtbaseLibrary,xml,core,))
$(eval $(call DefineQtbaseLibrary,sql,core,))

define Package/qtbase/Plugins/install
	$(INSTALL_DIR) $(1)/usr/share/Qt5/plugins/$(2)
	$(CP) $(PKG_BUILD_DIR)/plugins/$(2)/lib$(3).so $(1)/usr/share/Qt5/plugins/$(2)
endef

# 1: plugin directory
# 2: plugin short name
# 3: so file name
# 4: dependencies on other qtbase libraries (short name)
# 5: dependencies on other packages
define DefineQtbasePlugin
  $(call DefineQtbaseLibrary,$(2),$(4),$(5))

  define Package/libqt5$(2)/install
    $(call Package/qtbase/Plugins/install,$$(1),$(1),$(3))
  endef
endef

$(eval $(call DefineQtbasePlugin,sqldrivers,sql-sqlite,qsqlite,core sql,\
	+QT5_SYSTEM_PCRE2:libpcre2-16 +QT5_SYSTEM_ZLIB:zlib))

$(foreach lib,$(QTBASE_LIBS),$(eval $(call BuildPackage,libqt5$(lib))))
$(eval $(call BuildPackage,qtbase))
