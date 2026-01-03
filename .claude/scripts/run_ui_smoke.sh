#!/bin/bash
set -e

echo "📱 Running CalmMind UI Smoke Tests..."

# Check if Xcode project exists (early phases won't have it)
if [ ! -d "CalmMind.xcodeproj" ]; then
  echo "⏭️ Skipping UI tests: CalmMind.xcodeproj not found (early scaffolding phase)"
  exit 0
fi

# Allow CI to override destination
DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

# Remove old result bundle if exists
rm -rf UITestResults.xcresult

# Use app scheme with -only-testing for UI tests (not a separate scheme)
CMD=(xcodebuild test -scheme CalmMind -destination "$DESTINATION" -only-testing:CalmMindUITests -resultBundlePath UITestResults.xcresult)

if command -v xcpretty >/dev/null 2>&1; then
  "${CMD[@]}" 2>&1 | xcpretty
  EXIT_CODE=${PIPESTATUS[0]}
else
  "${CMD[@]}"
  EXIT_CODE=$?
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All UI smoke tests passed"
else
  echo "❌ UI smoke tests failed"
  exit $EXIT_CODE
fi
