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
