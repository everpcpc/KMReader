#!/bin/bash

# Build all platforms script for KMReader
# Usage: ./build-all.sh [--show-in-organizer] [--skip-export] [--verbose]
# --show-in-organizer: Save archives to Xcode's default location
# --skip-export: Only create archives, skip export step
# --verbose: Show verbose output during export

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
VERBOSE=false

for arg in "$@"; do
	case "$arg" in
	--show-in-organizer)
		SHOW_IN_ORGANIZER=true
		;;
	--skip-export)
		SKIP_EXPORT=true
		;;
	--verbose)
		VERBOSE=true
		;;
	*)
		echo -e "${RED}Unknown option: $arg${NC}"
		echo "Usage: ./build-all.sh [--show-in-organizer] [--skip-export] [--verbose]"
		exit 1
		;;
	esac
done

# Configuration
ARCHIVES_DIR="$PROJECT_ROOT/archives"
EXPORTS_DIR="$PROJECT_ROOT/exports"
EXPORT_OPTIONS="$SCRIPT_DIR/exportOptions.plist"
PLATFORMS=("ios" "macos" "tvos")

# Check if export options file exists
if [ "$SKIP_EXPORT" = false ] && [ ! -f "$EXPORT_OPTIONS" ]; then
	echo -e "${RED}Error: Export options plist not found at '$EXPORT_OPTIONS'${NC}"
	echo "Please create it by copying the example:"
	echo "  cp $SCRIPT_DIR/exportOptions.plist.example $EXPORT_OPTIONS"
	echo "Then edit it according to your needs."
	exit 1
fi

# Array to store archive paths
declare -a ARCHIVE_PATHS
ARCHIVE_FAILED=false

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}KMReader - Build All Platforms${NC}"
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

		# Build export command with optional API key arguments
		EXPORT_CMD=("$SCRIPT_DIR/export.sh" "$archive_path" "$EXPORT_OPTIONS" "$EXPORTS_DIR")

		# Add API key arguments if environment variables are set
		if [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ] && [ -n "$APP_STORE_CONNECT_API_ISSUER_ID" ] && [ -n "$APP_STORE_CONNECT_API_KEY_ID" ]; then
			EXPORT_CMD+=("--api-key-path" "$APP_STORE_CONNECT_API_KEY_PATH")
			EXPORT_CMD+=("--api-issuer-id" "$APP_STORE_CONNECT_API_ISSUER_ID")
			EXPORT_CMD+=("--api-key-id" "$APP_STORE_CONNECT_API_KEY_ID")
		fi

		# Add verbose flag if requested
		if [ "$VERBOSE" = true ]; then
			EXPORT_CMD+=("--verbose")
		fi

		"${EXPORT_CMD[@]}"

		echo ""
	done

	echo -e "${GREEN}✓ All exports completed successfully!${NC}"
	echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Build Summary${NC}"
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

echo -e "${GREEN}✓ Build process completed!${NC}"
