# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=rustdesk-s
PKG_VERSION:=1.1.16
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/lianzeliu/rustdesk-server.git
PKG_SOURCE_VERSION:=openwrt-1.1.16

PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>
PKG_LICENSE:=AGPL-3.0-only
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=rust/host
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

define Package/rustdesk-s
  SECTION:=net
  CATEGORY:=Network
  TITLE:=RustDesk Server Program
  DEPENDS:=@(aarch64||arm||x86_64) @(!arm||TARGET_bcm53xx||HAS_FPU)
  URL:=https://rustdesk.com/server
  USERID:=rustdesk-s:rustdesk-s
endef

define Package/rustdesk-s/description
  Self-host your own RustDesk server, it is free and open source.
endef

define Package/rustdesk-s/conffiles
/etc/config/rustdesk-s
/etc/rustdesk-s
endef

define Package/rustdesk-s/install
	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/{hbbr,hbbs} $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/rustdesk-s.conf $(1)/etc/config/rustdesk-s
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/rustdesk-s.init $(1)/etc/init.d/rustdesk-s
endef

$(eval $(call RustBinPackage,rustdesk-s))
$(eval $(call BuildPackage,rustdesk-s))
