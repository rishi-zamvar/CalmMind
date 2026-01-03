#!/bin/bash
# Preflight checks - run before committing
# This script checks for common issues that should never be committed

set -e

echo "🛫 Running preflight checks..."

ERRORS=0

# ============================================
# 1. Check for hardcoded secrets
# ============================================
echo "Checking for hardcoded secrets..."

SECRET_PATTERNS=(
  "sk-[a-zA-Z0-9]{20,}"           # OpenAI API keys
  "OPENAI_API_KEY=['\"]?[^'\"\\s]+" # Hardcoded env vars
  "Bearer [a-zA-Z0-9_-]{20,}"     # Bearer tokens
  'apiKey\s*[:=]\s*"[^"]{10,}"'   # API key assignments
  'api_key\s*[:=]\s*"[^"]{10,}"'  # Snake case API keys
  'secret\s*[:=]\s*"[^"]{10,}"'   # Generic secrets
  'password\s*[:=]\s*"[^"]{6,}"'  # Passwords
)

# Files to scan
INCLUDE="--include=*.swift --include=*.plist --include=*.json --include=*.xcconfig --include=*.yml --include=*.yaml --include=*.md"
EXCLUDE="--exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=.build --exclude-dir=Pods --exclude-dir=*.xcresult"

for pattern in "${SECRET_PATTERNS[@]}"; do
  MATCHES=$(grep -rE "$pattern" $INCLUDE $EXCLUDE . 2>/dev/null | grep -v "preflight.sh" | grep -v "check_safety.sh" || true)
  if [ -n "$MATCHES" ]; then
    echo "❌ Potential secret found matching pattern: $pattern"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
  fi
done

# ============================================
# 2. Check for common file issues
# ============================================
echo "Checking for problematic files..."

# Check for .env files (should never be committed in iOS projects)
if find . -name ".env*" -not -path "./.git/*" 2>/dev/null | grep -q .; then
  echo "❌ .env file found - these should not be committed"
  find . -name ".env*" -not -path "./.git/*"
  ERRORS=$((ERRORS + 1))
fi

# Check for private key files
if find . \( -name "*.pem" -o -name "*.p12" -o -name "*.key" \) -not -path "./.git/*" 2>/dev/null | grep -q .; then
  echo "❌ Private key file found - these should not be committed"
  find . \( -name "*.pem" -o -name "*.p12" -o -name "*.key" \) -not -path "./.git/*"
  ERRORS=$((ERRORS + 1))
fi

# ============================================
# 3. Check for debug code
# ============================================
echo "Checking for debug code..."

DEBUG_PATTERNS=(
  "print.*DEBUG"
  "// TODO: remove"
  "// FIXME: temp"
  "debugPrint"
)

for pattern in "${DEBUG_PATTERNS[@]}"; do
  MATCHES=$(grep -rn "$pattern" --include="*.swift" . 2>/dev/null | grep -v "Test" || true)
  if [ -n "$MATCHES" ]; then
    echo "⚠️ Potential debug code found: $pattern"
    echo "$MATCHES"
    # Don't fail on debug code, just warn
  fi
done

# ============================================
# 4. Verify no large files staged
# ============================================
echo "Checking for large files..."

# Check staged files over 1MB
LARGE_FILES=$(git diff --cached --name-only 2>/dev/null | while read file; do
  if [ -f "$file" ]; then
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$SIZE" -gt 1048576 ]; then
      echo "$file ($((SIZE / 1024))KB)"
    fi
  fi
done)

if [ -n "$LARGE_FILES" ]; then
  echo "⚠️ Large files staged (>1MB):"
  echo "$LARGE_FILES"
  # Warning only, not an error
fi

# ============================================
# Summary
# ============================================
if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "❌ Preflight checks FAILED with $ERRORS error(s)"
  echo "Fix the issues above before committing."
  exit 1
fi

echo "✅ Preflight checks passed"
