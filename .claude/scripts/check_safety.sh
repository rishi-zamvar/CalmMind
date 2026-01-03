#!/bin/bash
set -e

echo "🔒 Running Safety Checks..."

# Check for hardcoded API keys
if grep -r "sk-" --include="*.swift" CalmMind/ 2>/dev/null; then
  echo "❌ SAFETY VIOLATION: Hardcoded API key found!"
  exit 1
fi

# Check for direct OpenAI calls in SafetyClassifier
if grep -r "OpenAIService" CalmMind/Services/Safety/ 2>/dev/null; then
  echo "❌ SAFETY VIOLATION: Safety module must not call OpenAI!"
  exit 1
fi

# Check for force unwraps in production code (excluding tests)
FORCE_UNWRAPS=$(grep -r "!" --include="*.swift" CalmMind/ 2>/dev/null | grep -v "CalmMindTests" | grep -v "//" | grep -c "!" || true)
if [ "$FORCE_UNWRAPS" -gt 10 ]; then
  echo "⚠️ WARNING: $FORCE_UNWRAPS potential force unwraps found. Review recommended."
fi

echo "✅ Safety checks passed"
