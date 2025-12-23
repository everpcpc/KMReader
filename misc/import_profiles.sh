#!/bin/bash

set -euo pipefail

PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILES_DIR"

import_profile() {
	local platform=$1
	local profile_base64=$2
	local file_ext=$3

	if [ -z "$profile_base64" ]; then
		echo "Warning: $platform profile not provided, skipping"
		return 0
	fi

	echo "Importing $platform provisioning profile..."
	local temp_profile="$RUNNER_TEMP/${platform}${file_ext}"
	echo "$profile_base64" | base64 -d >"$temp_profile"

	local uuid=""
	local profile_xml
	if profile_xml=$(security cms -D -i "$temp_profile" 2>/dev/null); then
		uuid=$(echo "$profile_xml" | /usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin 2>/dev/null || echo "")
		local profile_name
		profile_name=$(echo "$profile_xml" | /usr/libexec/PlistBuddy -c "Print Name" /dev/stdin 2>/dev/null || echo "")
		local app_identifier
		app_identifier=$(echo "$profile_xml" | /usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier" /dev/stdin 2>/dev/null || echo "")
		local bundle_identifier=""
		if [[ "$app_identifier" == *.* ]]; then
			bundle_identifier="${app_identifier#*.}"
		fi

		if [ -n "$profile_name" ]; then
			echo "  Name: $profile_name"
		fi
		if [ -n "$bundle_identifier" ]; then
			echo "  Bundle Identifier: $bundle_identifier"
		fi
	fi

	if [ -n "$uuid" ]; then
		cp "$temp_profile" "$PROFILES_DIR/$uuid${file_ext}"
		echo "✓ Imported $platform profile: $uuid"
	else
		local fallback_name="${platform}${file_ext}"
		cp "$temp_profile" "$PROFILES_DIR/$fallback_name"
		echo "⚠ Imported $platform profile (UUID not found, using: $fallback_name)"
	fi
}

import_profile "iOS" "${IOS_PROVISIONING_PROFILE_BASE64:-}" ".mobileprovision"
import_profile "macOS" "${MACOS_PROVISIONING_PROFILE_BASE64:-}" ".provisionprofile"
import_profile "tvOS" "${TVOS_PROVISIONING_PROFILE_BASE64:-}" ".mobileprovision"

import_profile "widgets" "${WIDGETS_PROVISIONING_PROFILE_BASE64:-}" ".mobileprovision"

echo ""
echo "Imported provisioning profiles:"
ls -lh "$PROFILES_DIR" 2>/dev/null | tail -n +2 || echo "No profiles found"
