# Contributing to CalmMind

## Commit Conventions

### Format
```
<type>: <description>
```

### Types
- `feat` - New feature
- `fix` - Bug fix
- `test` - Adding or updating tests
- `chore` - Maintenance tasks
- `refactor` - Code refactoring
- `docs` - Documentation changes

### Examples
```
feat: add SafetyClassifier for crisis detection
fix: prevent duplicate notifications on same day
test: add unit tests for RateLimiter
chore: update CI workflow for Xcode 15
refactor: extract token budgeting into ContextManager
docs: update README with widget instructions
```

## Development Workflow

### TDD - Test-Driven Development

1. **Write failing test first**
2. Verify test fails for the right reason
3. Implement minimum code to pass
4. Refactor if needed
5. Verify all tests pass
6. Commit

### Commit Scope

Each commit should:
- Be atomic (one logical change)
- Have corresponding tests
- Not break existing tests
- Not touch code outside its scope

## Code Style

### Swift
- Swift 5.9+ syntax
- SwiftUI for all views
- SwiftData for persistence
- No force unwraps in production code (ok in tests)
- Prefer `async/await` over completion handlers

### Naming
- Types: `PascalCase`
- Functions/variables: `camelCase`
- Test methods: `test_<scenario>_<expectedResult>`

### File Organization
- One type per file (exceptions: small related types)
- Tests mirror source structure
- Mocks in dedicated `Mocks/` folder

## Safety Contract

This is a mental health application. Safety is **non-negotiable**.

### Absolute Rules

1. **Crisis Detection Override**
   - Crisis messages MUST bypass LLM entirely
   - Use local `SafetyClassifier` ONLY
   - NEVER send crisis content to OpenAI

2. **Data Privacy**
   - Journal full text NEVER leaves device
   - Only summaries sent to OpenAI
   - API key stored in Keychain ONLY

3. **User Safety**
   - App must work offline
   - AI failure must NOT block journaling/todos
   - Notifications respect privacy mode

4. **No Harm**
   - Never dismiss user feelings
   - Never provide medical advice
   - Always include professional resources

## Testing Requirements

- 100% test coverage for `SafetyClassifier`
- 100% test coverage for `CrisisResponseComposer`
- Integration tests verify crisis flow bypasses LLM
- Never weaken tests to make them pass

### Prohibited Actions

- Never delete or comment out failing assertions
- Never weaken test expectations
- Never skip/disable tests
- Never change expected values to match buggy output

**Always fix the implementation to match the test.**

## Dependencies

- Minimize external dependencies
- No SPM packages without explicit approval
- Prefer Apple frameworks (Foundation, SwiftUI, SwiftData)

## Pull Requests

1. Ensure all tests pass locally
2. Run safety check script
3. Follow commit conventions
4. Keep changes focused and atomic
