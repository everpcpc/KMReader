#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from localize_sort import sort_entries, sort_keys

REQUIRED_PLATFORMS = ("ios", "macos", "tvos")
BUILD_DESTINATIONS = {
    "ios": "generic/platform=iOS Simulator",
    "macos": "platform=macOS",
    "tvos": "generic/platform=tvOS Simulator",
}
LOCALIZATION_KEY_ORDER = (
    "de",
    "en",
    "es",
    "fr",
    "it",
    "ja",
    "ko",
    "ru",
    "zh-Hans",
    "zh-Hant",
)


def eprint(message: str) -> None:
    print(message, file=sys.stderr)


def get_project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def parse_build_settings(output: str) -> dict[str, str]:
    settings: dict[str, str] = {}
    for line in output.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        settings[key.strip()] = value.strip()
    return settings


def build_settings_for_platform(project_root: Path, platform: str) -> dict[str, str] | None:
    destination = BUILD_DESTINATIONS[platform]
    args = [
        "xcodebuild",
        "-project",
        str(project_root / "KMReader.xcodeproj"),
        "-scheme",
        "KMReader",
        "-destination",
        destination,
        "-showBuildSettings",
    ]

    try:
        result = subprocess.run(
            args,
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        eprint(f"Error: failed to resolve build settings for {platform}: {exc}")
        if exc.stderr:
            eprint(exc.stderr.strip())
        return None

    return parse_build_settings(result.stdout)


def stringsdata_dir_for_platform(project_root: Path, platform: str) -> Path | None:
    settings = build_settings_for_platform(project_root, platform)
    if settings is None:
        return None

    configuration_temp_dir = settings.get("CONFIGURATION_TEMP_DIR")
    if configuration_temp_dir:
        return Path(configuration_temp_dir)

    target_temp_dir = settings.get("TARGET_TEMP_DIR")
    if target_temp_dir:
        return Path(target_temp_dir).parent

    return None


def iter_stringsdata_files(root: Path) -> list[Path]:
    return list(root.rglob("*.stringsdata"))


def iter_target_stringsdata_files(variant_dir: Path, target_name: str = "KMReader") -> list[Path]:
    target_root = variant_dir / f"{target_name}.build" / "Objects-normal"
    if not target_root.is_dir():
        return []
    return iter_stringsdata_files(target_root)


def iter_explicit_stringsdata_files(root: Path, target_name: str = "KMReader") -> list[Path]:
    target_variant_files = iter_target_stringsdata_files(root, target_name)
    if target_variant_files:
        return target_variant_files

    if root.name == f"{target_name}.build":
        target_root = root / "Objects-normal"
        if target_root.is_dir():
            return iter_stringsdata_files(target_root)

    return iter_stringsdata_files(root)



def load_stringsdata_entries(paths: list[Path]) -> dict:
    tables: dict[str, list[dict]] = {}
    seen: set[tuple[str, str, str]] = set()
    version = None

    for path in paths:
        try:
            with path.open("r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue

        if version is None:
            version = data.get("version")

        for table_name, entries in (data.get("tables") or {}).items():
            if not entries:
                continue
            table = tables.setdefault(table_name, [])
            for entry in entries:
                key = (
                    table_name,
                    entry.get("key"),
                    entry.get("comment") or "",
                )
                if key in seen:
                    continue
                seen.add(key)
                table.append(entry)

    if not tables:
        raise RuntimeError("no strings entries found in stringsdata")

    for entries in tables.values():
        sort_entries(entries)

    return {
        "source": "aggregated",
        "tables": tables,
        "version": version or 1,
    }


def sort_localizations(localizations: dict) -> dict:
    ordered = {}
    seen = set()

    for key in LOCALIZATION_KEY_ORDER:
        if key in localizations:
            ordered[key] = localizations[key]
            seen.add(key)

    for key in sort_keys(k for k in localizations.keys() if k not in seen):
        ordered[key] = localizations[key]

    return ordered


def sort_xcstrings_keys(path: Path, existing_keys: set[str]) -> None:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    strings = data.get("strings")
    if not isinstance(strings, dict):
        return

    new_keys = set(strings.keys()) - existing_keys
    for key in new_keys:
        entry = strings.get(key)
        if not isinstance(entry, dict):
            continue

        localizations = entry.get("localizations")
        if not isinstance(localizations, dict):
            continue

        entry["localizations"] = sort_localizations(localizations)

    data["strings"] = {key: strings[key] for key in sort_keys(strings.keys())}

    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, separators=(",", " : "))


def main() -> int:
    project_root = get_project_root()
    xcstrings_path = project_root / "KMReader" / "Localizable.xcstrings"

    if not xcstrings_path.exists():
        eprint(f"Error: xcstrings not found at {xcstrings_path}")
        return 1

    with xcstrings_path.open("r", encoding="utf-8") as f:
        existing_data = json.load(f)
    existing_strings = existing_data.get("strings")
    existing_keys = set(existing_strings.keys()) if isinstance(existing_strings, dict) else set()

    explicit_strings_dir = os.environ.get("LOCALIZE_STRINGS_DIR")

    if explicit_strings_dir:
        stringsdata_dir = Path(explicit_strings_dir)
        if not stringsdata_dir.is_dir():
            eprint(f"Error: LOCALIZE_STRINGS_DIR is not a directory: {stringsdata_dir}")
            return 1
        stringsdata_dirs = [stringsdata_dir]
        stringsdata_files = iter_explicit_stringsdata_files(stringsdata_dir)
    else:
        stringsdata_dirs_by_platform = {
            platform: stringsdata_dir_for_platform(project_root, platform)
            for platform in REQUIRED_PLATFORMS
        }
        unresolved_platforms = [
            platform
            for platform, directory in stringsdata_dirs_by_platform.items()
            if directory is None
        ]
        if unresolved_platforms:
            eprint(
                "Error: failed to resolve stringsdata directories for platforms: "
                + ", ".join(unresolved_platforms)
            )
            return 1

        stringsdata_dirs = [
            stringsdata_dirs_by_platform[platform] for platform in REQUIRED_PLATFORMS
        ]
        stringsdata_files = []
        for directory in stringsdata_dirs:
            if directory is None:
                continue
            stringsdata_files.extend(iter_target_stringsdata_files(directory))

    if not stringsdata_files:
        dirs_text = ", ".join(str(path) for path in stringsdata_dirs)
        eprint(f"Error: no .stringsdata files found in {dirs_text}")
        eprint("Hint: run a build for KMReader target, then rerun make localize.")
        return 1

    print("Using stringsdata from:")
    for directory in stringsdata_dirs:
        print(f"  - {directory}")

    try:
        merged = load_stringsdata_entries(stringsdata_files)
    except RuntimeError as exc:
        eprint(f"Error: {exc}")
        return 1

    tmp_path = (
        Path(os.environ.get("TMPDIR", "/tmp"))
        / f"kmreader-stringsdata.{os.getpid()}.json"
    )
    try:
        with tmp_path.open("w", encoding="utf-8") as f:
            json.dump(merged, f)

        args = [
            "xcrun",
            "xcstringstool",
            "sync",
            str(xcstrings_path),
            "--stringsdata",
            str(tmp_path),
        ]
        code = os.spawnvp(os.P_WAIT, args[0], args)
        if code == 0:
            sort_xcstrings_keys(xcstrings_path, existing_keys)
        return code
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
