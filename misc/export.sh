#!/bin/bash

# Export script for KMReader archives
# Usage: ./export.sh [archive_path] [export_options_plist] [destination]
# Example: ./export.sh ./archives/KMReader-iOS_20240101_120000.xcarchive exportOptions.plist ./exports

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
ARCHIVE_PATH="${1}"
EXPORT_OPTIONS="${2:-$SCRIPT_DIR/exportOptions.plist}"
DEST_DIR="${3:-$PROJECT_ROOT/exports}"

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
  -allowProvisioningUpdates

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Export completed successfully!${NC}"
  echo "Export location: $EXPORT_PATH"
  echo ""
  echo "Exported files:"
  ls -lh "$EXPORT_PATH"
else
  echo -e "${RED}✗ Export failed!${NC}"
  exit 1
fi
