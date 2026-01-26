#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path

from localize_sort import sort_entries


def eprint(message: str) -> None:
    print(message, file=sys.stderr)


def get_project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def get_latest_derived_dir(derived_root: Path) -> Path | None:
    candidates = sorted(
        derived_root.glob("KMReader-*"), key=lambda p: p.stat().st_mtime, reverse=True
    )
    return candidates[0] if candidates else None


def iter_stringsdata_files(root: Path) -> list[Path]:
    return list(root.rglob("*.stringsdata"))


def select_latest_stringsdata_dir(stringsdata_files: list[Path]) -> Path | None:
    latest_file = None
    latest_mtime = -1.0
    for path in stringsdata_files:
        try:
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if mtime > latest_mtime:
            latest_mtime = mtime
            latest_file = path
    return latest_file.parent if latest_file else None


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


def main() -> int:
    project_root = get_project_root()
    xcstrings_path = project_root / "KMReader" / "Localizable.xcstrings"

    if not xcstrings_path.exists():
        eprint(f"Error: xcstrings not found at {xcstrings_path}")
        return 1

    derived_root = Path(
        os.environ.get(
            "LOCALIZE_DERIVED_DATA_ROOT",
            Path.home() / "Library/Developer/Xcode/DerivedData",
        )
    )
    explicit_derived_dir = os.environ.get("LOCALIZE_DERIVED_DATA")

    if explicit_derived_dir:
        derived_dir = Path(explicit_derived_dir)
    else:
        derived_dir = get_latest_derived_dir(derived_root)

    if not derived_dir or not derived_dir.exists():
        eprint(f"Error: DerivedData for KMReader not found under {derived_root}")
        eprint("Hint: set LOCALIZE_DERIVED_DATA to an existing DerivedData path.")
        return 1

    stringsdata_root = derived_dir / "Build/Intermediates.noindex/KMReader.build"
    explicit_strings_dir = os.environ.get("LOCALIZE_STRINGS_DIR")

    if explicit_strings_dir:
        stringsdata_dir = Path(explicit_strings_dir)
        if not stringsdata_dir.is_dir():
            eprint(f"Error: LOCALIZE_STRINGS_DIR is not a directory: {stringsdata_dir}")
            return 1
        stringsdata_files = iter_stringsdata_files(stringsdata_dir)
    else:
        if not stringsdata_root.exists():
            eprint(f"Error: no KMReader build intermediates found under {derived_dir}")
            eprint("Hint: run a build for KMReader target, then rerun make localize.")
            return 1
        stringsdata_files = list(
            stringsdata_root.glob("**/KMReader.build/Objects-normal/*/*.stringsdata")
        )

    if not stringsdata_files:
        eprint("Error: no .stringsdata files found for KMReader target")
        eprint(
            "Hint: run a build for the platform you want included, then rerun make localize."
        )
        return 1

    if explicit_strings_dir:
        stringsdata_dir = Path(explicit_strings_dir)
    else:
        stringsdata_dir = select_latest_stringsdata_dir(stringsdata_files)
        if not stringsdata_dir:
            eprint("Error: unable to select latest stringsdata directory")
            return 1
        stringsdata_files = iter_stringsdata_files(stringsdata_dir)

    if not stringsdata_files:
        eprint(f"Error: no .stringsdata files found in {stringsdata_dir}")
        eprint("Hint: run a build for KMReader target, then rerun make localize.")
        return 1

    print(f"Using stringsdata from {stringsdata_dir}")

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
            "--skip-marking-strings-stale",
        ]

        return os.spawnvp(os.P_WAIT, args[0], args)
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
