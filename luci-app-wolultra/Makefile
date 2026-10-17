# Copyright (C) 2026
#
# This is free software, licensed under the Apache License, Version 2.0.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-wolultra
PKG_VERSION:=20261017
PKG_RELEASE:=1
PKG_PO_VERSION:=$(PKG_VERSION)-r$(PKG_RELEASE)

LUCI_TITLE:=LuCI support for WOL Ultra
LUCI_DEPENDS:=+luci-base +etherwake
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/wolultra
endef

# Generate a wake token on first install only; never overwrite an existing
# one, and never run while building a firmware image.
define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
if [ -z "$$(uci get wolultra.global.token 2>/dev/null)" ]; then
	TOKEN="$$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
	[ -n "$$TOKEN" ] && uci set wolultra.global.token="$$TOKEN" && uci commit wolultra
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
