.PHONY: help archive-ios archive-macos archive-tvos archive-ios-organizer archive-macos-organizer archive-tvos-organizer export build-all build-all-organizer clean-archives clean-exports

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
	@echo "  make build-all           - Archive and export all platforms (iOS, macOS, tvOS)"
	@echo "  make build-all-organizer - Archive and export all platforms (appears in Organizer)"
	@echo ""
	@echo "Clean commands:"
	@echo "  make clean-archives   - Remove all archives"
	@echo "  make clean-exports    - Remove all exports"
	@echo "  make clean            - Remove archives and exports"
	@echo ""

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

build-all: ## Archive and export all platforms (iOS, macOS, tvOS)
	@echo "$(GREEN)Building all platforms...$(NC)"
	@$(MISC_DIR)/build-all.sh

build-all-organizer: ## Archive and export all platforms (appears in Xcode Organizer)
	@echo "$(GREEN)Building all platforms (will appear in Organizer)...$(NC)"
	@$(MISC_DIR)/build-all.sh --show-in-organizer

clean-archives: ## Remove all archives
	@echo "$(YELLOW)Cleaning archives...$(NC)"
	@rm -rf $(ARCHIVES_DIR)

clean-exports: ## Remove all exports
	@echo "$(YELLOW)Cleaning exports...$(NC)"
	@rm -rf $(EXPORTS_DIR)

clean: clean-archives clean-exports ## Remove archives and exports
