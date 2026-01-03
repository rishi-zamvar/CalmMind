# CalmMind - Personal AI Mental Health Companion
## Production-Grade TDD Implementation Plan

**Target:** iOS 17+ | **Language:** Swift/SwiftUI | **AI:** OpenAI GPT-4
**Philosophy:** Tests first, commit-level discipline, safe by default

---

## Safe By Design Checklist (Enforced by Tests)

- [ ] No API key in repo, logs, crashes, UI screenshots
- [ ] No raw journal archive sent to OpenAI (summaries only)
- [ ] Tool calls validated and schema-checked
- [ ] Rate limiting and retries capped
- [ ] Crisis flow overrides LLM (deterministic, local)
- [ ] Notification content respects privacy mode
- [ ] Network failure never deletes user data
- [ ] AI failure never blocks journaling/todos
- [ ] Partial writes disallowed (transactional saves)
- [ ] Send operation atomic: user message saved BEFORE API call

---

## Project Structure

```
CalmMind/
├── App/
│   ├── CalmMindApp.swift
│   └── ContentView.swift
├── Config/
│   ├── AppConfig.swift              # Info.plist typed wrapper
│   ├── SecretsStore.swift           # Keychain wrapper
│   └── UserPreferences.swift        # UserDefaults typed wrapper
├── Models/
│   ├── ChatMessage.swift
│   ├── JournalEntry.swift
│   ├── DailySession.swift
│   ├── TodoItem.swift
│   └── MemoryItem.swift
├── Repositories/
│   ├── MessageRepository.swift
│   ├── JournalRepository.swift
│   ├── TodoRepository.swift
│   ├── MemoryRepository.swift
│   └── SessionRepository.swift
├── Services/
│   ├── Network/
│   │   ├── OpenAIServiceProtocol.swift
│   │   ├── OpenAIService.swift
│   │   ├── RateLimiter.swift
│   │   └── RetryPolicy.swift
│   ├── AI/
│   │   ├── AIOrchestrator.swift
│   │   ├── ContextManager.swift
│   │   ├── ContextRedactor.swift    # Enforces data egress contract
│   │   └── JournalGenerator.swift
│   ├── Safety/
│   │   ├── SafetyClassifier.swift   # Local rules + keyword detection
│   │   ├── CrisisResponseComposer.swift
│   │   └── CrisisResources.swift
│   ├── Tools/
│   │   ├── ToolRegistry.swift       # MCP-style tool definitions
│   │   ├── ToolValidator.swift
│   │   ├── TodoTools.swift
│   │   └── JournalTools.swift
│   └── Notifications/
│       ├── NotificationScheduler.swift
│       ├── NudgeComposer.swift
│       └── CheckInStateMachine.swift
├── Validation/
│   ├── MessageValidator.swift
│   ├── TodoTitleNormalizer.swift
│   └── JournalConstraints.swift
├── Views/
│   ├── Chat/
│   ├── Journal/
│   ├── Todo/
│   ├── Settings/
│   └── Onboarding/
├── ViewModels/
│   ├── ChatViewModel.swift
│   ├── JournalViewModel.swift
│   └── TodoViewModel.swift
├── Widget/
│   ├── WidgetSnapshotStore.swift    # App Group shared state
│   └── CalmMindWidget/
├── Services/
│   └── Encryption/
│       ├── DataProtectionValidator.swift
│       └── FieldEncryptor.swift     # CryptoKit AES-GCM (optional)
└── Resources/
    ├── CrisisHotlines.json
    └── NudgeTemplates.json          # Morning/evening nudge text variants

CalmMindTests/
├── Unit/
│   ├── Config/
│   │   ├── AppConfigTests.swift
│   │   └── SecretsStoreTests.swift
│   ├── Validation/
│   │   ├── MessageValidatorTests.swift
│   │   └── TodoTitleNormalizerTests.swift
│   ├── Models/
│   │   ├── ChatMessageTests.swift
│   │   ├── JournalEntryTests.swift
│   │   ├── DailySessionTests.swift
│   │   ├── TodoItemTests.swift
│   │   └── MemoryItemTests.swift
│   ├── Repositories/
│   │   └── *RepositoryTests.swift
│   ├── Services/
│   │   ├── OpenAIServiceTests.swift
│   │   ├── RateLimiterTests.swift
│   │   ├── RetryPolicyTests.swift
│   │   ├── SafetyClassifierTests.swift
│   │   ├── ContextManagerTests.swift
│   │   ├── ContextRedactorTests.swift
│   │   ├── ToolRegistryTests.swift
│   │   ├── AIOrchestratorTests.swift
│   │   └── JournalGeneratorTests.swift
│   └── ViewModels/
│       ├── ChatViewModelTests.swift
│       ├── JournalViewModelTests.swift
│       └── TodoViewModelTests.swift
├── Integration/
│   ├── SendFlowIntegrationTests.swift
│   ├── JournalFlowIntegrationTests.swift
│   ├── CrisisFlowIntegrationTests.swift
│   └── ToolCallIntegrationTests.swift
└── Mocks/
    ├── MockOpenAIService.swift
    ├── MockSecretsStore.swift
    ├── MockURLSession.swift
    └── TestData.swift

CalmMindUITests/
├── ChatUITests.swift
├── JournalUITests.swift
├── TodoUITests.swift
└── OnboardingUITests.swift
```

---

## Phase 0: Repo + CI + Safety Rails + Claude Hooks

**Exit Criteria:** PR required, CI required, no secrets in repo, Claude hooks active

**IMPORTANT - iOS Secrets Philosophy:**
- iOS apps do NOT use `.env` files at runtime (unlike Node.js/Python)
- **Runtime secrets** (API keys): Stored in **Keychain**, entered by user in-app
- **Build-time config** (non-secrets): Use `.xcconfig` files (gitignored if sensitive)
- **No secrets in code, Info.plist, or git** - enforced by preflight script

### Commit 0.1: `chore: init repo structure + gitignore + readme`
**Files:**
- `.gitignore` (Swift, Xcode, secrets patterns, `*.xcconfig` for local overrides)
- `README.md` (project overview)
- `CONTRIBUTING.md` (commit conventions)

### Commit 0.1.5: `chore: add Claude Code agentic hooks`

**Purpose:** Enable Claude to work iteratively with test feedback, safety checks, and self-correction.

**Directory Structure:**
```
CalmMind/
├── .claude/
│   ├── settings.json           # Claude Code project settings
│   ├── hooks/
│   │   ├── pre_plan.md         # Read before planning any changes
│   │   ├── pre_change.md       # Read before making code changes
│   │   ├── post_change.md      # Run after each code change
│   │   ├── post_test.md        # Run after test execution
│   │   └── on_failure.md       # Run when tests fail
│   ├── policies/
│   │   ├── repo_rules.md       # Repository-wide coding standards
│   │   └── safety_contract.md  # Mental health app safety requirements
│   └── scripts/
│       ├── run_unit_tests.sh   # Execute unit test suite
│       ├── run_ui_smoke.sh     # Execute UI smoke tests
│       ├── check_safety.sh     # Verify safety constraints
│       └── summarize_failures.sh # Parse test failures for Claude
```

**File Contents:**

#### `.claude/settings.json`
```json
{
  "project_name": "CalmMind",
  "test_command": ".claude/scripts/run_unit_tests.sh",
  "ui_test_command": ".claude/scripts/run_ui_smoke.sh",
  "safety_check_command": ".claude/scripts/check_safety.sh",
  "auto_run_tests_after_change": true,
  "max_consecutive_failures": 3,
  "require_tests_pass_before_commit": true,
  "ci_equivalence": {
    "note": "These scripts MUST match CI workflow commands exactly",
    "ci_workflow_file": ".github/workflows/ci.yml",
    "local_scripts_must_mirror_ci": true
  }
}
```

#### CI Equivalence Rule
```markdown
Scripts in `.claude/scripts/` MUST run the same commands as `.github/workflows/ci.yml`.

If CI uses:
  xcodebuild test -scheme CalmMind -destination 'platform=iOS Simulator,name=iPhone 15'

Then `.claude/scripts/run_unit_tests.sh` MUST use the same command.

**Why:** Green locally but red in CI is a failure mode. The agentic loop must
catch what CI catches.

**Maintenance:** When CI workflow changes, update scripts immediately.
```

#### `.claude/hooks/pre_plan.md`
```markdown
# Pre-Plan Hook

Before planning any changes, Claude MUST:

1. **Read the implementation plan** at `.claude/plans/glittery-crunching-crystal.md`
2. **Identify current phase** - which phase are we in?
3. **Check test status** - run `.claude/scripts/run_unit_tests.sh`
4. **Verify safety contract** - read `.claude/policies/safety_contract.md`

## Planning Rules
- Write tests FIRST (TDD) - never implement without tests
- One commit at a time - follow commit granularity in plan
- Mental health safety is non-negotiable - crisis detection bypasses LLM
- No secrets in code - API keys go in Keychain only
```

#### `.claude/hooks/pre_change.md`
```markdown
# Pre-Change Hook

Before making ANY code change, Claude MUST verify:

## Safety Checklist
- [ ] This change does NOT introduce hardcoded secrets
- [ ] This change does NOT send raw journal text to OpenAI
- [ ] This change does NOT bypass crisis detection
- [ ] This change has corresponding tests written FIRST

## TDD Workflow
1. Write failing test(s) first
2. Verify test fails for the right reason
3. Implement minimum code to pass
4. Refactor if needed
5. Verify all tests pass

## SCOPE LIMITER (Critical)

**Identify current commit from plan:**
1. Read `.claude/plans/glittery-crunching-crystal.md`
2. Find current commit (e.g., "Commit 3.2")
3. ONLY modify files listed in that commit

**Allowed files per commit (examples):**
- Commit 1.2 → ONLY: `Config/SecretsStore.swift`, `Mocks/MockSecretsStore.swift`
- Commit 4.1 → ONLY: `Services/Safety/SafetyClassifier.swift`
- Commit 9.3 → ONLY: `Services/Notifications/NudgeComposer.swift`

**If tempted to modify other files:**
- STOP
- Ask: "Is this file in my current commit scope?"
- If NO → Do NOT modify it
- If it seems necessary → Ask user first

## File Change Rules
- Only modify files relevant to current commit scope
- Do not refactor unrelated code
- Do not add features not in the plan
- Preserve existing test coverage
- Do not "fix" code outside your commit scope
```

#### `.claude/hooks/post_change.md`
```markdown
# Post-Change Hook

After EVERY code change, Claude MUST:

1. **Run unit tests**: `.claude/scripts/run_unit_tests.sh`
2. **Check for safety violations**: `.claude/scripts/check_safety.sh`
3. **Review changes**: Ensure only intended files were modified

## On Test Failure
- Do NOT proceed to next task
- Read `.claude/hooks/on_failure.md`
- Fix the failing test before continuing

## On Test Pass
- Mark task as complete
- Proceed to next commit in phase
- Update progress in plan if needed
```

#### `.claude/hooks/post_test.md`
```markdown
# Post-Test Hook

After test execution completes:

## If ALL tests pass:
- Confirm changes are ready for commit
- Verify commit message matches plan convention
- Proceed to next task

## If ANY tests fail:
- Run `.claude/scripts/summarize_failures.sh`
- Analyze failure output
- Identify root cause (not symptoms)
- Fix and re-test before proceeding

## Test Output Interpretation
- Look for: assertion failures, crashes, timeouts
- Check: test isolation (one test affecting another)
- Verify: mocks are properly configured
```

#### `.claude/hooks/on_failure.md`
```markdown
# On Failure Hook

When tests fail, Claude MUST follow this recovery protocol:

## Step 1: Diagnose
- Read full error message
- Identify which test(s) failed
- Determine if failure is in test or implementation

## Step 2: Classify Failure Type
- **Compilation error**: Fix syntax/type issues first
- **Assertion failure**: Implementation doesn't match expected behavior
- **Crash**: Nil unwrap, index out of bounds, etc.
- **Timeout**: Async issue or infinite loop

## Step 3: Fix Strategy
- Make minimal change to fix
- Do NOT add unrelated changes
- Re-run ONLY failed tests first: `xcodebuild test -only-testing:CalmMindTests/<TestClass>/<testMethod>`
- Then run full suite

## Step 4: Verify Fix
- All previously passing tests still pass
- Failed test(s) now pass
- No new failures introduced

## Max Retries
- If same test fails 3 times with different fixes, STOP
- Ask user for guidance
- Do not spiral into random changes

## ABSOLUTE PROHIBITIONS (Never Do These)
- ❌ NEVER delete or comment out failing assertions
- ❌ NEVER weaken test expectations (e.g., change `XCTAssertEqual` to `XCTAssertNotNil`)
- ❌ NEVER skip/disable tests with `XCTSkip` or by renaming
- ❌ NEVER remove test methods
- ❌ NEVER change expected values to match buggy output
- ✅ ALWAYS fix the implementation to match the test
- ✅ Tests define the contract - implementation must conform
```

#### `.claude/policies/repo_rules.md`
```markdown
# Repository Rules

## Code Style
- Swift 5.9+ syntax
- SwiftUI for all views
- SwiftData for persistence
- No force unwraps in production code (ok in tests)
- Prefer async/await over completion handlers

## File Organization
- One type per file (exceptions: small related types)
- Tests mirror source structure
- Mocks in dedicated Mocks/ folder

## Naming Conventions
- Types: PascalCase
- Functions/variables: camelCase
- Test methods: test_<scenario>_<expectedResult>

## Dependencies
- Minimize external dependencies
- No SPM packages without explicit approval
- Prefer Apple frameworks (Foundation, SwiftUI, SwiftData)

## Git Practices
- Atomic commits (one logical change per commit)
- Commit message format: `<type>: <description>`
- Types: feat, fix, test, chore, refactor, docs
```

#### `.claude/policies/safety_contract.md`
```markdown
# Mental Health App Safety Contract

This is a MENTAL HEALTH application. Safety is NON-NEGOTIABLE.

## Absolute Rules (Never Break)

### 1. Crisis Detection Override
- Crisis messages MUST bypass LLM entirely
- Use local SafetyClassifier ONLY
- Return pre-written compassionate response
- Include crisis hotline resources
- NEVER send crisis content to OpenAI

### 2. Data Privacy
- Journal full text NEVER leaves device
- Only summaries sent to OpenAI for context
- Private-flagged memories excluded from all egress
- API key stored in Keychain ONLY

### 3. User Safety
- App must work offline (journaling, todos)
- AI failure must NOT block core functionality
- Network failure must NOT delete user data
- Notifications must respect privacy mode

### 4. No Harm
- Never dismiss user feelings
- Never provide medical advice
- Never diagnose conditions
- Always validate emotions
- Always include professional resources

## Testing Requirements
- 100% test coverage for SafetyClassifier
- 100% test coverage for CrisisResponseComposer
- Integration tests verify crisis flow bypasses LLM
- No test may mock away safety components
```

#### `.claude/scripts/run_unit_tests.sh`
```bash
#!/bin/bash
set -e

echo "🧪 Running CalmMind Unit Tests..."

xcodebuild test \
  -scheme CalmMind \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CalmMindTests \
  -resultBundlePath TestResults.xcresult \
  2>&1 | xcpretty

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All unit tests passed"
else
  echo "❌ Unit tests failed"
  exit $EXIT_CODE
fi
```

#### `.claude/scripts/run_ui_smoke.sh`
```bash
#!/bin/bash
set -e

echo "📱 Running CalmMind UI Smoke Tests..."

xcodebuild test \
  -scheme CalmMindUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath UITestResults.xcresult \
  2>&1 | xcpretty

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All UI smoke tests passed"
else
  echo "❌ UI smoke tests failed"
  exit $EXIT_CODE
fi
```

#### `.claude/scripts/check_safety.sh`
```bash
#!/bin/bash
set -e

echo "🔒 Running Safety Checks..."

# Check for hardcoded API keys
if grep -r "sk-" --include="*.swift" CalmMind/; then
  echo "❌ SAFETY VIOLATION: Hardcoded API key found!"
  exit 1
fi

# Check for direct OpenAI calls in SafetyClassifier
if grep -r "OpenAIService" CalmMind/Services/Safety/; then
  echo "❌ SAFETY VIOLATION: Safety module must not call OpenAI!"
  exit 1
fi

# Check for force unwraps in production code (excluding tests)
FORCE_UNWRAPS=$(grep -r "!" --include="*.swift" CalmMind/ | grep -v "CalmMindTests" | grep -v "//" | grep -c "!" || true)
if [ "$FORCE_UNWRAPS" -gt 10 ]; then
  echo "⚠️ WARNING: $FORCE_UNWRAPS potential force unwraps found. Review recommended."
fi

echo "✅ Safety checks passed"
```

#### `.claude/scripts/summarize_failures.sh`
```bash
#!/bin/bash

echo "📊 Summarizing Test Failures..."

if [ -d "TestResults.xcresult" ]; then
  xcrun xcresulttool get --path TestResults.xcresult --format json 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
# Extract and print failure summaries
print('Test failures found. Check TestResults.xcresult for details.')
" 2>/dev/null || echo "Could not parse test results. Check TestResults.xcresult manually."
else
  echo "No test results found. Run tests first."
fi
```

#### README.md section to add:
```markdown
## Claude Code Workflow

This project uses Claude Code agentic hooks for iterative, test-driven development.

### How It Works

1. **Hooks live in `.claude/`** - Claude reads these before/after every action
2. **Scripts run tests** - Same commands as CI, ensuring local ↔ CI parity
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
[Plan] → [Write Test] → [Run Test (Fail)] → [Implement] → [Run Test (Pass)] → [Commit]
   ↑                                                                              ↓
   └──────────────────────── [Next Commit] ←────────────────────────────────────────┘
```

### After Updating CI

If you change `.github/workflows/ci.yml`, update `.claude/scripts/` to match.
Hooks must run the same commands as CI.
```

**Exit Criteria for Commit 0.1.5:**
- All files in `.claude/` created
- Scripts are executable (`chmod +x .claude/scripts/*.sh`)
- README.md includes Claude Code Workflow section
- Claude can run `./claude/scripts/run_unit_tests.sh` successfully

### Commit 0.2: `chore: create Xcode project with test targets`
**Files:**
- `CalmMind.xcodeproj`
- `CalmMind/App/CalmMindApp.swift` (minimal)
- `CalmMindTests/` (test target configured)
- `CalmMindUITests/` (UI test target configured)

### Commit 0.3: `chore: add CI workflow (unit + UI smoke)`
**Files:**
- `.github/workflows/ci.yml`
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.app
      - name: Run Unit Tests
        run: xcodebuild test -scheme CalmMind -destination 'platform=iOS Simulator,name=iPhone 15'
      - name: Run UI Tests
        run: xcodebuild test -scheme CalmMindUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Commit 0.4: `chore: add secret scanning + preflight scripts`
**Files:**
- `scripts/preflight.sh` (checks for hardcoded keys)
- `.github/workflows/secrets-scan.yml`
- `.pre-commit-config.yaml` (optional)

---

## Phase 1: Config + Secrets + Validation

**Exit Criteria:** App runs with "no key" gracefully, no network code yet

### Commit 1.1: `feat: AppConfig (Info.plist keys) + validation`

**Tests (write first):**
```swift
// AppConfigTests.swift
class AppConfigTests: XCTestCase {
    // MARK: - Loading
    func test_loadsDefaultValues()
    func test_usesInfoPlistOverrides()
    func test_validatesTokenLimits_arePositive()
    func test_validatesModelName_notEmpty()

    // MARK: - Defaults
    func test_defaultMaxTokens_is4000()
    func test_defaultModel_isGPT4()
    func test_defaultContextWindow_is10Messages()
    func test_defaultMorningNudgeTime_is8AM()
    func test_defaultEveningNudgeTime_is9PM()
}
```

**Implementation:**
- `Config/AppConfig.swift`
- `Info.plist` keys for: `AI_MODEL`, `MAX_TOKENS`, `CONTEXT_WINDOW`, `MORNING_NUDGE_HOUR`, `EVENING_NUDGE_HOUR`

### Commit 1.2: `feat: SecretsStore (Keychain) + fake for tests`

**Tests (write first):**
```swift
// SecretsStoreTests.swift
class SecretsStoreTests: XCTestCase {
    var sut: SecretsStore!

    // MARK: - Storage
    func test_saveAPIKey_persistsToKeychain()
    func test_getAPIKey_returnsStoredKey()
    func test_deleteAPIKey_removesFromKeychain()
    func test_getAPIKey_returnsNil_whenNotSet()

    // MARK: - Security
    func test_keyNotAccessibleWithoutAuthentication()  // if using kSecAttrAccessible
    func test_keyStoredWithCorrectAccessibility()
}

// MockSecretsStoreTests.swift
class MockSecretsStoreTests: XCTestCase {
    func test_mockStore_worksInMemory()
    func test_mockStore_canSimulateMissingKey()
}
```

**Implementation:**
- `Config/SecretsStore.swift` (protocol + Keychain impl)
- `Mocks/MockSecretsStore.swift`

### Commit 1.3: `feat: UserPreferences typed wrapper`

**Tests (write first):**
```swift
// UserPreferencesTests.swift
class UserPreferencesTests: XCTestCase {
    func test_morningNotificationsEnabled_defaultsTrue()
    func test_eveningNotificationsEnabled_defaultsTrue()
    func test_privacyMode_defaultsFalse()
    func test_canTogglePreferences()
    func test_preferencesPersistAcrossLaunches()

    // MARK: - Notification Privacy Mode
    func test_notificationPrivacyMode_defaultsToDetailed()
    func test_notificationPrivacyMode_canSetToMinimal()
    func test_notificationPrivacyMode_persistsAcrossLaunches()
}
```

**Note:** `notificationPrivacyMode` enum: `.minimal` (generic text only), `.detailed` (can include todo titles, mood references)

**Implementation:**
- `Config/UserPreferences.swift`

### Commit 1.4: `feat: input validation + normalization utilities`

**Tests (write first):**
```swift
// MessageValidatorTests.swift
class MessageValidatorTests: XCTestCase {
    var sut: MessageValidator!

    // MARK: - Empty
    func test_rejectsEmptyMessage()
    func test_rejectsWhitespaceOnlyMessage()

    // MARK: - Length
    func test_acceptsMessageUnderLimit()
    func test_truncatesMessageOverLimit()
    func test_maxLengthIs2000Characters()

    // MARK: - Sanitization
    func test_trimsLeadingTrailingWhitespace()
    func test_normalizesNewlines()
}

// TodoTitleNormalizerTests.swift
class TodoTitleNormalizerTests: XCTestCase {
    var sut: TodoTitleNormalizer!

    func test_shortensLongTitle_to50Chars()
    func test_removesLeadingFillerWords()  // "I need to" -> "Call doctor"
    func test_capitalizesFirstLetter()
    func test_removesTrailingPunctuation()
    func test_extractsDateIfPresent()  // "tomorrow" -> due date
}

// JournalConstraintsTests.swift
class JournalConstraintsTests: XCTestCase {
    func test_maxLengthIs5000Characters()
    func test_entryCantBeEmpty()
}
```

**Implementation:**
- `Validation/MessageValidator.swift`
- `Validation/TodoTitleNormalizer.swift`
- `Validation/JournalConstraints.swift`

---

## Phase 2: Data Models + SwiftData Container

**Exit Criteria:** CRUD works offline, all persistence tests pass

### Commit 2.1: `feat: SwiftData models (all entities)`

**Tests (write first):**
```swift
// ChatMessageTests.swift
class ChatMessageTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() {
        container = try! ModelContainer(for: ChatMessage.self, configurations: .init(isStoredInMemoryOnly: true))
    }

    // MARK: - Creation
    func test_createUserMessage_setsCorrectRole()
    func test_createAssistantMessage_setsCorrectRole()
    func test_createSystemMessage_setsCorrectRole()
    func test_createMessage_generatesUniqueID()
    func test_createMessage_setsCurrentTimestamp()

    // MARK: - Session Association
    func test_message_belongsToCorrectSessionDate()
    func test_contextInjection_defaultsToFalse()
    func test_contextInjection_canBeSetTrue()

    // MARK: - Persistence
    func test_message_persistsToSwiftData()
    func test_message_canBeRetrievedBySession()
    func test_messagesOrderedByTimestamp()
}

// JournalEntryTests.swift
class JournalEntryTests: XCTestCase {
    // MARK: - Creation
    func test_createEntry_withFullText()
    func test_createEntry_setsCreatedDate()
    func test_createEntry_summaryDefaultsToNil()
    func test_createEntry_moodScoreDefaultsToNil()

    // MARK: - Uniqueness
    func test_onlyOneEntryPerCalendarDay()
    func test_canUpdateExistingEntry()

    // MARK: - Summary
    func test_canSetSummaryText()
    func test_fullTextUnchangedWhenSummarySet()

    // MARK: - Mood
    func test_moodScore_acceptsRange1to10()
    func test_moodScore_rejectsOutOfRange()

    // MARK: - Queries
    func test_fetchEntriesByDateRange()
    func test_fetchEntryForSpecificDate()
    func test_fetchEntriesNeedingSummary()
}

// TodoItemTests.swift
class TodoItemTests: XCTestCase {
    // MARK: - Creation
    func test_createTodo_withTitle()
    func test_createTodo_setsCreatedDate()
    func test_createTodo_isNotCompletedByDefault()
    func test_createTodo_sourceDefaultsToUser()

    // MARK: - Completion
    func test_markComplete_setsCompletedDate()
    func test_markIncomplete_clearsCompletedDate()

    // MARK: - Source
    func test_aiExtractedTodos_markedAsAISource()
    func test_userCreatedTodos_markedAsUserSource()

    // MARK: - Queries
    func test_fetchIncompleteTodos()
    func test_fetchTodosByDateRange()
    func test_fetchAIExtractedTodos()
}

// DailySessionTests.swift
class DailySessionTests: XCTestCase {
    // MARK: - Creation
    func test_createSession_forDate()
    func test_createSession_startsWithEmptyMessages()
    func test_sessionDate_usesCalendarDayNotExactTime()

    // MARK: - Uniqueness
    func test_onlyOneSessionPerCalendarDay()
    func test_getOrCreate_returnsExistingForToday()
    func test_getOrCreate_createsNewForNewDay()

    // MARK: - Journal Status
    func test_isJournalGenerated_defaultsFalse()
    func test_canMarkJournalAsGenerated()

    // MARK: - Message Count
    func test_messageCount_returnsCorrectCount()
}

// MemoryItemTests.swift
class MemoryItemTests: XCTestCase {
    // MARK: - Creation
    func test_createMemory_withContent()
    func test_createMemory_setsDateNoted()
    func test_createMemory_embeddingDefaultsToNil()

    // MARK: - Usage Tracking
    func test_timesReferenced_defaultsToZero()
    func test_incrementTimesReferenced()
    func test_lastReferencedDate_updates()

    // MARK: - Private Flag
    func test_isPrivate_defaultsFalse()
    func test_privateMemories_excludedFromEgress()
}
```

**Implementation:**
- `Models/ChatMessage.swift`
- `Models/JournalEntry.swift`
- `Models/TodoItem.swift`
- `Models/DailySession.swift`
- `Models/MemoryItem.swift`

### Commit 2.2: `feat: repositories with transactional saves`

**Tests (write first):**
```swift
// MessageRepositoryTests.swift
class MessageRepositoryTests: XCTestCase {
    var sut: MessageRepository!
    var container: ModelContainer!

    func test_saveMessage_persistsToStore()
    func test_saveMessage_isAtomic()  // Either fully saved or not at all
    func test_fetchMessagesForSession_returnsOrdered()
    func test_deleteMessage_removesFromStore()
    func test_countMessages_forSession()
}

// SessionRepositoryTests.swift
class SessionRepositoryTests: XCTestCase {
    func test_getOrCreateSession_createsIfNotExists()
    func test_getOrCreateSession_returnsExistingIfExists()
    func test_getCurrentSession_usesLocalTimezone()
    func test_markJournalGenerated_updatesSession()
}

// JournalRepositoryTests.swift
class JournalRepositoryTests: XCTestCase {
    func test_createEntry_forDate()
    func test_updateEntry_preservesCreatedDate()
    func test_fetchAllEntries_orderedByDateDesc()
    func test_fetchEntry_forSpecificDate()
    func test_deleteEntry_removesFromStore()
    func test_fetchEntriesNeedingSummary()
}

// TodoRepositoryTests.swift
class TodoRepositoryTests: XCTestCase {
    func test_createTodo_persistsToStore()
    func test_completeTodo_setsCompletedDate()
    func test_deleteTodo_removesFromStore()
    func test_fetchIncompleteTodos_ordered()
    func test_fetchCompletedTodos_ordered()
}

// MemoryRepositoryTests.swift
class MemoryRepositoryTests: XCTestCase {
    func test_createMemory_persistsToStore()
    func test_updateEmbedding_afterCreation()
    func test_searchByEmbedding_returnsSimilar()
    func test_fetchNonPrivateMemories()
    func test_incrementReferenceCount()
}
```

**Implementation:**
- `Repositories/MessageRepository.swift`
- `Repositories/SessionRepository.swift`
- `Repositories/JournalRepository.swift`
- `Repositories/TodoRepository.swift`
- `Repositories/MemoryRepository.swift`

---

## Phase 3: OpenAI Service + Networking Hardening

**Exit Criteria:** Deterministic tests for 429/5xx/timeouts, rate limiting works

### Commit 3.1: `feat: RateLimiter with token bucket`

**Tests (write first):**
```swift
// RateLimiterTests.swift
class RateLimiterTests: XCTestCase {
    var sut: RateLimiter!

    // MARK: - Basic Operation
    func test_allowsRequestUnderLimit()
    func test_blocksRequestOverLimit()
    func test_refillsTokensOverTime()

    // MARK: - Configuration
    func test_respectsMaxRequestsPerMinute()
    func test_respectsCooldownAfter429()

    // MARK: - Concurrency
    func test_threadSafe_concurrentRequests()

    // MARK: - Wait Time
    func test_returnsWaitTime_whenBlocked()
}
```

**Implementation:**
- `Services/Network/RateLimiter.swift`

### Commit 3.2: `feat: RetryPolicy with exponential backoff`

**Tests (write first):**
```swift
// RetryPolicyTests.swift
class RetryPolicyTests: XCTestCase {
    var sut: RetryPolicy!

    // MARK: - Retry Decisions
    func test_shouldRetry_on429()
    func test_shouldRetry_on503()
    func test_shouldRetry_onNetworkTimeout()
    func test_shouldNotRetry_on400()
    func test_shouldNotRetry_on401()
    func test_shouldNotRetry_afterMaxAttempts()

    // MARK: - Backoff
    func test_backoff_increasesExponentially()
    func test_backoff_includesJitter()
    func test_backoff_cappedAtMaxDelay()

    // MARK: - Max Attempts
    func test_maxAttempts_defaultsTo3()
}
```

**Implementation:**
- `Services/Network/RetryPolicy.swift`

### Commit 3.3: `feat: OpenAIServiceProtocol + MockURLSession`

**Tests (write first):**
```swift
// MockURLSessionTests.swift
class MockURLSessionTests: XCTestCase {
    func test_mockSession_returnsConfiguredResponse()
    func test_mockSession_canSimulateError()
    func test_mockSession_canSimulateDelay()
    func test_mockSession_recordsRequests()
}
```

**Implementation:**
- `Services/Network/OpenAIServiceProtocol.swift`
- `Mocks/MockURLSession.swift`

### Commit 3.4: `feat: OpenAIService streaming + strict decoding`

**Tests (write first):**
```swift
// OpenAIServiceTests.swift
class OpenAIServiceTests: XCTestCase {
    var sut: OpenAIService!
    var mockURLSession: MockURLSession!
    var mockSecretsStore: MockSecretsStore!
    var mockRateLimiter: MockRateLimiter!

    // MARK: - Configuration
    func test_requiresAPIKey_throwsIfMissing()
    func test_usesCorrectEndpoint()
    func test_setsAuthorizationHeader()
    func test_setsContentTypeHeader()

    // MARK: - Request Building
    func test_constructsCorrectRequestBody()
    func test_includesAllMessages()
    func test_includesModel()
    func test_includesStream_true()
    func test_includesTools_whenProvided()

    // MARK: - Streaming
    func test_streaming_yieldsPartialResponses()
    func test_streaming_completesOnDone()
    func test_streaming_handlesInterruption()
    func test_streaming_accumulates_fullResponse()

    // MARK: - Error Handling
    func test_handleRateLimitError_429()
    func test_handleInvalidAPIKey_401()
    func test_handleServerError_500()
    func test_handleNetworkTimeout()
    func test_handleMalformedResponse()

    // MARK: - Rate Limiting Integration
    func test_respectsRateLimiter()
    func test_waitsWhenRateLimited()

    // MARK: - Retry Integration
    func test_retriesOnTransientError()
    func test_stopsAfterMaxRetries()

    // MARK: - Idempotency
    func test_preventsDuplicateSend_sameMessageID()
}
```

**Implementation:**
- `Services/Network/OpenAIService.swift`

### Commit 3.5: `feat: MockOpenAIService for dependent tests`

**Implementation:**
```swift
// MockOpenAIService.swift
class MockOpenAIService: OpenAIServiceProtocol {
    var mockResponse: String = "I understand how you feel."
    var mockToolCalls: [ToolCall]? = nil
    var shouldFail: Bool = false
    var failureError: OpenAIError = .networkError
    var lastMessages: [OpenAIMessage]?
    var lastTools: [ToolDefinition]?
    var callCount: Int = 0
    var delaySeconds: Double = 0

    func sendChatCompletion(...) async throws -> ChatCompletionResponse {
        callCount += 1
        lastMessages = messages
        lastTools = tools
        if delaySeconds > 0 { try await Task.sleep(for: .seconds(delaySeconds)) }
        if shouldFail { throw failureError }
        return ChatCompletionResponse(content: mockResponse, toolCalls: mockToolCalls)
    }
}
```

---

## Phase 4: Safety Pipeline

**Exit Criteria:** Crisis messages NEVER call LLM, safe UI output is deterministic

### Commit 4.1: `feat: SafetyClassifier (local rules)`

**Tests (write first):**
```swift
// SafetyClassifierTests.swift
class SafetyClassifierTests: XCTestCase {
    var sut: SafetyClassifier!

    // MARK: - Crisis Detection
    func test_detectsCrisis_suicidalIdeation()
    func test_detectsCrisis_selfHarmMention()
    func test_detectsCrisis_hopelessnessIndicators()
    func test_detectsCrisis_emergencyKeywords()

    // MARK: - Variants (Must Not Miss)
    func test_detectsCrisis_variant_wantToDie()
    func test_detectsCrisis_variant_endItAll()
    func test_detectsCrisis_variant_noPointLiving()
    func test_detectsCrisis_variant_cuttingMyself()

    // MARK: - False Positives (Should NOT Trigger)
    func test_doesNotTrigger_discussingPastCrisis()
    func test_doesNotTrigger_hypothetical()
    func test_doesNotTrigger_movieReference()

    // MARK: - Classification Levels
    func test_classifies_safe()
    func test_classifies_cautionary()
    func test_classifies_crisis()

    // MARK: - Determinism
    func test_sameInput_sameOutput()
    func test_noExternalDependencies()
}
```

**Implementation:**
- `Services/Safety/SafetyClassifier.swift`
- Pattern matching with regex + keyword lists
- Returns: `.safe`, `.cautionary`, `.crisis`

### Commit 4.2: `feat: CrisisResponseComposer + resources`

**Tests (write first):**
```swift
// CrisisResponseComposerTests.swift
class CrisisResponseComposerTests: XCTestCase {
    var sut: CrisisResponseComposer!

    // MARK: - Response Generation
    func test_generatesEmpatheticResponse()
    func test_includesCrisisHotline()
    func test_responseIsLocallyGenerated_noLLM()
    func test_responseVariesByInputContext()

    // MARK: - Resources
    func test_includesNationalSuicideHotline()
    func test_includes988Number()
    func test_includesCrisisTextLine()

    // MARK: - Tone
    func test_neverDismissive()
    func test_neverJudgmental()
    func test_alwaysValidating()
}

// CrisisResourcesTests.swift
class CrisisResourcesTests: XCTestCase {
    func test_resourcesLoadFromBundle()
    func test_resourcesHaveValidPhoneNumbers()
    func test_resourcesHaveDescriptions()
}
```

**Implementation:**
- `Services/Safety/CrisisResponseComposer.swift`
- `Services/Safety/CrisisResources.swift`
- `Resources/CrisisHotlines.json`

### Commit 4.3: `test: crisis flow integration`

**Tests:**
```swift
// CrisisFlowIntegrationTests.swift
class CrisisFlowIntegrationTests: XCTestCase {
    var orchestrator: AIOrchestrator!
    var mockOpenAI: MockOpenAIService!

    func test_crisisMessage_bypassesLLM()
    func test_crisisMessage_returnsSafeResponse()
    func test_crisisMessage_includesResources()
    func test_crisisMessage_stillPersistsToSession()
    func test_openAI_neverCalled_forCrisisInput()
}
```

---

## Phase 5: Context Manager + Data Egress Contract

**Exit Criteria:** Context never exceeds token budget, only summaries leave device

### Commit 5.1: `feat: ContextRedactor (data egress contract)`

**Tests (write first):**
```swift
// ContextRedactorTests.swift
class ContextRedactorTests: XCTestCase {
    var sut: ContextRedactor!

    // MARK: - Allowed Egress
    func test_allowsRecentMessages()
    func test_allowsJournalSummaries_notFullText()
    func test_allowsMemorySummaries_notFullContent()
    func test_allowsTodoTitles_notDetails()

    // MARK: - Blocked Egress
    func test_blocksFullJournalArchive()
    func test_blocksRawMemoryStore()
    func test_blocksPrivateFlaggedItems()

    // MARK: - Enforcement
    func test_promptDoesNotIncludeFullJournalText()
    func test_memoryEgressUsesSummariesOnly()
    func test_privateFlag_excludesFromEgress()

    // MARK: - Output Verification
    func test_outputFitsTokenBudget()
    func test_outputIsStructured()
}
```

**Implementation:**
- `Services/AI/ContextRedactor.swift`

### Commit 5.2: `feat: ContextManager token budgeting`

**Tests (write first):**
```swift
// ContextManagerTests.swift
class ContextManagerTests: XCTestCase {
    var sut: ContextManager!
    var mockRedactor: MockContextRedactor!

    // MARK: - Recent Messages
    func test_keepsMostRecentMessages()
    func test_respectsMessageCountLimit()
    func test_prioritizesRecentOverOld()

    // MARK: - Token Budgeting
    func test_estimatesTokenCount_forMessages()
    func test_staysWithinBudget()
    func test_truncatesIfOverBudget()
    func test_budgetSplitCorrectly()  // system + context + conversation

    // MARK: - Summarization Trigger
    func test_triggersIntraDaySummary_whenLong()
    func test_summaryPreservesKeyPoints()
    func test_summaryReducesTokenCount()

    // MARK: - Context Assembly
    func test_assemblesSystemPrompt()
    func test_includesYesterdaysSummary_ifAvailable()
    func test_includesRelevantMemories()
    func test_includesRecentTodos()
}
```

**Implementation:**
- `Services/AI/ContextManager.swift`

### Commit 5.3: `feat: journal summary generation`

**Tests (write first):**
```swift
// JournalGeneratorTests.swift
class JournalGeneratorTests: XCTestCase {
    var sut: JournalGenerator!
    var mockOpenAI: MockOpenAIService!

    // MARK: - Entry Generation
    func test_generatesEntry_fromConversation()
    func test_generatedEntry_isFirstPerson()
    func test_generatedEntry_coversMainTopics()
    func test_generatedEntry_respectsLengthLimit()

    // MARK: - Mood Extraction
    func test_extractsMoodScore_fromContent()
    func test_moodScore_1to10Scale()

    // MARK: - Summary Generation
    func test_generatesSummary_forOldEntry()
    func test_summary_isConcise_2to3Sentences()
    func test_summary_preservesKeyFacts()

    // MARK: - Edge Cases
    func test_handlesEmptyConversation_noEntry()
    func test_handlesVeryLongConversation()
    func test_handlesSensitiveContent_appropriately()
}
```

**Implementation:**
- `Services/AI/JournalGenerator.swift`

---

## Phase 6: MCP Tool Layer

**Exit Criteria:** Model can safely call todo/journal ops, unknown tools rejected

### Commit 6.1: `feat: ToolRegistry + schemas`

**Tests (write first):**
```swift
// ToolRegistryTests.swift
class ToolRegistryTests: XCTestCase {
    var sut: ToolRegistry!

    // MARK: - Registration
    func test_registersAllTools()
    func test_toolHasName()
    func test_toolHasDescription()
    func test_toolHasParameterSchema()

    // MARK: - Available Tools
    func test_todoAdd_registered()
    func test_todoComplete_registered()
    func test_todoList_registered()
    func test_journalCreateDraft_registered()

    // MARK: - Schema Export
    func test_exportsOpenAIFunctionSchema()
}

// ToolValidatorTests.swift
class ToolValidatorTests: XCTestCase {
    var sut: ToolValidator!

    // MARK: - Validation
    func test_validatesRequiredParams()
    func test_rejectsExtraParams()
    func test_validatesParamTypes()

    // MARK: - Security
    func test_rejectsUnknownTool()
    func test_sanitizesStringParams()
    func test_rejectsMalformedJSON()
}
```

**Implementation:**
- `Services/Tools/ToolRegistry.swift`
- `Services/Tools/ToolValidator.swift`

### Commit 6.2: `feat: TodoTools (add, complete, list)`

**Tests (write first):**
```swift
// TodoToolsTests.swift
class TodoToolsTests: XCTestCase {
    var sut: TodoTools!
    var mockTodoRepo: MockTodoRepository!

    // MARK: - Add Todo
    func test_addTodo_createsItem()
    func test_addTodo_normalizesTitle()
    func test_addTodo_extractsDueDate()
    func test_addTodo_marksAsAISource()
    func test_addTodo_validatesTitle_notEmpty()
    func test_addTodo_validatesTitle_maxLength()

    // MARK: - Complete Todo
    func test_completeTodo_byId()
    func test_completeTodo_byTitle_fuzzyMatch()
    func test_completeTodo_setsCompletedDate()

    // MARK: - List Todos
    func test_listTodos_returnsIncomplete()
    func test_listTodos_canFilterBySource()
}
```

**Implementation:**
- `Services/Tools/TodoTools.swift`

### Commit 6.3: `feat: JournalTools (createDraft, update)`

**Tests (write first):**
```swift
// JournalToolsTests.swift
class JournalToolsTests: XCTestCase {
    var sut: JournalTools!
    var mockJournalRepo: MockJournalRepository!

    // MARK: - Create Draft
    func test_createDraft_fromSessionId()
    func test_createDraft_setsDateFromSession()

    // MARK: - Update
    func test_updateEntry_byId()
    func test_updateEntry_preservesCreatedDate()
}
```

**Implementation:**
- `Services/Tools/JournalTools.swift`

### Commit 6.4: `test: tool call integration`

**Tests:**
```swift
// ToolCallIntegrationTests.swift
class ToolCallIntegrationTests: XCTestCase {
    func test_orchestratorProcessesToolCall()
    func test_toolCallResult_returnedToModel()
    func test_unknownToolCall_rejected()
    func test_invalidArgs_rejected()
    func test_toolEffect_persistedToDatabase()
}
```

---

## Phase 7: AI Orchestrator + Full Send Loop

**Exit Criteria:** Full flow works in integration test without UI

### Commit 7.1: `feat: AIOrchestrator system prompt construction`

**Tests (write first):**
```swift
// AIOrchestratorTests.swift - Part 1
class AIOrchestratorTests: XCTestCase {
    var sut: AIOrchestrator!
    var mockOpenAI: MockOpenAIService!
    var mockContextManager: MockContextManager!
    var mockSafetyClassifier: MockSafetyClassifier!
    var mockToolRegistry: MockToolRegistry!

    // MARK: - System Prompt
    func test_systemPrompt_includesPersona()
    func test_systemPrompt_includesGuidelines()
    func test_systemPrompt_includesDate()
    func test_systemPrompt_includesUserContext()
}
```

**Implementation:**
- `Services/AI/AIOrchestrator.swift` (partial)

### Commit 7.2: `feat: AIOrchestrator message processing`

**Tests (write first):**
```swift
// AIOrchestratorTests.swift - Part 2

    // MARK: - Message Processing
    func test_processUserMessage_validatesInput()
    func test_processUserMessage_checksRateLimit()
    func test_processUserMessage_checksSafety_first()
    func test_processUserMessage_savesUserMessage_beforeAPICall()  // CRITICAL
    func test_processUserMessage_callsOpenAI()
    func test_processUserMessage_savesAssistantResponse()
    func test_processUserMessage_returnsResponse()

    // MARK: - Crisis Override
    func test_crisisInput_skipLLM()
    func test_crisisInput_returnSafeResponse()

    // MARK: - Error Handling
    func test_networkError_doesNotLoseUserMessage()
    func test_networkError_returnsGracefulError()
    func test_canRetry_afterError()
```

**Implementation:**
- `Services/AI/AIOrchestrator.swift` (complete)

### Commit 7.3: `feat: AIOrchestrator tool call handling`

**Tests (write first):**
```swift
// AIOrchestratorTests.swift - Part 3

    // MARK: - Tool Calls
    func test_processesToolCall_fromResponse()
    func test_executesTool_viaRegistry()
    func test_returnsToolResult_toModel()
    func test_handlesMultipleToolCalls()
    func test_invalidToolCall_handledGracefully()
```

### Commit 7.4: `test: send flow integration (atomic operations)`

**Tests:**
```swift
// SendFlowIntegrationTests.swift
class SendFlowIntegrationTests: XCTestCase {
    var orchestrator: AIOrchestrator!
    var container: ModelContainer!
    var mockOpenAI: MockOpenAIService!

    // MARK: - Happy Path
    func test_fullConversation_persistsAndReloads()
    func test_newDay_startsWithYesterdayContext()
    func test_longConversation_managedCorrectly()

    // MARK: - Atomicity (CRITICAL)
    func test_userMessageSaved_beforeNetworkCall()
    func test_networkFailure_doesNotLoseUserMessage()
    func test_crashRecovery_rehydratesSession()

    // MARK: - Idempotency
    func test_duplicateSend_prevented()

    // MARK: - Tool Integration
    func test_todoAdded_whenModelCallsTool()
}
```

---

## Phase 8: ViewModels + UI

**Exit Criteria:** UI smoke tests pass for main flows

### Commit 8.1: `feat: ChatViewModel`

**Tests (write first):**
```swift
// ChatViewModelTests.swift
class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockOrchestrator: MockAIOrchestrator!
    var mockSessionRepo: MockSessionRepository!

    // MARK: - Session Management
    func test_loadsExistingSession_forToday()
    func test_createsNewSession_forNewDay()
    func test_transitionsSession_atMidnight()

    // MARK: - Sending Messages
    func test_sendMessage_validatesInput()
    func test_sendMessage_addsUserMessage()
    func test_sendMessage_callsOrchestrator()
    func test_sendMessage_addsAssistantResponse()
    func test_sendMessage_clearsInputText()
    func test_sendMessage_disabled_whenInputEmpty()

    // MARK: - Loading States
    func test_isLoading_whileWaitingForResponse()
    func test_isLoading_falseAfterResponse()
    func test_disablesInput_whileLoading()

    // MARK: - Error Handling
    func test_showsError_onNetworkFailure()
    func test_allowsRetry_afterError()
    func test_errorCleared_onNewSend()
}
```

**Implementation:**
- `ViewModels/ChatViewModel.swift`
- `Views/Chat/ChatView.swift`
- `Views/Chat/MessageBubble.swift`
- `Views/Chat/ChatInputBar.swift`

### Commit 8.2: `feat: TodoViewModel + UI`

**Tests (write first):**
```swift
// TodoViewModelTests.swift
class TodoViewModelTests: XCTestCase {
    var sut: TodoViewModel!
    var mockTodoRepo: MockTodoRepository!

    func test_loadsIncompleteTodos()
    func test_addTodo_createsItem()
    func test_completeTodo_movesToCompleted()
    func test_deleteTodo_removesFromList()
    func test_aiTodos_distinguishable()
}
```

**Implementation:**
- `ViewModels/TodoViewModel.swift`
- `Views/Todo/TodoListView.swift`
- `Views/Todo/TodoRow.swift`

### Commit 8.3: `feat: JournalViewModel + UI`

**Tests (write first):**
```swift
// JournalViewModelTests.swift
class JournalViewModelTests: XCTestCase {
    var sut: JournalViewModel!
    var mockJournalRepo: MockJournalRepository!
    var mockJournalGenerator: MockJournalGenerator!

    // MARK: - Loading
    func test_loadsAllEntries()
    func test_entriesOrderedByDateDescending()
    func test_groupsEntriesByMonth()

    // MARK: - Generation
    func test_triggersGeneration_onDayEnd()
    func test_skipsGeneration_ifAlreadyExists()
    func test_skipsGeneration_ifNoConversation()

    // MARK: - Editing
    func test_canEditEntry()
    func test_editUpdatesDatabase()

    // MARK: - Deletion
    func test_canDeleteEntry()
}
```

**Implementation:**
- `ViewModels/JournalViewModel.swift`
- `Views/Journal/JournalListView.swift`
- `Views/Journal/JournalDetailView.swift`

### Commit 8.4: `feat: Settings + Onboarding`

**Implementation:**
- `Views/Settings/SettingsView.swift`
- `Views/Onboarding/OnboardingView.swift`
- `Views/Onboarding/APIKeySetupView.swift`

### Commit 8.5: `test: UI smoke tests`

**Tests:**
```swift
// ChatUITests.swift
class ChatUITests: XCTestCase {
    func test_messageAppearsAfterSend()
    func test_typingIndicatorShows()
    func test_scrollsToNewMessage()
    func test_inputDisabledDuringLoading()
    func test_errorDisplaysOnFailure()
}

// TodoUITests.swift
class TodoUITests: XCTestCase {
    func test_todoListDisplaysItems()
    func test_canAddTodo()
    func test_canCompleteTodo()
    func test_canDeleteTodo()
}

// JournalUITests.swift
class JournalUITests: XCTestCase {
    func test_journalListDisplaysEntries()
    func test_canNavigateToDetail()
    func test_emptyStateDisplayed()
}

// OnboardingUITests.swift
class OnboardingUITests: XCTestCase {
    func test_onboardingShows_whenNoAPIKey()
    func test_canEnterAPIKey()
    func test_proceedsAfterValidKey()
}
```

---

## Phase 9: Notifications + Widget

**Exit Criteria:** Morning/evening nudges work, widget updates on todo change

### Commit 9.1: `feat: CheckInStateMachine`

**Tests (write first):**
```swift
// CheckInStateMachineTests.swift
class CheckInStateMachineTests: XCTestCase {
    var sut: CheckInStateMachine!

    // MARK: - Basic State
    func test_initialState_notCheckedIn()
    func test_morningCheckIn_recorded()
    func test_eveningCheckIn_recorded()
    func test_resetsAtMidnight()
    func test_checkedIn_recentlyUsedApp()

    // MARK: - Stable Identifiers (CRITICAL)
    func test_morningNotificationId_format_nudge_morning_YYYYMMDD()
    func test_eveningNotificationId_format_nudge_evening_YYYYMMDD()
    func test_checkInId_format_checkin_morning_YYYYMMDD()
    func test_identifiersAreIdempotent_sameDay()

    // MARK: - Grace Windows
    func test_graceWindowMinutes_fromAppConfig()
    func test_checkInWithinGraceWindow_cancelsNudge()
    func test_checkInAfterGraceWindow_doesNotCancelNudge()
    func test_defaultGraceWindow_is30Minutes()
}
```

**Implementation:**
- `Services/Notifications/CheckInStateMachine.swift`
- Notification IDs: `nudge.morning.2025-01-02`, `nudge.evening.2025-01-02`
- Check-in IDs: `checkin.morning.2025-01-02`
- Grace window from `AppConfig.nudgeGraceWindowMinutes` (default 30)

### Commit 9.2: `feat: NotificationScheduler`

**Tests (write first):**
```swift
// NotificationSchedulerTests.swift
class NotificationSchedulerTests: XCTestCase {
    var sut: NotificationScheduler!
    var mockNotificationCenter: MockUNUserNotificationCenter!
    var mockAppConfig: MockAppConfig!
    var mockUserPreferences: MockUserPreferences!

    // MARK: - Basic Scheduling
    func test_schedulesMorningNudge()
    func test_schedulesEveningNudge()
    func test_nudgeCanceled_afterCheckIn()
    func test_respectsUserPreferences()

    // MARK: - Times from Config (CRITICAL)
    func test_morningNudgeTime_fromAppConfig()
    func test_eveningNudgeTime_fromAppConfig()
    func test_usesStableNotificationId_fromStateMachine()

    // MARK: - Anti-Duplicate Guard (CRITICAL)
    func test_doesNotScheduleDuplicateNudges_sameDay()
    func test_tracksLastNudgeMorningAt()
    func test_tracksLastNudgeEveningAt()
    func test_allowsReschedule_nextDay()
    func test_spamPrevention_maxNudgesPerDay_is2()

    // MARK: - Cancellation
    func test_cancelById_usesStableId()
    func test_cancelAllPending_removesAll()
    func test_nudgeCanceled_usesStableIdentifier()
}
```

**Implementation:**
- `Services/Notifications/NotificationScheduler.swift`
- Times from `AppConfig.morningNudgeHour`, `AppConfig.eveningNudgeHour`
- Anti-duplicate tracking via `UserDefaults.lastNudgeMorningAt`, `lastNudgeEveningAt`
- **Stable Notification IDs (format):**
  - `nudge.morning.2025-01-02`
  - `nudge.evening.2025-01-02`
  - `checkin.morning.2025-01-02`
  - `checkin.evening.2025-01-02`
- Grace windows from `AppConfig.nudgeGraceWindowMinutes` (not hardcoded)

### Commit 9.3: `feat: NudgeComposer (personalized, privacy-safe)`

**Tests (write first):**
```swift
// NudgeComposerTests.swift
class NudgeComposerTests: XCTestCase {
    var sut: NudgeComposer!
    var mockUserPreferences: MockUserPreferences!

    // MARK: - Content Generation
    func test_morningNudge_includesGreeting()
    func test_morningNudge_referencesTasks_ifAny()
    func test_eveningNudge_promptsReflection()
    func test_nudgeVaries_notRepetitive()
    func test_gentleNudge_afterNegativeDay()

    // MARK: - Privacy Mode (CRITICAL - Lock Screen Safe)
    func test_privacyMode_minimal_omitsTodoTitles()
    func test_privacyMode_minimal_usesGenericText()
    func test_privacyMode_detailed_canIncludeTodoTitles()
    func test_privacyMode_detailed_canIncludeMoodReference()
    func test_lockScreenSafe_noSensitiveDetailsEver_inTitle()

    // MARK: - Templates from Config
    func test_templatesLoadFromNudgeTemplatesJSON()
    func test_templatePool_hasMinimum5MorningVariants()
    func test_templatePool_hasMinimum5EveningVariants()
    func test_templateSelection_isSeededRandom_notPureRandom()

    // MARK: - Seeded Randomness Contract
    func test_templateSelection_sameDaySameSeed_sameOutput()
    func test_seed_isHashOfDateDeviceSaltVersion()
    func test_deviceSalt_persistedOnce()
}
```

**Implementation:**
- `Services/Notifications/NudgeComposer.swift`
- `Resources/NudgeTemplates.json` (template pool)
- Respects `UserPreferences.notificationPrivacyMode`
- Seed = `hash(dateKey + deviceSalt + templatePoolVersion)`
- `deviceSalt` stored once in UserDefaults on first launch

### Commit 9.4: `feat: WidgetSnapshotStore + Widget`

**Tests (write first):**
```swift
// WidgetSnapshotStoreTests.swift
class WidgetSnapshotStoreTests: XCTestCase {
    var sut: WidgetSnapshotStore!

    // MARK: - Writing
    func test_writesToAppGroup()
    func test_updatesOnTodoChange()
    func test_updatesOnSessionChange()

    // MARK: - Schema Validation (CRITICAL - cross-process readable)
    func test_snapshotJSON_isWellFormed()
    func test_snapshotJSON_hasRequiredFields()
    func test_snapshotJSON_serializesToAppGroupPath()

    // MARK: - Widget Decoding (same-process simulation)
    func test_widgetProvider_canDecodeSnapshot()
    func test_widgetProvider_handlesEmptySnapshot()
    func test_widgetProvider_handlesMalformedSnapshot_gracefully()

    // MARK: - Rich Schema
    func test_snapshotJSON_includesCheckInFlags()
    func test_snapshotJSON_includesIncompleteTodoCount()
    func test_snapshotJSON_includesLastInteractionAt()
    func test_snapshotRespectsPrivacyMode_minimal_omitsTodoTitles()
}

// Note: Cross-process read tests are NOT unit-testable.
// Widget reading is verified via manual QA + UI tests only.
```

**Implementation:**
- `Widget/WidgetSnapshotStore.swift`
- `Widget/CalmMindWidget/`
- App Group configuration
- **Full snapshot schema:**
```json
{
  "version": 1,
  "incompleteTodos": ["Call doctor", "Buy groceries"],  // omitted if privacyMode == minimal
  "incompleteTodoCount": 2,
  "didMorningCheckIn": true,
  "didEveningCheckIn": false,
  "lastInteractionAt": "2025-01-02T14:30:00Z",
  "lastSessionDate": "2025-01-02",
  "privacyMode": "detailed",  // or "minimal"
  "nextNudgeAt": "2025-01-02T21:00:00Z"  // optional, derived
}
```

### Commit 9.5: `test: notification integration`

**Tests:**
```swift
// NotificationIntegrationTests.swift
class NotificationIntegrationTests: XCTestCase {
    func test_morningNudgeScheduled_atCorrectTime()
    func test_nudgeCanceled_whenUserChats()
    func test_widgetUpdates_whenTodoCompleted()
}
```

---

## Phase 10: Security + Polish

**Exit Criteria:** Security audit passes, data export/delete works

### Commit 10.1: `feat: encryption at rest (iOS Data Protection + optional field-level)`

**NOTE:** Core Data/SwiftData does NOT have built-in SQLite encryption. The "NSPersistentStoreDescription encryption" claim is false.

**Tests (write first):**
```swift
// EncryptionTests.swift
class EncryptionTests: XCTestCase {
    // MARK: - iOS Data Protection (automatic)
    func test_databaseFile_hasCompleteProtection()  // NSFileProtectionComplete
    func test_appGroupFiles_haveCompleteProtection()

    // MARK: - SQLite WAL/SHM Files (CRITICAL - often overlooked)
    func test_walFile_hasCompleteProtection()   // store.sqlite-wal
    func test_shmFile_hasCompleteProtection()   // store.sqlite-shm
    func test_allDatabaseFiles_sameProtectionLevel()

    // MARK: - Field-Level Encryption (optional, for extra-sensitive fields)
    func test_journalFullText_canBeEncrypted()
    func test_encryptedField_decryptable_withKey()
    func test_encryptedField_notReadable_withoutKey()
    func test_encryptionKey_storedInKeychain()
    func test_rotateEncryptionKey_reencryptsData()
}
```

**Implementation:**
- `Services/Encryption/DataProtectionValidator.swift` - verifies file protection attributes
- `Services/Encryption/FieldEncryptor.swift` - CryptoKit AES-GCM for sensitive fields (optional)
- Set `NSFileProtectionComplete` on database directory
- **Must protect all SQLite files:** `store.sqlite`, `store.sqlite-wal`, `store.sqlite-shm`
- Encryption key stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

### Commit 10.2: `feat: export/delete all data`

**Tests:**
```swift
// DataManagementTests.swift
class DataManagementTests: XCTestCase {
    var sut: DataDeleter!
    var mockNotificationScheduler: MockNotificationScheduler!
    var mockWidgetSnapshotStore: MockWidgetSnapshotStore!
    var mockSecretsStore: MockSecretsStore!

    // MARK: - Export
    func test_exportAllData_createsValidJSON()
    func test_exportAllData_includesAllEntities()
    func test_exportAllData_excludesAPIKey()

    // MARK: - Delete (CRITICAL - comprehensive cleanup)
    func test_deleteAllData_removesAllSwiftDataEntities()
    func test_deleteAllData_clearsKeychain()  // API key gone
    func test_deleteAllData_clearsUserDefaults()
    func test_deleteAllData_cancelsAllNotifications()
    func test_deleteAllData_clearsWidgetSnapshot()
    func test_deleteAllData_clearsEncryptionKey()
    func test_deleteAllData_clearsBackgroundTaskState()  // BGTasks for summarization/embeddings

    // MARK: - Verification
    func test_deleteAllData_appLaunchesCleanAfter()
    func test_deleteAllData_isIdempotent()
}
```

**Implementation:**
- `Services/DataExporter.swift`
- `Services/DataDeleter.swift`
- `Services/BackgroundTaskCoordinator.swift` - manages BGTaskScheduler registrations
- Delete flow calls:
  - `notificationScheduler.cancelAllPending()`
  - `widgetSnapshotStore.clear()`
  - `secretsStore.deleteAll()`
  - `BackgroundTaskCoordinator.cancelAll()` - cancels pending summarization/embedding tasks

### Commit 10.3: `chore: security audit checklist`

**Files:**
- `SECURITY.md` - threat model, mitigations
- Final pass through all tests

---

## Test Count Summary

| Category | Count |
|----------|-------|
| Config/Secrets/Validation | ~30 |
| Models | ~45 |
| Repositories | ~30 |
| Network (OpenAI, Rate, Retry) | ~40 |
| Safety | ~25 |
| Context/Egress | ~25 |
| Tools (MCP) | ~25 |
| Orchestrator | ~30 |
| ViewModels | ~35 |
| Notifications (Phase 9) | ~40 |
| Widget (Phase 9) | ~12 |
| Encryption (Phase 10) | ~7 |
| Data Management (Phase 10) | ~10 |
| Integration | ~20 |
| UI Tests | ~20 |
| **TOTAL** | **~394 tests** |

---

## Execution Checklist

Each phase must pass before proceeding:

- [ ] **Phase 0:** Repo + CI green
- [ ] **Phase 1:** Config tests green, app handles missing key
- [ ] **Phase 2:** Model tests green, CRUD works
- [ ] **Phase 3:** Network tests green, rate limiting works
- [ ] **Phase 4:** Safety tests green, crisis bypasses LLM
- [ ] **Phase 5:** Context tests green, egress contract enforced
- [ ] **Phase 6:** Tool tests green, unknown tools rejected
- [ ] **Phase 7:** Orchestrator tests green, send flow atomic
- [ ] **Phase 8:** ViewModel tests green, UI smoke tests green
- [ ] **Phase 9:** Notification tests green, widget updates
- [ ] **Phase 10:** Security audit complete, export/delete works
