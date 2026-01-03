# Pre-Plan Hook

Before planning any changes, Claude MUST:

1. **Read the implementation plan** at `.claude/plans/glittery-crunching-crystal.md`
2. **Identify current phase** - which phase are we in?
3. **Check test status** - run `.claude/scripts/run_unit_tests.sh`
4. **Verify safety contract** - read `.claude/policies/safety_contract.md`

## Early Phase Exception

If `CalmMind.xcodeproj` does NOT exist:
- Skip test execution (no tests to run yet)
- Proceed with scaffolding commits only (Phase 0)
- Tests become mandatory after Commit 0.2 creates the Xcode project

## Planning Rules
- Write tests FIRST (TDD) - never implement without tests
- One commit at a time - follow commit granularity in plan
- Mental health safety is non-negotiable - crisis detection bypasses LLM
- No secrets in code - API keys go in Keychain only
