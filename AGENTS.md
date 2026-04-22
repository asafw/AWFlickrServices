# AWFlickrServices — AI Agent Instructions

## Context file
`.github/CONTEXT.md` is the authoritative project-state document for
AI-assisted development. **Always read it before making any changes.**

## After every session that makes code changes

Before ending the conversation, the AI must:

1. Update `.github/CONTEXT.md`:
   - Latest commit hash + message
   - Updated test counts
   - Any new/changed types, APIs, or invariants
   - Updated commit history block

2. Update `.github/instructions/awflickrservices.instructions.md` if
   architecture, conventions, or public API descriptions changed.

3. Commit both files together — never separately:
   ```bash
   git add .github/CONTEXT.md .github/instructions/awflickrservices.instructions.md
   git commit -m "docs(context): update session state"
   git push origin v2
   ```

## Build / test quick reference

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Unit tests (fast, no network)
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
```

> `swift test` fails with "no such module 'AuthenticationServices'" — always use `xcodebuild`.

All 74 tests must pass after any change.
