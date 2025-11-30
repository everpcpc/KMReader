#!/bin/bash

# Export script for KMReader archives
# Usage: ./export.sh [archive_path] [export_options_plist] [destination] [--keep-archive] [--api-key-path PATH] [--api-issuer-id ID] [--verbose]
# Example: ./export.sh ./archives/KMReader-iOS_20240101_120000.xcarchive exportOptions.plist ./exports
# --keep-archive: Keep the archive after successful export (default: delete archive)
# --api-key-path: Path to App Store Connect API key (.p8 file) for automatic upload
# --api-issuer-id: App Store Connect API Issuer ID (required with --api-key-path)
# --api-key-id: App Store Connect API Key ID (required with --api-key-path)
# --verbose: Show full xcodebuild output for debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
KEEP_ARCHIVE=false
ARCHIVE_PATH=""
EXPORT_OPTIONS=""
DEST_DIR=""
API_KEY_PATH=""
API_ISSUER_ID=""
API_KEY_ID=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	--keep-archive)
		KEEP_ARCHIVE=true
		shift
		;;
	--api-key-path)
		API_KEY_PATH="$2"
		shift 2
		;;
	--api-issuer-id)
		API_ISSUER_ID="$2"
		shift 2
		;;
	--api-key-id)
		API_KEY_ID="$2"
		shift 2
		;;
	--verbose)
		VERBOSE=true
		shift
		;;
	*)
		if [ -z "$ARCHIVE_PATH" ]; then
			ARCHIVE_PATH="$1"
		elif [ -z "$EXPORT_OPTIONS" ]; then
			EXPORT_OPTIONS="$1"
		elif [ -z "$DEST_DIR" ]; then
			DEST_DIR="$1"
		fi
		shift
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

# Check export method and upload settings
EXPORT_METHOD=""
UPLOAD_ENABLED=false
if command -v plutil &>/dev/null; then
	EXPORT_METHOD=$(plutil -extract method raw "$EXPORT_OPTIONS" 2>/dev/null || echo "")
	UPLOAD_VALUE=$(plutil -extract uploadToAppStore raw "$EXPORT_OPTIONS" 2>/dev/null || echo "")
	if [ "$UPLOAD_VALUE" = "true" ] || [ "$UPLOAD_VALUE" = "1" ]; then
		UPLOAD_ENABLED=true
	fi
	# app-store-connect method implies upload
	if [ "$EXPORT_METHOD" = "app-store-connect" ]; then
		UPLOAD_ENABLED=true
	fi
fi

echo -e "${GREEN}Starting export...${NC}"
echo "Archive: $ARCHIVE_PATH"
echo "Export options: $EXPORT_OPTIONS"
echo "Export path: $EXPORT_PATH"
if [ -n "$EXPORT_METHOD" ]; then
	echo "Export method: $EXPORT_METHOD"
fi
if [ "$UPLOAD_ENABLED" = true ]; then
	echo -e "${YELLOW}Upload to App Store Connect: Enabled${NC}"
	if [ -n "$API_KEY_PATH" ]; then
		echo "Using App Store Connect API key: $API_KEY_PATH"
	else
		echo -e "${YELLOW}Note: Will prompt for Apple ID credentials if API key not provided${NC}"
		echo -e "${YELLOW}      Make sure you have App-Specific Password if 2FA is enabled${NC}"
	fi
else
	if [ "$EXPORT_METHOD" = "app-store-connect" ]; then
		echo -e "${YELLOW}Note: Method is 'app-store-connect' but uploadToAppStore is not explicitly set${NC}"
		echo -e "${YELLOW}      Upload should happen automatically with this method${NC}"
	fi
fi
echo ""

# Set up App Store Connect API authentication
# Priority: command-line arguments > environment variables
if [ "$UPLOAD_ENABLED" = true ]; then
	# Use command-line arguments if provided, otherwise fall back to environment variables
	if [ -z "$API_KEY_PATH" ] && [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
		API_KEY_PATH="$APP_STORE_CONNECT_API_KEY_PATH"
	fi
	if [ -z "$API_ISSUER_ID" ] && [ -n "$APP_STORE_CONNECT_API_ISSUER_ID" ]; then
		API_ISSUER_ID="$APP_STORE_CONNECT_API_ISSUER_ID"
	fi
	if [ -z "$API_KEY_ID" ] && [ -n "$APP_STORE_CONNECT_API_KEY_ID" ]; then
		API_KEY_ID="$APP_STORE_CONNECT_API_KEY_ID"
	fi

	# If API key path is provided (via args or env), validate and set up
	if [ -n "$API_KEY_PATH" ]; then
		if [ ! -f "$API_KEY_PATH" ]; then
			echo -e "${RED}Error: API key file not found at '$API_KEY_PATH'${NC}"
			exit 1
		fi
		if [ -z "$API_ISSUER_ID" ] || [ -z "$API_KEY_ID" ]; then
			echo -e "${RED}Error: API Issuer ID and Key ID are required when using API key${NC}"
			echo -e "${YELLOW}Provide via: --api-issuer-id and --api-key-id arguments${NC}"
			echo -e "${YELLOW}Or set: APP_STORE_CONNECT_API_ISSUER_ID and APP_STORE_CONNECT_API_KEY_ID environment variables${NC}"
			exit 1
		fi
		# Set environment variables for xcodebuild to use App Store Connect API key
		export APP_STORE_CONNECT_API_KEY_PATH="$API_KEY_PATH"
		export APP_STORE_CONNECT_API_ISSUER_ID="$API_ISSUER_ID"
		export APP_STORE_CONNECT_API_KEY_ID="$API_KEY_ID"
		echo -e "${GREEN}Using App Store Connect API key for authentication${NC}"
	fi
fi

# Export
echo -e "${YELLOW}Exporting archive...${NC}"
if [ "$UPLOAD_ENABLED" = true ]; then
	echo -e "${YELLOW}This will also upload to App Store Connect...${NC}"
fi

# Run xcodebuild
if [ "$VERBOSE" = true ]; then
	# Show full output in verbose mode
	echo -e "${YELLOW}Running xcodebuild (verbose mode)...${NC}"
	xcodebuild -exportArchive \
		-archivePath "$ARCHIVE_PATH" \
		-exportPath "$EXPORT_PATH" \
		-exportOptionsPlist "$EXPORT_OPTIONS" \
		-allowProvisioningUpdates
	XCODEBUILD_EXIT_CODE=$?
	XCODEBUILD_OUTPUT=""
else
	# Capture output for analysis
	XCODEBUILD_OUTPUT=$(xcodebuild -exportArchive \
		-archivePath "$ARCHIVE_PATH" \
		-exportPath "$EXPORT_PATH" \
		-exportOptionsPlist "$EXPORT_OPTIONS" \
		-allowProvisioningUpdates 2>&1)
	XCODEBUILD_EXIT_CODE=$?
fi

# Check for upload status from multiple sources
UPLOAD_DETECTED=false
UPLOAD_FAILED=false

# Method 1: Check xcodebuild output
if [ -n "$XCODEBUILD_OUTPUT" ]; then
	if echo "$XCODEBUILD_OUTPUT" | grep -qiE "upload|app store connect|successfully uploaded|upload.*complete"; then
		UPLOAD_DETECTED=true
	fi
	if echo "$XCODEBUILD_OUTPUT" | grep -qiE "upload.*fail|upload.*error|failed to upload"; then
		UPLOAD_FAILED=true
	fi
fi

# Method 2: Check DistributionSummary.plist for upload status
DISTRIBUTION_SUMMARY="$EXPORT_PATH/DistributionSummary.plist"
if [ -f "$DISTRIBUTION_SUMMARY" ] && command -v plutil &>/dev/null; then
	# Check for distributionMethod - if it's "app-store-connect", upload should have happened
	DIST_METHOD=$(plutil -extract distributionMethod raw "$DISTRIBUTION_SUMMARY" 2>/dev/null || echo "")
	if [ "$DIST_METHOD" = "app-store-connect" ] && [ "$EXPORT_METHOD" = "app-store-connect" ]; then
		# With app-store-connect method, if export succeeded, upload should have happened
		UPLOAD_DETECTED=true
	fi

	# Check for any upload-related keys
	if plutil -extract uploadDestination raw "$DISTRIBUTION_SUMMARY" 2>/dev/null | grep -qi "app.*store"; then
		UPLOAD_DETECTED=true
	fi
fi

# Method 3: Check Packaging.log for upload messages
PACKAGING_LOG="$EXPORT_PATH/Packaging.log"
if [ -f "$PACKAGING_LOG" ]; then
	if grep -qiE "upload|app.*store.*connect|successfully.*upload" "$PACKAGING_LOG" 2>/dev/null; then
		UPLOAD_DETECTED=true
	fi
	if grep -qiE "upload.*fail|upload.*error|failed.*upload" "$PACKAGING_LOG" 2>/dev/null; then
		UPLOAD_FAILED=true
	fi
fi

# Method 4: Check Packaging.log for skipped upload step
# If IDEDistributionAppStoreInformationStep was skipped, upload didn't happen
PACKAGING_LOG="$EXPORT_PATH/Packaging.log"
if [ -f "$PACKAGING_LOG" ]; then
	if grep -qi "Skipping step.*IDEDistributionAppStoreInformationStep" "$PACKAGING_LOG" 2>/dev/null; then
		# Upload step was skipped, so upload didn't happen
		UPLOAD_DETECTED=false
		# Note: app-store-connect method may not automatically upload
		# It might just export the IPA for manual upload
	fi
fi

# Show output if there was an error or in verbose mode
if [ "$XCODEBUILD_EXIT_CODE" -ne 0 ]; then
	if [ "$VERBOSE" != true ]; then
		echo "$XCODEBUILD_OUTPUT"
	fi
	echo -e "${RED}✗ Export failed!${NC}"
	exit 1
fi

# Show upload-related output if detected (non-verbose mode)
if [ "$VERBOSE" != true ] && [ "$UPLOAD_DETECTED" = true ]; then
	echo "$XCODEBUILD_OUTPUT" | grep -iE "upload|app store|successfully" || true
fi

echo -e "${GREEN}✓ Export completed successfully!${NC}"
if [ "$UPLOAD_ENABLED" = true ]; then
	if [ "$UPLOAD_FAILED" = true ]; then
		echo -e "${RED}✗ Upload to App Store Connect failed!${NC}"
		echo -e "${YELLOW}Check the output above and Packaging.log for details.${NC}"
	elif [ "$UPLOAD_DETECTED" = true ]; then
		echo -e "${GREEN}✓ Upload to App Store Connect completed!${NC}"
		if [ "$EXPORT_METHOD" = "app-store-connect" ]; then
			echo -e "${GREEN}  Build should now be available in App Store Connect.${NC}"
		fi
	else
		# Upload was not detected
		if [ "$EXPORT_METHOD" = "app-store-connect" ]; then
			echo -e "${YELLOW}⚠ Upload to App Store Connect was not detected.${NC}"
			echo -e "${YELLOW}  Note: 'app-store-connect' method may only export the IPA file.${NC}"
			echo -e "${YELLOW}  You may need to manually upload the IPA file.${NC}"
		else
			echo -e "${YELLOW}⚠ Upload status unclear. Check the output above.${NC}"
			echo -e "${YELLOW}If upload didn't happen, you may need to:${NC}"
			echo -e "${YELLOW}  1. Check your API credentials or Apple ID login${NC}"
			echo -e "${YELLOW}  2. Verify the archive was built with correct signing${NC}"
			echo -e "${YELLOW}  3. Check App Store Connect for the uploaded build${NC}"
			echo -e "${YELLOW}  4. Check Packaging.log for detailed information${NC}"
		fi
	fi
fi

echo "Export location: $EXPORT_PATH"
echo ""
echo "Exported files:"
ls -lh "$EXPORT_PATH"

# Auto-upload using xcrun altool if upload was enabled but not detected
if [ "$UPLOAD_ENABLED" = true ] && [ "$UPLOAD_DETECTED" != true ] && [ "$UPLOAD_FAILED" != true ]; then
	# Find IPA/PKG file
	IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -n 1)
	PKG_FILE=$(find "$EXPORT_PATH" -name "*.pkg" -type f | head -n 1)
	UPLOAD_FILE=""
	PLATFORM_TYPE=""

	# Determine platform and file
	if [ -n "$IPA_FILE" ]; then
		UPLOAD_FILE="$IPA_FILE"
		if [[ "$ARCHIVE_PATH" == *"tvOS"* ]] || [[ "$ARCHIVE_PATH" == *"tvos"* ]]; then
			PLATFORM_TYPE="tvos"
		else
			PLATFORM_TYPE="ios"
		fi
	elif [ -n "$PKG_FILE" ]; then
		UPLOAD_FILE="$PKG_FILE"
		PLATFORM_TYPE="osx"
	fi

	# Try automatic upload if we have API credentials and upload file
	if [ -n "$UPLOAD_FILE" ] && [ -n "$PLATFORM_TYPE" ]; then
		if [ -n "$API_KEY_PATH" ] && [ -n "$API_ISSUER_ID" ] && [ -n "$API_KEY_ID" ]; then
			echo ""
			echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo -e "${YELLOW}Attempting automatic upload with xcrun altool...${NC}"
			echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo ""

			UPLOAD_OUTPUT=$(xcrun altool --upload-app \
				--file "$UPLOAD_FILE" \
				--type "$PLATFORM_TYPE" \
				--apiKey "$API_KEY_ID" \
				--apiIssuer "$API_ISSUER_ID" 2>&1)
			UPLOAD_EXIT_CODE=$?

			if [ "$UPLOAD_EXIT_CODE" -eq 0 ] && echo "$UPLOAD_OUTPUT" | grep -qi "UPLOAD SUCCEEDED"; then
				echo "$UPLOAD_OUTPUT" | grep -E "UPLOAD SUCCEEDED|Delivery UUID|Transferred" || echo "$UPLOAD_OUTPUT"
				echo ""
				echo -e "${GREEN}✓ Upload to App Store Connect completed successfully!${NC}"
				UPLOAD_DETECTED=true
			else
				echo "$UPLOAD_OUTPUT"
				echo ""
				echo -e "${RED}✗ Automatic upload failed.${NC}"
				echo -e "${YELLOW}You can try manual upload using the methods below.${NC}"
				UPLOAD_FAILED=true
			fi
		else
			# No API credentials, show manual upload instructions
			echo ""
			echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo -e "${YELLOW}Manual Upload Required${NC}"
			echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo ""
			echo -e "${YELLOW}Upload was not detected automatically.${NC}"
			echo -e "${YELLOW}File location: $UPLOAD_FILE${NC}"
			echo ""
			echo -e "${GREEN}Method 1: Using Transporter app (Easiest)${NC}"
			echo "  1. Open Transporter app (from Mac App Store)"
			echo "  2. Sign in with your Apple ID"
			echo "  3. Drag and drop: $UPLOAD_FILE"
			echo "  4. Click 'Deliver'"
			echo ""
			echo -e "${GREEN}Method 2: Using xcrun altool${NC}"
			echo "  xcrun altool --upload-app \\"
			echo "    --file \"$UPLOAD_FILE\" \\"
			echo "    --type $PLATFORM_TYPE \\"
			echo "    -u \"YOUR_APPLE_ID\" \\"
			echo "    -p \"YOUR_APP_SPECIFIC_PASSWORD\""
			echo ""
			echo "  Note: App-Specific Password can be created at:"
			echo "  https://appleid.apple.com/account/manage"
			echo ""
		fi
	fi
fi

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
