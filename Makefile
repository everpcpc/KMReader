.PHONY: help build build-ios build-macos build-tvos build-ios-ci build-macos-ci build-tvos-ci archive-ios archive-macos archive-tvos archive-ios-organizer archive-macos-organizer archive-tvos-organizer export release release-organizer release-ios release-macos release-tvos artifacts artifact-ios artifact-macos artifact-tvos clean-archives clean-exports clean-artifacts bump major minor patch format localize

# Configuration
SCHEME = KMReader
PROJECT = KMReader.xcodeproj
MISC_DIR = misc
ARCHIVES_DIR = archives
EXPORTS_DIR = exports

# Colors
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "KMReader Build Commands"
	@echo ""
	@echo "Format commands:"
	@echo "  make format           - Format Swift files with swift-format"
	@echo "  make localize         - Scan source code and update Localizable.xcstrings"
	@echo ""
	@echo "Build commands:"
	@echo "  make build           - Build all platforms (iOS, macOS, tvOS)"
	@echo "  make build-ios       - Build for iOS"
	@echo "  make build-macos     - Build for macOS"
	@echo "  make build-tvos      - Build for tvOS"
	@echo ""
	@echo "Archive commands:"
	@echo "  make archive-ios      - Archive for iOS (custom location)"
	@echo "  make archive-macos    - Archive for macOS (custom location)"
	@echo "  make archive-tvos      - Archive for tvOS (custom location)"
	@echo "  make archive-ios-organizer    - Archive for iOS (appears in Xcode Organizer)"
	@echo "  make archive-macos-organizer  - Archive for macOS (appears in Xcode Organizer)"
	@echo "  make archive-tvos-organizer   - Archive for tvOS (appears in Xcode Organizer)"
	@echo ""
	@echo "Export commands:"
	@echo "  make export ARCHIVE=<path> [OPTIONS=<plist>] [DEST=<dir>]"
	@echo "    Example: make export ARCHIVE=archives/KMReader-iOS_20240101_120000.xcarchive"
	@echo ""
	@echo "Build all platforms:"
	@echo "  make release           - Archive and export all platforms (iOS, macOS, tvOS)"
	@echo "  make release-organizer - Archive and export all platforms (appears in Organizer)"
	@echo "  make artifacts         - Build release and prepare artifacts (ipa + dmg) for GitHub Release"
	@echo ""
	@echo "Clean commands:"
	@echo "  make clean-archives   - Remove all archives"
	@echo "  make clean-exports    - Remove all exports"
	@echo "  make clean-artifacts  - Remove prepared artifacts"
	@echo "  make clean            - Remove archives, exports, and artifacts"
	@echo ""
	@echo "Version commands:"
	@echo "  make bump             - Increment CURRENT_PROJECT_VERSION in project.pbxproj"
	@echo "  make major            - Increment major version (MARKETING_VERSION)"
	@echo "  make minor            - Increment minor version (MARKETING_VERSION)"
	@echo ""

build: build-ios build-macos build-tvos ## Build all platforms (iOS, macOS, tvOS)
	@echo "$(GREEN)All platforms built successfully!$(NC)"

build-ios: ## Build for iOS
	@echo "$(GREEN)Building for iOS...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphoneos build -quiet

build-macos: ## Build for macOS
	@echo "$(GREEN)Building for macOS...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk macosx build -quiet

build-tvos: ## Build for tvOS
	@echo "$(GREEN)Building for tvOS...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk appletvos build -quiet

build-ios-ci: ## Build for iOS (CI, uses simulator, no code signing)
	@echo "$(GREEN)Building for iOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

build-macos-ci: ## Build for macOS (CI, no code signing)
	@echo "$(GREEN)Building for macOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk macosx -destination 'platform=macOS' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

build-tvos-ci: ## Build for tvOS (CI, uses simulator, no code signing)
	@echo "$(GREEN)Building for tvOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

archive-ios: ## Archive for iOS
	@echo "$(GREEN)Archiving for iOS...$(NC)"
	@$(MISC_DIR)/archive.sh ios $(ARCHIVES_DIR)

archive-macos: ## Archive for macOS
	@echo "$(GREEN)Archiving for macOS...$(NC)"
	@$(MISC_DIR)/archive.sh macos $(ARCHIVES_DIR)

archive-tvos: ## Archive for tvOS
	@echo "$(GREEN)Archiving for tvOS...$(NC)"
	@$(MISC_DIR)/archive.sh tvos $(ARCHIVES_DIR)

archive-ios-organizer: ## Archive for iOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for iOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh ios --show-in-organizer

archive-macos-organizer: ## Archive for macOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for macOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh macos --show-in-organizer

archive-tvos-organizer: ## Archive for tvOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for tvOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh tvos --show-in-organizer

export: ## Export archive (requires ARCHIVE=<path>)
	@if [ -z "$(ARCHIVE)" ]; then \
		echo "Error: ARCHIVE path is required"; \
		echo "Usage: make export ARCHIVE=<path> [OPTIONS=<plist>] [DEST=<dir>]"; \
		exit 1; \
	fi
	@$(MISC_DIR)/export.sh "$(ARCHIVE)" "$(OPTIONS)" "$(DEST)"

release: ## Archive and export all platforms (iOS, macOS, tvOS)
	@echo "$(GREEN)Building all platforms...$(NC)"
	@$(MISC_DIR)/release.sh

release-organizer: ## Archive and export all platforms (appears in Xcode Organizer)
	@echo "$(GREEN)Building all platforms (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/release.sh --show-in-organizer

release-ios: ## Archive and export iOS only
	@echo "$(GREEN)Building iOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform ios

release-macos: ## Archive and export macOS only
	@echo "$(GREEN)Building macOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform macos

release-tvos: ## Archive and export tvOS only
	@echo "$(GREEN)Building tvOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform tvos

artifacts: ## Prepare artifacts (ipa + dmg) for GitHub Release
	@echo "$(GREEN)Preparing artifacts for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts

artifact-ios: ## Prepare iOS artifact for GitHub Release
	@echo "$(GREEN)Preparing iOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts ios

artifact-macos: ## Prepare macOS artifact for GitHub Release
	@echo "$(GREEN)Preparing macOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts macos

artifact-tvos: ## Prepare tvOS artifact for GitHub Release
	@echo "$(GREEN)Preparing tvOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts tvos

clean-archives: ## Remove all archives
	@echo "$(YELLOW)Cleaning archives...$(NC)"
	@rm -rf $(ARCHIVES_DIR)

clean-exports: ## Remove all exports
	@echo "$(YELLOW)Cleaning exports...$(NC)"
	@rm -rf $(EXPORTS_DIR)

clean-artifacts: ## Remove prepared artifacts
	@echo "$(YELLOW)Cleaning artifacts...$(NC)"
	@rm -rf artifacts

clean: clean-archives clean-exports clean-artifacts ## Remove archives, exports, and artifacts

bump: ## Increment CURRENT_PROJECT_VERSION in project.pbxproj
	@$(MISC_DIR)/bump.sh

major: ## Increment major version (MARKETING_VERSION)
	@$(MISC_DIR)/bump-version.sh major

minor: ## Increment minor version (MARKETING_VERSION)
	@$(MISC_DIR)/bump-version.sh minor

format: ## Format Swift files with swift-format
	@echo "$(GREEN)Formatting Swift files...$(NC)"
	@find . -name "*.swift" -not -path "./DerivedData/*" -not -path "./.build/*" -not -path "./packages/*" | xargs swift-format -i

localize: ## Scan source code and update Localizable.xcstrings
	@echo "$(GREEN)Scanning source code for new strings...$(NC)"
	@xcodebuild -exportLocalizations -localizationPath ./temp_localization -project $(PROJECT) -quiet
	@rm -rf ./temp_localization
	@echo "$(GREEN)Sync completed!$(NC)"
