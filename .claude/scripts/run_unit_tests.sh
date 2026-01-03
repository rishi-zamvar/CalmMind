#!/bin/bash
set -e

echo "🧪 Running CalmMind Unit Tests..."

xcodebuild test \
  -scheme CalmMind \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CalmMindTests \
  -resultBundlePath TestResults.xcresult \
  2>&1 | xcpretty

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All unit tests passed"
else
  echo "❌ Unit tests failed"
  exit $EXIT_CODE
fi
