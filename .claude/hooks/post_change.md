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
