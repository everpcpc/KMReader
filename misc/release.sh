#!/bin/bash

# Release script for KMReader (builds all platforms)
# Usage: ./release.sh [--show-in-organizer] [--skip-export]
# --show-in-organizer: Save archives to Xcode's default location
# --skip-export: Only create archives, skip export step

set -e

# Auto-load .env file if it exists (in project root or script directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Auto-load .env file if it exists (in project root or script directory)
if [ -f "$PROJECT_ROOT/.env" ]; then
	echo -e "${GREEN}Loading environment variables from .env file...${NC}"
	set -a # automatically export all variables
	source "$PROJECT_ROOT/.env"
	set +a # stop automatically exporting
elif [ -f "$SCRIPT_DIR/.env" ]; then
	echo -e "${GREEN}Loading environment variables from .env file...${NC}"
	set -a
	source "$SCRIPT_DIR/.env"
	set +a
fi

# Parse arguments
SHOW_IN_ORGANIZER=false
SKIP_EXPORT=false
SINGLE_PLATFORM=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--show-in-organizer)
		SHOW_IN_ORGANIZER=true
		shift
		;;
	--skip-export)
		SKIP_EXPORT=true
		shift
		;;
	--platform)
		if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
			SINGLE_PLATFORM="$2"
			shift 2
		else
			echo -e "${RED}Error: --platform requires an argument (ios, macos, or tvos)${NC}"
			exit 1
		fi
		;;
	*)
		echo -e "${RED}Unknown option: $1${NC}"
		echo "Usage: ./release.sh [--show-in-organizer] [--skip-export] [--platform <ios|macos|tvos>]"
		exit 1
		;;
	esac
done

# Configuration
ARCHIVES_DIR="$PROJECT_ROOT/archives"
EXPORTS_DIR="$PROJECT_ROOT/exports"
EXPORT_OPTIONS_IOS="$SCRIPT_DIR/exportOptions.ios.plist"
EXPORT_OPTIONS_MACOS="$SCRIPT_DIR/exportOptions.macos.plist"
EXPORT_OPTIONS_TVOS="$SCRIPT_DIR/exportOptions.tvos.plist"

# Determine which platforms to build
if [ -n "$SINGLE_PLATFORM" ]; then
	case "$SINGLE_PLATFORM" in
	ios | macos | tvos)
		PLATFORMS=("$SINGLE_PLATFORM")
		;;
	*)
		echo -e "${RED}Error: Invalid platform '$SINGLE_PLATFORM'. Must be ios, macos, or tvos.${NC}"
		exit 1
		;;
	esac
else
	PLATFORMS=("ios" "macos" "tvos")
fi

# Check if export options files exist
if [ "$SKIP_EXPORT" = false ]; then
	for plist in "$EXPORT_OPTIONS_IOS" "$EXPORT_OPTIONS_MACOS" "$EXPORT_OPTIONS_TVOS"; do
		if [ ! -f "$plist" ]; then
			echo -e "${RED}Error: export options plist not found at '$plist'${NC}"
			exit 1
		fi
	done
fi

# Array to store archive paths
declare -a ARCHIVE_PATHS
ARCHIVE_FAILED=false

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}KMReader - Release${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Archive all platforms
echo -e "${GREEN}Step 1: Creating archives for all platforms...${NC}"
echo ""

for platform in "${PLATFORMS[@]}"; do
	echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${YELLOW}Archiving for $platform...${NC}"
	echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

	# Run archive and capture output to both display and extract path
	TEMP_OUTPUT=$(mktemp)
	ARCHIVE_EXIT_CODE=0

	if [ "$SHOW_IN_ORGANIZER" = true ]; then
		"$SCRIPT_DIR/archive.sh" "$platform" --show-in-organizer 2>&1 | tee "$TEMP_OUTPUT"
		ARCHIVE_EXIT_CODE=${PIPESTATUS[0]}
	else
		"$SCRIPT_DIR/archive.sh" "$platform" "$ARCHIVES_DIR" 2>&1 | tee "$TEMP_OUTPUT"
		ARCHIVE_EXIT_CODE=${PIPESTATUS[0]}
	fi

	# Extract archive path from output (look for "Archive location: " line)
	ARCHIVE_PATH=$(grep "Archive location:" "$TEMP_OUTPUT" | sed 's/.*Archive location: //' | tr -d '\n')
	rm -f "$TEMP_OUTPUT"

	# If not found in output, try to find the most recent archive
	if [ -z "$ARCHIVE_PATH" ] || [ ! -d "$ARCHIVE_PATH" ]; then
		# Determine search directory
		if [ "$SHOW_IN_ORGANIZER" = true ]; then
			ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +"%Y-%m-%d")"
		else
			ARCHIVE_DIR="$ARCHIVES_DIR"
		fi

		# Get archive name for this platform
		case "$platform" in
		ios)
			ARCHIVE_NAME="KMReader-iOS"
			;;
		macos)
			ARCHIVE_NAME="KMReader-macOS"
			;;
		tvos)
			ARCHIVE_NAME="KMReader-tvOS"
			;;
		esac

		# Find the most recent archive
		ARCHIVE_PATH=$(find "$ARCHIVE_DIR" -name "${ARCHIVE_NAME}_*.xcarchive" -type d -maxdepth 1 2>/dev/null | sort -r | head -n 1)
	fi

	if [ "$ARCHIVE_EXIT_CODE" -ne 0 ]; then
		echo -e "${RED}✗ Archive failed for $platform!${NC}"
		ARCHIVE_FAILED=true
		echo ""
		continue
	fi

	if [ -n "$ARCHIVE_PATH" ] && [ -d "$ARCHIVE_PATH" ]; then
		ARCHIVE_PATHS+=("$ARCHIVE_PATH")
		echo -e "${GREEN}✓ Archive saved: $ARCHIVE_PATH${NC}"
	else
		echo -e "${RED}✗ Warning: Could not find archive for $platform${NC}"
		ARCHIVE_FAILED=true
	fi

	echo ""
done

# Check if any archive failed
if [ "$ARCHIVE_FAILED" = true ]; then
	echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${RED}✗ Some archives failed! Skipping export.${NC}"
	echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""
	echo -e "${YELLOW}Summary:${NC}"
	echo "  Failed platforms will not be exported."
	if [ ${#ARCHIVE_PATHS[@]} -gt 0 ]; then
		echo -e "${GREEN}  Successful archives:${NC}"
		for archive_path in "${ARCHIVE_PATHS[@]}"; do
			if [ -d "$archive_path" ]; then
				echo "    - $archive_path"
			fi
		done
	fi
	exit 1
fi

echo -e "${GREEN}✓ All archives created successfully!${NC}"
echo ""

# Step 2: Export all archives
if [ "$SKIP_EXPORT" = false ]; then
	echo -e "${GREEN}Step 2: Exporting all archives...${NC}"
	echo ""

	for archive_path in "${ARCHIVE_PATHS[@]}"; do
		if [ ! -d "$archive_path" ]; then
			echo -e "${RED}✗ Skipping invalid archive: $archive_path${NC}"
			continue
		fi

		# Extract platform name from archive path
		if [[ "$archive_path" == *"KMReader-iOS"* ]]; then
			PLATFORM_NAME="iOS"
		elif [[ "$archive_path" == *"KMReader-macOS"* ]]; then
			PLATFORM_NAME="macOS"
		elif [[ "$archive_path" == *"KMReader-tvOS"* ]]; then
			PLATFORM_NAME="tvOS"
		else
			PLATFORM_NAME="Unknown"
		fi

		echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
		echo -e "${YELLOW}Exporting $PLATFORM_NAME archive...${NC}"
		echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

		case "$PLATFORM_NAME" in
		"iOS")
			EXPORT_PLIST="$EXPORT_OPTIONS_IOS"
			;;
		"macOS")
			EXPORT_PLIST="$EXPORT_OPTIONS_MACOS"
			;;
		"tvOS")
			EXPORT_PLIST="$EXPORT_OPTIONS_TVOS"
			;;
		*)
			echo -e "${RED}✗ Unknown platform for export: $PLATFORM_NAME${NC}"
			continue
			;;
		esac

		# Build export command; keep archive for artifacts.sh to extract .app file for DMG creation
		EXPORT_CMD=(
			"$SCRIPT_DIR/export.sh"
			"$archive_path"
			"$EXPORT_PLIST"
			"$EXPORTS_DIR"
			"--keep-archive"
			"--platform"
			"$PLATFORM_NAME"
		)

		"${EXPORT_CMD[@]}"

		echo ""
	done

	echo -e "${GREEN}✓ All exports completed successfully!${NC}"
	echo ""
	echo -e "${GREEN}Uploading exported artifacts...${NC}"
	for platform in "${PLATFORMS[@]}"; do
		case "$platform" in
		ios)
			PLATFORM_NAME="iOS"
			ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "KMReader-iOS.ipa" | sort | tail -n1 || true)
			if [ -z "$ARTIFACT_FILE" ]; then
				ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "*.ipa" ! -name "*tvOS*.ipa" | sort | tail -n1 || true)
			fi
			;;
		macos)
			PLATFORM_NAME="macOS"
			ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "KMReader-macOS.pkg" | sort | tail -n1 || true)
			if [ -z "$ARTIFACT_FILE" ]; then
				ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "*.pkg" | sort | tail -n1 || true)
			fi
			;;
		tvos)
			PLATFORM_NAME="tvOS"
			ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "KMReader-tvOS.ipa" | sort | tail -n1 || true)
			if [ -z "$ARTIFACT_FILE" ]; then
				ARTIFACT_FILE=$(find "$EXPORTS_DIR" -type f -name "*tvOS*.ipa" | sort | tail -n1 || true)
			fi
			;;
		esac

		if [ -n "$ARTIFACT_FILE" ]; then
			echo -e "${YELLOW}Uploading $(basename "$ARTIFACT_FILE") for $PLATFORM_NAME...${NC}"
			"$SCRIPT_DIR/upload.sh" "$ARTIFACT_FILE" "$PLATFORM_NAME"
		else
			echo -e "${YELLOW}No artifact found for $PLATFORM_NAME; skipping upload.${NC}"
		fi
	done
	echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Release Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Archives created:${NC}"
for archive_path in "${ARCHIVE_PATHS[@]}"; do
	if [ -d "$archive_path" ]; then
		echo "  - $archive_path"
	fi
done
echo ""

if [ "$SKIP_EXPORT" = false ]; then
	echo -e "${GREEN}Exports location:${NC}"
	echo "  - $EXPORTS_DIR"
	echo ""
	echo "Exported files:"
	if [ -d "$EXPORTS_DIR" ]; then
		ls -lh "$EXPORTS_DIR" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
	fi
	echo ""
fi

echo -e "${GREEN}✓ Release process completed!${NC}"
