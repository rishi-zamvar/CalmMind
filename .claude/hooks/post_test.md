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
