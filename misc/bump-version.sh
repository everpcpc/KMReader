#!/bin/bash

# Bump marketing version script for KMReader
# Usage: ./bump-version.sh [major|minor]
# Increments MARKETING_VERSION in project.pbxproj (two-digit version: major.minor)
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

# Check argument
if [ -z "$1" ]; then
	echo -e "${RED}Error: Version type is required${NC}"
	echo "Usage: $0 [major|minor]"
	exit 1
fi

VERSION_TYPE="$1"

if [ "$VERSION_TYPE" != "major" ] && [ "$VERSION_TYPE" != "minor" ]; then
	echo -e "${RED}Error: Version type must be 'major' or 'minor'${NC}"
	exit 1
fi

# Check if git working directory is clean
cd "$PROJECT_ROOT"
if [ -n "$(git status --porcelain)" ]; then
	echo -e "${RED}Error: Working directory is not clean. Please commit or stash your changes first.${NC}"
	exit 1
fi

echo -e "${GREEN}Bumping $VERSION_TYPE version...${NC}"

# Extract current version
CURRENT_VERSION=$(grep -m 1 "MARKETING_VERSION = " "$PROJECT" | sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' | tr -d '"')
CURRENT_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT" | sed -n 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);/\1/p' | tr -d '"')

if [ -z "$CURRENT_VERSION" ]; then
	echo -e "${YELLOW}Error: Could not find MARKETING_VERSION${NC}"
	exit 1
fi
if [ -z "$CURRENT_BUILD" ]; then
	echo -e "${YELLOW}Error: Could not find CURRENT_PROJECT_VERSION${NC}"
	exit 1
fi

# Parse version components (two-digit format: major.minor)
IFS='.' read -ra VERSION_PARTS <<<"$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"

# Calculate next version
if [ "$VERSION_TYPE" == "major" ]; then
	MAJOR=$((MAJOR + 1))
	MINOR=0
elif [ "$VERSION_TYPE" == "minor" ]; then
	MINOR=$((MINOR + 1))
fi

NEXT_VERSION="$MAJOR.$MINOR"
NEXT_BUILD=$((CURRENT_BUILD + 1))

echo -e "${GREEN}Current version: $CURRENT_VERSION -> Next version: $NEXT_VERSION${NC}"
echo -e "${GREEN}Current build: $CURRENT_BUILD -> Next build: $NEXT_BUILD${NC}"

# Update all occurrences of MARKETING_VERSION
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $NEXT_VERSION;/g" "$PROJECT"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/g" "$PROJECT"

echo -e "${GREEN}Version bumped successfully!${NC}"

# Commit the changes
echo -e "${GREEN}Committing changes...${NC}"
git add "$PROJECT"
git commit -m "chore: bump version to $NEXT_VERSION"

echo -e "${GREEN}Version bump committed!${NC}"
