#!/bin/bash

# Bump version script for KMReader
# Usage: ./bump.sh
# Increments CURRENT_PROJECT_VERSION in project.pbxproj
# Requires a clean git working directory

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
PROJECT="$PROJECT_ROOT/KMReader.xcodeproj/project.pbxproj"

# Check if git working directory is clean
cd "$PROJECT_ROOT"
if [ -n "$(git status --porcelain)" ]; then
	echo -e "${RED}Error: Working directory is not clean. Please commit or stash your changes first.${NC}"
	exit 1
fi

echo -e "${GREEN}Bumping version...${NC}"

# Extract current version
CURRENT_VERSION=$(grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT" | sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/p')

if [ -z "$CURRENT_VERSION" ]; then
	echo -e "${YELLOW}Error: Could not find CURRENT_PROJECT_VERSION${NC}"
	exit 1
fi

# Calculate next version
NEXT_VERSION=$((CURRENT_VERSION + 1))

echo -e "${GREEN}Current version: $CURRENT_VERSION -> Next version: $NEXT_VERSION${NC}"

# Update all occurrences of CURRENT_PROJECT_VERSION
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_VERSION;/CURRENT_PROJECT_VERSION = $NEXT_VERSION;/g" "$PROJECT"

echo -e "${GREEN}Version bumped successfully!${NC}"

# Commit the changes
echo -e "${GREEN}Committing changes...${NC}"
git add "$PROJECT"
git commit -m "chore: incr build ver to $NEXT_VERSION"

echo -e "${GREEN}Version bump committed!${NC}"
