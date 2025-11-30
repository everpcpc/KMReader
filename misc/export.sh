#!/bin/bash

# Export script for KMReader archives
# Usage: ./export.sh [archive_path] [export_options_plist] [destination] [--keep-archive]
# Example: ./export.sh ./archives/KMReader-iOS_20240101_120000.xcarchive exportOptions.plist ./exports
# --keep-archive: Keep the archive after successful export (default: delete archive)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
KEEP_ARCHIVE=false
ARCHIVE_PATH=""
EXPORT_OPTIONS=""
DEST_DIR=""

for arg in "$@"; do
	case "$arg" in
	--keep-archive)
		KEEP_ARCHIVE=true
		;;
	*)
		if [ -z "$ARCHIVE_PATH" ]; then
			ARCHIVE_PATH="$arg"
		elif [ -z "$EXPORT_OPTIONS" ]; then
			EXPORT_OPTIONS="$arg"
		elif [ -z "$DEST_DIR" ]; then
			DEST_DIR="$arg"
		fi
		;;
	esac
done

# Set defaults
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$SCRIPT_DIR/exportOptions.plist}"
DEST_DIR="${DEST_DIR:-$PROJECT_ROOT/exports}"

# Validate arguments
if [ -z "$ARCHIVE_PATH" ]; then
	echo -e "${RED}Error: Archive path is required${NC}"
	echo "Usage: ./export.sh [archive_path] [export_options_plist] [destination]"
	exit 1
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
	echo -e "${RED}Error: Archive not found at '$ARCHIVE_PATH'${NC}"
	exit 1
fi

if [ ! -f "$EXPORT_OPTIONS" ]; then
	echo -e "${RED}Error: Export options plist not found at '$EXPORT_OPTIONS'${NC}"
	echo "You can copy exportOptions.plist.example to exportOptions.plist and customize it"
	exit 1
fi

# Create destination directory
mkdir -p "$DEST_DIR"

# Generate export path with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_PATH="$DEST_DIR/export_${TIMESTAMP}"

echo -e "${GREEN}Starting export...${NC}"
echo "Archive: $ARCHIVE_PATH"
echo "Export options: $EXPORT_OPTIONS"
echo "Export path: $EXPORT_PATH"
echo ""

# Export
echo -e "${YELLOW}Exporting archive...${NC}"
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-allowProvisioningUpdates \
	-quiet

if [ $? -eq 0 ]; then
	echo -e "${GREEN}✓ Export completed successfully!${NC}"
	echo "Export location: $EXPORT_PATH"
	echo ""
	echo "Exported files:"
	ls -lh "$EXPORT_PATH"

	# Delete archive if not keeping it
	if [ "$KEEP_ARCHIVE" = false ]; then
		echo ""
		echo -e "${YELLOW}Deleting archive...${NC}"
		rm -rf "$ARCHIVE_PATH"
		echo -e "${GREEN}✓ Archive deleted${NC}"
	else
		echo ""
		echo -e "${YELLOW}Archive kept at: $ARCHIVE_PATH${NC}"
	fi
else
	echo -e "${RED}✗ Export failed!${NC}"
	exit 1
fi
