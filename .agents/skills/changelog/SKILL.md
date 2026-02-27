---
name: changelog
description: Generate App Store changelog text from commits between the latest tag and HEAD. Use full commit details, keep user-facing language, sectioned plain text, and exclude technical implementation details.
---

# Changelog

Generate App Store changelog content for end users.

## When To Use

- The user asks for a release changelog.
- The user asks to summarize recent changes for App Store update notes.
- The task is to convert git commits into user-facing release notes.

## Source Range

Use commits from the latest tag to `HEAD`.

```bash
latest_tag=$(git describe --tags --abbrev=0)
git log "${latest_tag}..HEAD" --pretty=format:'%H%n%s%n%b%n---'
```

If no tag exists, use full history and state that assumption.

```bash
git log --pretty=format:'%H%n%s%n%b%n---'
```

## Content Rules

- Read detailed commit bodies, not only commit titles.
- Write for end users in friendly, clear product language.
- Organize output into sections.
- Output plain text only, optimized for copy.
- Do not include emoji.
- Do not include technical implementation details.

## Writing Style

- Focus on user-visible improvements and behavior changes.
- Merge related commits into one coherent item.
- Remove internal terms, file names, class names, and refactor-only details.
- Keep each bullet concise and meaningful.

## Output

Default output is changelog text only.

If the user asks to update a file, write the final content to `APP_STORE_CHANGELOG.txt`.
