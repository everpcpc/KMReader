#!/bin/bash

# Archive script for KMReader
# Usage: ./archive.sh [platform] [destination] [--show-in-organizer]
# Platform: ios, macos, tvos (default: ios)
# Destination: archive output directory (default: ./archives)
# --show-in-organizer: Save archive to Xcode's default location so it appears in Organizer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SCHEME="KMReader"
PROJECT="$PROJECT_ROOT/KMReader.xcodeproj"
BUNDLE_ID="com.everpcpc.Komga"

# Parse arguments
SHOW_IN_ORGANIZER=false
PLATFORM="ios"
DEST_DIR="$PROJECT_ROOT/archives"

for arg in "$@"; do
	case "$arg" in
	--show-in-organizer)
		SHOW_IN_ORGANIZER=true
		;;
	ios | macos | tvos)
		PLATFORM="$arg"
		;;
	*)
		# Assume it's a destination directory if it doesn't match known values
		if [[ ! "$arg" =~ ^-- ]]; then
			DEST_DIR="$arg"
		fi
		;;
	esac
done

# Validate platform
case "$PLATFORM" in
ios | macos | tvos) ;;
*)
	echo -e "${RED}Error: Invalid platform '$PLATFORM'${NC}"
	echo "Supported platforms: ios, macos, tvos"
	exit 1
	;;
esac

# Set SDK and destination based on platform
case "$PLATFORM" in
ios)
	SDK="iphoneos"
	DESTINATION="generic/platform=iOS"
	ARCHIVE_NAME="KMReader-iOS"
	;;
macos)
	SDK="macosx"
	DESTINATION="generic/platform=macOS"
	ARCHIVE_NAME="KMReader-macOS"
	;;
tvos)
	SDK="appletvos"
	DESTINATION="generic/platform=tvOS"
	ARCHIVE_NAME="KMReader-tvOS"
	;;
esac

# Determine archive path
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

if [ "$SHOW_IN_ORGANIZER" = true ]; then
	# Use Xcode's default archive location so it appears in Organizer
	ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +"%Y-%m-%d")"
	mkdir -p "$ARCHIVES_DIR"
	ARCHIVE_PATH="$ARCHIVES_DIR/${ARCHIVE_NAME}_${TIMESTAMP}.xcarchive"
	echo -e "${YELLOW}Note: Archive will be saved to Xcode's default location and appear in Organizer${NC}"
else
	# Use custom destination directory
	mkdir -p "$DEST_DIR"
	ARCHIVE_PATH="$DEST_DIR/${ARCHIVE_NAME}_${TIMESTAMP}.xcarchive"
fi

echo -e "${GREEN}Starting archive for $PLATFORM...${NC}"
echo "Scheme: $SCHEME"
echo "SDK: $SDK"
echo "Destination: $DESTINATION"
echo "Archive path: $ARCHIVE_PATH"
echo ""

# Clean build folder first
echo -e "${YELLOW}Cleaning build folder...${NC}"
xcodebuild clean \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-sdk "$SDK" \
	-configuration Release

# Archive
echo -e "${YELLOW}Archiving...${NC}"
xcodebuild archive \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-sdk "$SDK" \
	-destination "$DESTINATION" \
	-configuration Release \
	-archivePath "$ARCHIVE_PATH" \
	-allowProvisioningUpdates \
	CODE_SIGN_IDENTITY="" \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGNING_ALLOWED=NO

if [ $? -eq 0 ]; then
	echo -e "${GREEN}✓ Archive created successfully!${NC}"
	echo "Archive location: $ARCHIVE_PATH"

	if [ "$SHOW_IN_ORGANIZER" = true ]; then
		echo ""
		echo "Archive is now available in Xcode Organizer (Window > Organizer)"
	fi

	echo ""
	echo "To export the archive, you can use:"
	echo "  xcodebuild -exportArchive \\"
	echo "    -archivePath \"$ARCHIVE_PATH\" \\"
	echo "    -exportPath \"$DEST_DIR/${ARCHIVE_NAME}_${TIMESTAMP}_export\" \\"
	echo "    -exportOptionsPlist exportOptions.plist"
else
	echo -e "${RED}✗ Archive failed!${NC}"
	exit 1
fi
