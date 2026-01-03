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
