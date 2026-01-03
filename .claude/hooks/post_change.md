# Post-Change Hook

After EVERY code change, Claude MUST:

1. **Run unit tests**: `.claude/scripts/run_unit_tests.sh`
2. **Check for safety violations**: `.claude/scripts/check_safety.sh`
3. **Review changes**: Ensure only intended files were modified

## On Test Failure
- Do NOT proceed to next task
- **Re-run failing tests ONLY first** (saves time, prevents thrash):
  ```bash
  xcodebuild test -scheme CalmMind -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CalmMindTests/TestClass/testMethod
  ```
  Use the **exact failing test identifier** as printed by xcodebuild output (e.g., `CalmMindTests/SafetyClassifierTests/test_detectsCrisis_suicidalIdeation`)
- Once failing tests pass, run FULL unit test suite
- Read `.claude/hooks/on_failure.md` for recovery protocol
- Fix the failing test before continuing

## On Test Pass
- Mark task as complete
- Proceed to next commit in phase
- Update progress in plan if needed

## UI Test Requirements
If the change touched any of these areas, ALSO run UI tests:
- Views/
- ViewModels/
- Widget/
- Notifications/

Run: `.claude/scripts/run_ui_smoke.sh`
