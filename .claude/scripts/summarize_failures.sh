#!/bin/bash

echo "📊 Summarizing Test Failures..."

# Accept path argument, default to TestResults.xcresult
RESULT_PATH="${1:-TestResults.xcresult}"

# Also check UI test results if no argument provided
if [ "$1" = "" ] && [ -d "UITestResults.xcresult" ]; then
  echo "Found UITestResults.xcresult, will check both bundles."
fi

summarize_bundle() {
  local bundle="$1"
  if [ -d "$bundle" ]; then
    echo ""
    echo "=== $bundle ==="
    xcrun xcresulttool get --path "$bundle" --format json 2>/dev/null | \
      python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Try to extract actionable failure info
    if 'issues' in data:
        issues = data.get('issues', {})
        test_failures = issues.get('testFailureSummaries', {}).get('_values', [])
        if test_failures:
            print(f'Found {len(test_failures)} test failure(s):')
            for failure in test_failures[:5]:  # Limit to first 5
                name = failure.get('testCaseName', {}).get('_value', 'Unknown')
                msg = failure.get('message', {}).get('_value', 'No message')
                print(f'  - {name}: {msg[:100]}')
        else:
            print('No test failures found in issues.')
    else:
        print('Test results found. Check $bundle for details.')
except Exception as e:
    print(f'Could not parse: {e}')
" 2>/dev/null || echo "Could not parse $bundle. Inspect manually with: xcrun xcresulttool get --path $bundle"
  else
    echo "Bundle not found: $bundle"
  fi
}

# Summarize requested bundle
summarize_bundle "$RESULT_PATH"

# Also summarize UI tests if checking default and both exist
if [ "$1" = "" ] && [ -d "UITestResults.xcresult" ]; then
  summarize_bundle "UITestResults.xcresult"
fi

echo ""
echo "For full details, open .xcresult bundles in Xcode."
