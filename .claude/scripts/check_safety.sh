#!/bin/bash
set -e

echo "🔒 Running Safety Checks..."

# Patterns that should NEVER appear in PRODUCTION source code
# Test files and example configs are excluded
DANGEROUS_PATTERNS=(
  "sk-proj-[a-zA-Z0-9]"      # Real OpenAI API keys (longer format)
  "Authorization: Bearer sk-proj"  # Real auth headers
)

# File types to scan (excluding build artifacts and git)
INCLUDE_PATTERNS="--include=*.swift --include=*.plist --include=*.json --include=*.xcconfig --include=*.md --include=*.yml --include=*.yaml"

# Directories to exclude (tests are allowed to have fake keys)
EXCLUDE_DIRS="--exclude-dir=.git --exclude-dir=.build --exclude-dir=DerivedData --exclude-dir=*.xcresult --exclude-dir=Pods --exclude-dir=CalmMindTests"

VIOLATIONS=0

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  # Exclude test files, example configs, and this script itself
  MATCHES=$(grep -rE "$pattern" $INCLUDE_PATTERNS $EXCLUDE_DIRS . 2>/dev/null | grep -v "check_safety.sh" | grep -v ".example" | grep -v "sk-your-key-here" || true)
  if [ -n "$MATCHES" ]; then
    echo "$MATCHES"
    echo "❌ SAFETY VIOLATION: Pattern '$pattern' found in production code!"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

# Check for direct OpenAI calls in SafetyClassifier (if it exists)
if [ -d "CalmMind/Services/Safety" ]; then
  if grep -r "OpenAIService" CalmMind/Services/Safety/ 2>/dev/null; then
    echo "❌ SAFETY VIOLATION: Safety module must not call OpenAI!"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
fi

# Check for force unwraps in production code (excluding tests)
if [ -d "CalmMind" ]; then
  FORCE_UNWRAPS=$(grep -rE "![^=]" --include="*.swift" CalmMind/ 2>/dev/null | grep -v "CalmMindTests" | grep -v "//" | grep -v "!=" | wc -l || true)
  if [ "$FORCE_UNWRAPS" -gt 10 ]; then
    echo "⚠️ WARNING: $FORCE_UNWRAPS potential force unwraps found. Review recommended."
  fi
fi

if [ $VIOLATIONS -gt 0 ]; then
  echo "❌ Safety checks FAILED with $VIOLATIONS violation(s)"
  exit 1
fi

echo "✅ Safety checks passed"
