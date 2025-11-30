# Build Scripts

This directory contains command-line scripts for archiving and exporting KMReader.

## Usage

### Using Makefile (Recommended)

Run from the project root directory:

```bash
# View all available commands
make help

# Archive commands (custom location)
make archive-ios      # iOS platform
make archive-macos    # macOS platform
make archive-tvos     # tvOS platform

# Archive commands (appears in Xcode Organizer)
make archive-ios-organizer      # iOS platform, appears in Organizer
make archive-macos-organizer   # macOS platform, appears in Organizer
make archive-tvos-organizer    # tvOS platform, appears in Organizer

# Export command
make export ARCHIVE=archives/KMReader-iOS_20240101_120000.xcarchive

# Build all platforms (archive + export)
make build-all           # Archive and export all platforms (iOS, macOS, tvOS)
make build-all-organizer # Archive and export all platforms (appears in Organizer)

# Clean commands
make clean-archives   # Remove all archives
make clean-exports    # Remove all exports
make clean            # Remove archives and exports
```

### Using Scripts Directly

```bash
# Archive
./misc/archive.sh [platform] [destination] [--show-in-organizer]
# platform: ios, macos, tvos (default: ios)
# destination: output directory (default: ./archives)
# --show-in-organizer: Save to Xcode's default location (~/Library/Developer/Xcode/Archives/) so it appears in Organizer

# Export
./misc/export.sh [archive_path] [export_options_plist] [destination]

# Build all platforms (archive + export)
./misc/build-all.sh [--show-in-organizer] [--skip-export]
# --show-in-organizer: Save archives to Xcode's default location
# --skip-export: Only create archives, skip export step
```

## Files

- `archive.sh` - Executes xcodebuild archive command to create .xcarchive files
- `export.sh` - Exports archive to IPA/APP files
- `build-all.sh` - Archives and exports all platforms (iOS, macOS, tvOS) in one command
- `exportOptions.plist.example` - Export configuration example file

## Configuring Export Options

**Yes, you need to create and configure your own `exportOptions.plist` file.**

1. Copy the example file:
   ```bash
   cp misc/exportOptions.plist.example misc/exportOptions.plist
   ```

2. Edit `misc/exportOptions.plist` according to your distribution needs:
   - **Required**: `method` - Choose: `app-store`, `ad-hoc`, `enterprise`, or `development`
   - **Recommended**: `teamID` - Your Apple Developer Team ID (found in Xcode Preferences > Accounts)
   - **Optional**: `signingCertificate` - Specific certificate name (if not using Automatic Signing)
   - **Optional**: `provisioningProfiles` - Specific provisioning profiles (if not using Automatic Signing)

3. See `misc/EXPORT_OPTIONS_GUIDE.md` for detailed configuration examples and explanations.

## Output Directories

- Archives (custom): `./archives/` - Stores .xcarchive files when using default archive commands
- Archives (Organizer): `~/Library/Developer/Xcode/Archives/YYYY-MM-DD/` - When using `--show-in-organizer` flag, archives are saved here and appear in Xcode Organizer
- Exports: `./exports/` - Stores exported IPA/APP files

## Notes

- Archive uses Release configuration
- Scripts automatically handle code signing (if configured in the project)
- All output files include timestamps to prevent overwriting
- Use `--show-in-organizer` flag or `*-organizer` make targets to save archives to Xcode's default location, making them visible in Xcode Organizer (Window > Organizer)
