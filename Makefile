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
	@echo "  make localize         - Sync Localizable.xcstrings from stringsdata"
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
	@$(MAKE) localize
	@echo "$(GREEN)iOS built successfully!$(NC)"

build-macos: ## Build for macOS
	@echo "$(GREEN)Building for macOS...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk macosx build -quiet
	@$(MAKE) localize
	@echo "$(GREEN)macOS built successfully!$(NC)"

build-tvos: ## Build for tvOS
	@echo "$(GREEN)Building for tvOS...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk appletvos build -quiet
	@$(MAKE) localize
	@echo "$(GREEN)tvOS built successfully!$(NC)"

build-ios-ci: ## Build for iOS (CI, uses simulator, no code signing)
	@echo "$(GREEN)Building for iOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	@echo "$(GREEN)iOS (CI) built successfully!$(NC)"

build-macos-ci: ## Build for macOS (CI, no code signing)
	@echo "$(GREEN)Building for macOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk macosx -destination 'platform=macOS' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	@echo "$(GREEN)macOS (CI) built successfully!$(NC)"

build-tvos-ci: ## Build for tvOS (CI, uses simulator, no code signing)
	@echo "$(GREEN)Building for tvOS (CI)...$(NC)"
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' build -quiet CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	@echo "$(GREEN)tvOS (CI) built successfully!$(NC)"

archive-ios: ## Archive for iOS
	@echo "$(GREEN)Archiving for iOS...$(NC)"
	@$(MISC_DIR)/archive.sh ios $(ARCHIVES_DIR)
	@echo "$(GREEN)iOS archived successfully!$(NC)"

archive-macos: ## Archive for macOS
	@echo "$(GREEN)Archiving for macOS...$(NC)"
	@$(MISC_DIR)/archive.sh macos $(ARCHIVES_DIR)
	@echo "$(GREEN)macOS archived successfully!$(NC)"

archive-tvos: ## Archive for tvOS
	@echo "$(GREEN)Archiving for tvOS...$(NC)"
	@$(MISC_DIR)/archive.sh tvos $(ARCHIVES_DIR)
	@echo "$(GREEN)tvOS archived successfully!$(NC)"

archive-ios-organizer: ## Archive for iOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for iOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh ios --show-in-organizer
	@echo "$(GREEN)iOS archived successfully!$(NC)"

archive-macos-organizer: ## Archive for macOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for macOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh macos --show-in-organizer
	@echo "$(GREEN)macOS archived successfully!$(NC)"

archive-tvos-organizer: ## Archive for tvOS (appears in Xcode Organizer)
	@echo "$(GREEN)Archiving for tvOS (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/archive.sh tvos --show-in-organizer
	@echo "$(GREEN)tvOS archived successfully!$(NC)"

export: ## Export archive (requires ARCHIVE=<path>)
	@if [ -z "$(ARCHIVE)" ]; then \
		echo "Error: ARCHIVE path is required"; \
		echo "Usage: make export ARCHIVE=<path> [OPTIONS=<plist>] [DEST=<dir>]"; \
		exit 1; \
	fi
	@$(MISC_DIR)/export.sh "$(ARCHIVE)" "$(OPTIONS)" "$(DEST)"
	@echo "$(GREEN)Exported successfully!$(NC)"

release: ## Archive and export all platforms (iOS, macOS, tvOS)
	@echo "$(GREEN)Building all platforms...$(NC)"
	@$(MISC_DIR)/release.sh
	@echo "$(GREEN)All platforms built successfully!$(NC)"

release-organizer: ## Archive and export all platforms (appears in Xcode Organizer)
	@echo "$(GREEN)Building all platforms (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/release.sh --show-in-organizer
	@echo "$(GREEN)All platforms built successfully!$(NC)"

release-ios: ## Archive and export iOS only
	@echo "$(GREEN)Building iOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform ios
	@echo "$(GREEN)iOS built successfully!$(NC)"

release-macos: ## Archive and export macOS only
	@echo "$(GREEN)Building macOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform macos
	@echo "$(GREEN)macOS built successfully!$(NC)"

release-tvos: ## Archive and export tvOS only
	@echo "$(GREEN)Building tvOS...$(NC)"
	@$(MISC_DIR)/release.sh --platform tvos
	@echo "$(GREEN)tvOS built successfully!$(NC)"

artifacts: ## Prepare artifacts (ipa + dmg) for GitHub Release
	@echo "$(GREEN)Preparing artifacts for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts
	@echo "$(GREEN)Artifacts prepared successfully!$(NC)"

artifact-ios: ## Prepare iOS artifact for GitHub Release
	@echo "$(GREEN)Preparing iOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts ios
	@echo "$(GREEN)iOS artifact prepared successfully!$(NC)"

artifact-macos: ## Prepare macOS artifact for GitHub Release
	@echo "$(GREEN)Preparing macOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts macos
	@echo "$(GREEN)macOS artifact prepared successfully!$(NC)"

artifact-tvos: ## Prepare tvOS artifact for GitHub Release
	@echo "$(GREEN)Preparing tvOS artifact for GitHub Release...$(NC)"
	@$(MISC_DIR)/artifacts.sh $(EXPORTS_DIR) artifacts tvos
	@echo "$(GREEN)tvOS artifact prepared successfully!$(NC)"

clean-archives: ## Remove all archives
	@echo "$(YELLOW)Cleaning archives...$(NC)"
	@rm -rf $(ARCHIVES_DIR)
	@echo "$(GREEN)Archives cleaned successfully!$(NC)"

clean-exports: ## Remove all exports
	@echo "$(YELLOW)Cleaning exports...$(NC)"
	@rm -rf $(EXPORTS_DIR)
	@echo "$(GREEN)Exports cleaned successfully!$(NC)"

clean-artifacts: ## Remove prepared artifacts
	@echo "$(YELLOW)Cleaning artifacts...$(NC)"
	@rm -rf artifacts
	@echo "$(GREEN)Artifacts cleaned successfully!$(NC)"

clean: clean-archives clean-exports clean-artifacts ## Remove archives, exports, and artifacts
	@echo "$(GREEN)Cleaned archives, exports, and artifacts successfully!$(NC)"
	
	

bump: ## Increment CURRENT_PROJECT_VERSION in project.pbxproj
	@$(MISC_DIR)/bump.sh

major: ## Increment major version (MARKETING_VERSION)
	@$(MISC_DIR)/bump-version.sh major

minor: ## Increment minor version (MARKETING_VERSION)
	@$(MISC_DIR)/bump-version.sh minor

format: ## Format Swift files with swift-format
	@echo "$(GREEN)Formatting Swift files...$(NC)"
	@find . -name "*.swift" -not -path "./DerivedData/*" -not -path "./.build/*" -not -path "./packages/*" | xargs swift-format -i
	@echo "$(GREEN)Formatted Swift files successfully!$(NC)"

localize: ## Sync Localizable.xcstrings from stringsdata
	@echo "$(GREEN)Syncing Localizable.xcstrings from stringsdata...$(NC)"
	@python3 $(MISC_DIR)/localize.py
	@echo "$(GREEN)Sync localizable strings successfully!$(NC)"
