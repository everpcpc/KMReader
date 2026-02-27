---
name: docs
description: Regenerate README.md, APP_STORE_DESCRIPTION.txt, and static/index.html based on current important product features in the codebase.
---

# Docs

Regenerate key project docs from current product capabilities.

## When To Use

- The user asks to refresh project docs after feature changes.
- README and App Store description are outdated.
- Marketing landing content in `static/index.html` needs alignment with current app features.

## Target Files

- `README.md`
- `APP_STORE_DESCRIPTION.txt`
- `static/index.html`

## Scope Rules

- Reflect current important features only.
- Keep product-facing language clear and concise.
- Avoid low-level technical implementation details.
- Keep messaging consistent across all three files.

## Inputs To Read First

- `AGENTS.md` (project capabilities and architecture summary)
- Current target files (to preserve structure where appropriate)
- Relevant feature modules under `KMReader/Features/` when needed

## Update Workflow

1. Collect current user-visible features from codebase and project docs.
2. Decide the most important feature set to present.
3. Update all target files so wording and feature emphasis stay aligned.
4. Keep `README.md` as the most complete overview.
5. Keep `APP_STORE_DESCRIPTION.txt` concise and store-appropriate.
6. Keep `static/index.html` aligned with the same feature priorities.

## Validation

- Ensure all three files mention the same core features.
- Remove stale or no-longer-available claims.
- Keep formatting clean and ready to publish.
