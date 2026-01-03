#!/bin/bash
set -e

echo "📱 Running CalmMind UI Smoke Tests..."

xcodebuild test \
  -scheme CalmMindUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath UITestResults.xcresult \
  2>&1 | xcpretty

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All UI smoke tests passed"
else
  echo "❌ UI smoke tests failed"
  exit $EXIT_CODE
fi
