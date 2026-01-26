#!/usr/bin/env python3

import json
import os
import argparse
import sys

from localize_sort import sort_keys


# Path to the xcstrings file relative to the project root
XISTRINGS_PATH = "KMReader/Localizable.xcstrings"
REQUIRED_LANGUAGES = ["de", "en", "fr", "ja", "ko", "zh-Hans", "zh-Hant"]


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


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


def sort_strings(data):
    strings = data.get("strings")
    if not isinstance(strings, dict):
        return
    data["strings"] = {key: strings[key] for key in sort_keys(strings.keys())}


def find_missing(data):
    missing = []
    strings = data.get("strings", {})
    for key, value in strings.items():
        if value.get("shouldTranslate") is False:
            continue

        localizations = value.get("localizations", {})
        missing_langs = []
        for lang in REQUIRED_LANGUAGES:
            if lang not in localizations:
                missing_langs.append(lang)
                continue

            loc = localizations[lang]
            if (
                not loc
                or "stringUnit" not in loc
                or loc.get("stringUnit", {}).get("state") != "translated"
            ):
                missing_langs.append(lang)

        if missing_langs:
            missing.append((key, missing_langs))

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
    update_parser.add_argument("--de", help="German translation")
    update_parser.add_argument("--en", help="English translation")
    update_parser.add_argument("--fr", help="French translation")
    update_parser.add_argument("--ja", help="Japanese translation")
    update_parser.add_argument("--ko", help="Korean translation")
    update_parser.add_argument("--zh-hans", help="Simplified Chinese translation")
    update_parser.add_argument("--zh-hant", help="Traditional Chinese translation")

    args = parser.parse_args()

    project_root = get_project_root()
    file_path = os.path.join(project_root, XISTRINGS_PATH)

    if not os.path.exists(file_path):
        eprint(f"Error: Could not find {XISTRINGS_PATH} at {file_path}")
        sys.exit(1)

    data = load_data(file_path)

    if args.command == "list":
        missing = find_missing(data)
        if not missing:
            eprint("No missing translations found.")
        else:
            eprint(f"Found {len(missing)} keys with missing translations:")
            for key, langs in missing:
                print(f"  - {key} ({', '.join(langs)})")

    elif args.command == "update":
        key = args.key
        if key not in data["strings"]:
            eprint(
                f"Key '{key}' not found in strings. Available keys (first 10): {list(data['strings'].keys())[:10]}",
            )
            eprint(f"Total keys: {len(data['strings'])}")
            data["strings"][key] = {"localizations": {}}

        if "localizations" not in data["strings"][key]:
            data["strings"][key]["localizations"] = {}

        localizations = data["strings"][key]["localizations"]
        eprint(f"Existing translations for '{key}': {list(localizations.keys())}")

        translations = {
            "de": args.de,
            "en": args.en,
            "fr": args.fr,
            "ja": args.ja,
            "ko": args.ko,
            "zh-Hans": args.zh_hans,
            "zh-Hant": args.zh_hant,
        }

        updated_langs = []
        for lang, value in translations.items():
            if value is not None and value.strip() != "":
                localizations[lang] = {
                    "stringUnit": {"state": "translated", "value": value}
                }
                updated_langs.append(lang)

        if updated_langs:
            sort_strings(data)
            save_data(file_path, data)
            eprint(
                f"Successfully updated {len(updated_langs)} translations for '{key}': {updated_langs}"
            )
            eprint(f"Final translations list: {list(localizations.keys())}")
        else:
            eprint("No translations provided. Nothing updated.")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
