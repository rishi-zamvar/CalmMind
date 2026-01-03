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

## Phase Boundary Requirements

At the END of each phase or any UI-facing change:
1. Run full unit test suite: `.claude/scripts/run_unit_tests.sh`
2. Run UI smoke tests: `.claude/scripts/run_ui_smoke.sh`
3. Both must pass before proceeding to next phase

## UI Test Triggers
Always run UI tests after changes to:
- Any View file (Views/)
- Any ViewModel file (ViewModels/)
- Widget code (Widget/)
- Notification code (Services/Notifications/)
- Onboarding flow (Views/Onboarding/)
