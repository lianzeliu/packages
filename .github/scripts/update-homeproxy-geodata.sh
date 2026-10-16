#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd -- "$SCRIPT_DIR/../.." && pwd)}"
RESOURCES_DIR="$REPO_ROOT/luci-app-homeproxy/root/etc/homeproxy/resources"
DASHBOARD_DIR="$REPO_ROOT/luci-app-homeproxy/root/etc/homeproxy/dashboard"

GEOIP_SOURCE="${GEOIP_SOURCE:-https://cdn.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs}"
GEOIP_VERSION_URL="${GEOIP_VERSION_URL:-https://github.com/SagerNet/sing-geoip/releases/latest}"
GEOSITE_SOURCE="${GEOSITE_SOURCE:-https://cdn.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set-unstable/geosite-cn.srs}"
GEOSITE_VERSION_URL="${GEOSITE_VERSION_URL:-https://github.com/SagerNet/sing-geosite/releases/latest}"
DASHBOARD_SOURCE="${DASHBOARD_SOURCE:-https://codeload.github.com/SagerNet/sing-box-dashboard/zip/refs/heads/gh-pages}"
DASHBOARD_VERSION_URL="${DASHBOARD_VERSION_URL:-https://github.com/SagerNet/sing-box-dashboard/commits/gh-pages.atom}"
USER_AGENT="${USER_AGENT:-HomeProxy resource preset}"

TMP_DIR="$(mktemp -d)" || {
	echo "Failed to prepare temporary resource directory." >&2
	exit 1
}
DASHBOARD_STAGE="${DASHBOARD_DIR}.new.$$"
RESOURCE_RESTORE_FAILED=0
trap 'rm -rf -- "$TMP_DIR" "$DASHBOARD_STAGE"; [ "$RESOURCE_RESTORE_FAILED" -ne 0 ] || rm -rf -- "$RESOURCES_DIR/.update.$$.tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

warn() {
	echo "WARNING: $*" >&2
	if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
		echo "::warning::$*"
	fi
}

fetch_release_version() {
	local effective_url version
	effective_url="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
		--retry-delay 1 --connect-timeout 10 --max-time 30 \
		-A "$USER_AGENT" -o /dev/null -w '%{url_effective}' "$1")" || return 1
	version="${effective_url##*/}"
	case "$version" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s\n' "$version"
}

fetch_dashboard_version() {
	local feed version
	feed="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
		--retry-delay 1 --connect-timeout 10 --max-time 30 \
		-A "$USER_AGENT" "$DASHBOARD_VERSION_URL")" || return 1
	version="$(printf '%s\n' "$feed" | awk -F '[<>]' '
		/<updated>/ {
			version = $3
			gsub(/[-:TZ]/, "", version)
			print version
			exit
		}
	')"
	case "$version" in
		??????????????) case "$version" in *[!0-9]*) return 1 ;; esac ;;
		*) return 1 ;;
	esac
	printf '%s\n' "$version"
}

download() {
	curl -fsSL --compressed --retry 3 --retry-all-errors --retry-delay 1 \
		--connect-timeout 10 --max-time 60 -A "$USER_AGENT" -o "$2" "$1" &&
		test -s "$2"
}

validate_rule_set() {
	# Download checks cover transfer errors; only check the SRS envelope here.
	[[ "$(head -c 3 "$1" 2>/dev/null)" == SRS && $(wc -c < "$1") -gt 4 ]]
}

versioned_url() {
	case "$1" in
	http://*|https://*) printf '%s?v=%s' "$1" "$2" ;;
	*) printf '%s' "$1" ;;
	esac
}

install_rule_set() {
	local source_file="$1" version="$2" resource="$3"
	local stage_dir="$RESOURCES_DIR/.update.$$.tmp/$resource"

	mkdir -p "$stage_dir" &&
		cp "$source_file" "$stage_dir/$resource.srs" &&
		printf '%s\n' "$version" > "$stage_dir/$resource.ver" &&
		chmod 0644 "$stage_dir/$resource.srs" "$stage_dir/$resource.ver" || return 1
	if [ -e "$RESOURCES_DIR/$resource.srs" ]; then
		cp -p "$RESOURCES_DIR/$resource.srs" "$stage_dir/$resource.srs.old" || return 1
	fi
	mv -f "$stage_dir/$resource.srs" "$RESOURCES_DIR/$resource.srs" || return 1
	if ! mv -f "$stage_dir/$resource.ver" "$RESOURCES_DIR/$resource.ver"; then
		if [ -f "$stage_dir/$resource.srs.old" ]; then
			if ! mv -f "$stage_dir/$resource.srs.old" "$RESOURCES_DIR/$resource.srs"; then
				RESOURCE_RESTORE_FAILED=1
				printf 'Failed to restore %s; backup retained at %s.\n' "$resource" "$stage_dir" >&2
			fi
		else
			rm -f "$RESOURCES_DIR/$resource.srs" || RESOURCE_RESTORE_FAILED=1
		fi
		return 1
	fi
}

update_rule_set() {
	local resource="$1" source_url="$2" version_url="$3"
	local version old_version

	version="$(fetch_release_version "$version_url")" || return 1
	old_version="$(cat "$RESOURCES_DIR/$resource.ver" 2>/dev/null)"
	if [ "$old_version" = "$version" ] && validate_rule_set "$RESOURCES_DIR/$resource.srs"; then
		echo "HomeProxy resources: $resource $version (current)"
		return 0
	fi
	download "$(versioned_url "$source_url" "$version")" "$TMP_DIR/$resource.srs" &&
		validate_rule_set "$TMP_DIR/$resource.srs" &&
		install_rule_set "$TMP_DIR/$resource.srs" "$version" "$resource" || return 1
	echo "HomeProxy resources: $resource $version"
}

normalize_dashboard_javascript() {
	local dashboard_root="$1"
	local file

	find "$dashboard_root" -type f -name '*.js' -print0 > "$TMP_DIR/dashboard-javascript" || return 1
	while IFS= read -r -d '' file; do
		# CI-only whitespace normalization keeps the vendored tree diff-clean.
		# The device updater intentionally preserves the original upstream files.
		# shellcheck disable=SC2016
		sed -i -E 's/^(`\+[^`]+\+`)  $/\1\\x20\\x20/' "$file" || return 1
	done < "$TMP_DIR/dashboard-javascript"
}

update_dashboard() {
	local version old_version index source_dir=""
	local backup_dir="${DASHBOARD_DIR}.old.$$"

	version="$(fetch_dashboard_version)" || return 1
	old_version="$(cat "$DASHBOARD_DIR/dashboard.ver" 2>/dev/null)"
	if [ "$old_version" = "$version" ] && [ -s "$DASHBOARD_DIR/index.html" ]; then
		echo "HomeProxy dashboard: $version (current)"
		return 0
	fi
	download "$(versioned_url "$DASHBOARD_SOURCE" "$version")" "$TMP_DIR/dashboard.zip" &&
		unzip -q "$TMP_DIR/dashboard.zip" -d "$TMP_DIR/dashboard" || return 1
	for index in "$TMP_DIR/dashboard/index.html" "$TMP_DIR"/dashboard/*/index.html; do
		if [ -s "$index" ]; then
			source_dir="${index%/index.html}"
			break
		fi
	done
	[ -n "$source_dir" ] || return 1
	mkdir -p "$DASHBOARD_STAGE" &&
		cp -a "$source_dir/." "$DASHBOARD_STAGE/" &&
		rm -f "$DASHBOARD_STAGE/.etag" &&
		normalize_dashboard_javascript "$DASHBOARD_STAGE" &&
		printf '%s\n' "$version" > "$DASHBOARD_STAGE/dashboard.ver" &&
		chmod -R a+rX "$DASHBOARD_STAGE" || return 1
	mv "$DASHBOARD_DIR" "$backup_dir" || return 1
	if ! mv "$DASHBOARD_STAGE" "$DASHBOARD_DIR"; then
		mv "$backup_dir" "$DASHBOARD_DIR" || warn "Unable to restore the dashboard; backup retained at $backup_dir."
		return 1
	fi
	rm -rf "$backup_dir"
	echo "HomeProxy dashboard: $version"
}

mkdir -p "$RESOURCES_DIR" "$DASHBOARD_DIR" || exit 1
update_failed=0
if ! update_rule_set geoip_cn "$GEOIP_SOURCE" "$GEOIP_VERSION_URL"; then
	warn "Failed to update HomeProxy geoip resource; continuing."
	update_failed=1
fi
if ! update_rule_set geosite_cn "$GEOSITE_SOURCE" "$GEOSITE_VERSION_URL"; then
	warn "Failed to update HomeProxy geosite; continuing."
	update_failed=1
fi
if ! update_dashboard; then
	warn "Failed to update HomeProxy dashboard; continuing."
	update_failed=1
fi

if [[ "$update_failed" -ne 0 ]]; then
	echo "HomeProxy resource update failed; refusing to commit partial data." >&2
	exit 1
fi
