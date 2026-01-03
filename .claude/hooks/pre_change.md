# Pre-Change Hook

Before making ANY code change, Claude MUST verify:

## Safety Checklist
- [ ] This change does NOT introduce hardcoded secrets
- [ ] This change does NOT send raw journal text to OpenAI
- [ ] This change does NOT bypass crisis detection
- [ ] This change has corresponding tests written FIRST

## Pre-Edit Requirements
1. **List files to be modified BEFORE editing** - state them explicitly
2. **Verify each file is in current commit scope**
3. **If change touches UI/widget/notifications**: UI tests must run post-change

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
