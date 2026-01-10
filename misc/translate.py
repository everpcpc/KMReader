#!/usr/bin/env python3

import json
import os
import argparse
import sys

# Path to the xcstrings file relative to the project root
XISTRINGS_PATH = "KMReader/Localizable.xcstrings"


def get_project_root():
    # Assume the script is in 'misc' directory
    return os.path.dirname(
        os.path.dirname(
            os.path.abspath(sys.argv[0] if __name__ == "__main__" else __file__)
        )
    )


def load_data(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_data(file_path, data):
    with open(file_path, "w", encoding="utf-8") as f:
        # Match Xcode formatting: 2 space indent, space BEFORE and AFTER colon
        json.dump(data, f, indent=2, ensure_ascii=False, separators=(",", " : "))


def find_missing(data):
    missing = []
    strings = data.get("strings", {})
    for key, value in strings.items():
        # Case 1: Key is an empty object
        if value == {}:
            missing.append(key)
            continue

        # Case 2: localizations object is empty
        localizations = value.get("localizations", {})
        if not localizations:
            missing.append(key)
            continue

        # Case 3: Any language has an empty object
        for lang, loc in localizations.items():
            if loc == {}:
                missing.append(key)
                break

    return missing


def main():
    parser = argparse.ArgumentParser(description="Translation utility for KMReader")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # List command
    subparsers.add_parser("list", help="List missing translations")

    # Update command
    update_parser = subparsers.add_parser(
        "update", help="Update translations for a key"
    )
    update_parser.add_argument("key", help="The key to update")
    update_parser.add_argument("--zh-hans", help="Simplified Chinese translation")
    update_parser.add_argument("--zh-hant", help="Traditional Chinese translation")
    update_parser.add_argument("--en", help="English translation")
    update_parser.add_argument("--fr", help="French translation")
    update_parser.add_argument("--ja", help="Japanese translation")
    update_parser.add_argument("--ko", help="Korean translation")

    args = parser.parse_args()

    project_root = get_project_root()
    file_path = os.path.join(project_root, XISTRINGS_PATH)

    if not os.path.exists(file_path):
        print(f"Error: Could not find {XISTRINGS_PATH} at {file_path}")
        sys.exit(1)

    data = load_data(file_path)

    if args.command == "list":
        missing = find_missing(data)
        if not missing:
            print("No missing translations found.")
        else:
            print(f"Found {len(missing)} keys with missing translations:")
            for key in missing:
                print(f"  - {key}")

    elif args.command == "update":
        key = args.key
        if key not in data["strings"]:
            data["strings"][key] = {}

        if "localizations" not in data["strings"][key]:
            data["strings"][key]["localizations"] = {}

        translations = {
            "en": args.en,
            "fr": args.fr,
            "ja": args.ja,
            "ko": args.ko,
            "zh-Hans": args.zh_hans,
            "zh-Hant": args.zh_hant,
        }

        updated = False
        for lang, value in translations.items():
            if value:
                data["strings"][key]["localizations"][lang] = {
                    "stringUnit": {"state": "translated", "value": value}
                }
                updated = True

        if updated:
            save_data(file_path, data)
            print(f"Successfully updated translations for '{key}'.")
        else:
            print("No translations provided. Nothing updated.")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
