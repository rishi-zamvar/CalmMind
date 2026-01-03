# CalmMind

Personal AI Mental Health Companion for iOS.

## Overview

CalmMind is a privacy-first iOS app that provides:
- **AI Chat Companion** - Daily conversations with an empathetic AI
- **Journaling** - Auto-generated entries from your conversations
- **Todo List** - Tasks extracted from chat and managed manually
- **Notifications** - Gentle morning and evening check-in nudges
- **Widget** - Home screen widget for quick access

## Privacy First

- All data stored locally on device
- API key stored in Keychain (never in code)
- Only conversation summaries sent to OpenAI (never full journals)
- Crisis detection happens locally (bypasses AI entirely)

## Requirements

- iOS 17.0+
- Xcode 15+
- OpenAI API key

## Getting Started

1. Clone the repository
2. Open `CalmMind.xcodeproj` in Xcode
3. Build and run
4. Enter your OpenAI API key in Settings

## Architecture

- **SwiftUI** - All views
- **SwiftData** - Local persistence
- **OpenAI API** - Chat completions with streaming

## Safety

This app handles sensitive mental health conversations. Safety is non-negotiable:

- Crisis messages bypass the AI and show pre-written supportive responses
- Crisis hotline resources are always available
- No medical advice or diagnoses are provided
- User feelings are always validated

## Claude Code Workflow

This project uses Claude Code agentic hooks for iterative, test-driven development.

### How It Works

1. **Hooks live in `.claude/`** - Claude reads these before/after every action
2. **Scripts run tests** - Same commands as CI, ensuring local-CI parity
3. **Policies enforce rules** - Safety contract, coding standards, scope limits

### Hooks Overview

| Hook | When | Purpose |
|------|------|---------|
| `pre_plan.md` | Before planning | Read plan, check current phase |
| `pre_change.md` | Before code changes | Safety checklist, scope limiter |
| `post_change.md` | After code changes | Run tests, verify safety |
| `post_test.md` | After tests run | Parse results, decide next action |
| `on_failure.md` | When tests fail | Recovery protocol, prohibitions |

### Key Scripts

```bash
.claude/scripts/run_unit_tests.sh    # Run unit tests (mirrors CI)
.claude/scripts/run_ui_smoke.sh      # Run UI smoke tests
.claude/scripts/check_safety.sh      # Check for safety violations
.claude/scripts/summarize_failures.sh # Parse test failures
```

### Agentic Loop

```
[Plan] -> [Write Test] -> [Run Test (Fail)] -> [Implement] -> [Run Test (Pass)] -> [Commit]
   ^                                                                                   |
   +------------------------------- [Next Commit] <-----------------------------------+
```

### After Updating CI

If you change `.github/workflows/ci.yml`, update `.claude/scripts/` to match.
Hooks must run the same commands as CI.

## License

Private - All Rights Reserved
