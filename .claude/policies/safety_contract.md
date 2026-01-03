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
