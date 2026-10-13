include $(TOPDIR)/rules.mk

PKG_NAME:=axonhub
PKG_VERSION:=20261013
PKG_RELEASE:=1

# Updated by Build-AxonHub.yml only after a successful daily release.
AXONHUB_BUILD_VERSION:=unstable-20261013
AXONHUB_UPSTREAM_COMMIT:=7a0cfbf42b00829dd8811cc87488f6194ed5ae02

ifeq ($(ARCH),aarch64)
  AXONHUB_ARCH:=arm64
  PKG_HASH:=5ff54604a71d6b10415be7c7e67d5794f5b6265079d413fccd5b12d57f187fa5
else ifeq ($(ARCH),x86_64)
  AXONHUB_ARCH:=amd64
  PKG_HASH:=03f4f63eccd35fc3c1fe3242f86635c6104efb6aad35b698c1754430c2cd3115
else ifeq ($(ARCH),loongarch64)
  AXONHUB_ARCH:=loong64
  PKG_HASH:=233302aec2857cd4df6192843f9c626d6ef6994b7d787d2acf76aeb6ceea09e8
else
  AXONHUB_ARCH:=unsupported
  PKG_HASH:=skip
endif

PKG_SOURCE:=$(PKG_NAME)-$(AXONHUB_BUILD_VERSION)-$(AXONHUB_UPSTREAM_COMMIT)-$(ARCH_PACKAGES)
PKG_SOURCE_URL:=https://github.com/VIKINGYFY/packages/releases/download/$(PKG_NAME)-$(AXONHUB_BUILD_VERSION)/$(PKG_NAME)_linux_$(AXONHUB_ARCH)?
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(AXONHUB_BUILD_VERSION)-$(AXONHUB_UPSTREAM_COMMIT)-$(ARCH)
UNPACK_CMD=mkdir -p $(1) && $(CP) $(DL_DIR)/$(PKG_SOURCE) $(1)/$(PKG_NAME)

PKG_LICENSE:=Apache-2.0 AND LGPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=VIKINGYFY

# The release binary is already stripped. Preserve it byte-for-byte because
# OpenWrt's sstrip corrupts the section table of this large static Go ELF.
RSTRIP:=:

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=AxonHub AI gateway ($(AXONHUB_BUILD_VERSION))
  URL:=https://github.com/looplj/axonhub
  DEPENDS:=@(aarch64||x86_64||loongarch64) +ca-bundle +zoneinfo-core +zoneinfo-asia
endef

define Package/$(PKG_NAME)/description
 AxonHub is an all-in-one AI gateway with an embedded management interface,
 API format translation, request tracing and provider load balancing.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/axonhub $(1)/usr/bin/axonhub
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
