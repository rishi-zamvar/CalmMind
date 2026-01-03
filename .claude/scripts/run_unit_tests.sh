#!/bin/bash
set -e

echo "🧪 Running CalmMind Unit Tests..."

# Check if Xcode project exists (early phases won't have it)
if [ ! -d "CalmMind.xcodeproj" ]; then
  echo "⏭️ Skipping tests: CalmMind.xcodeproj not found (early scaffolding phase)"
  exit 0
fi

# Allow CI to override destination
DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

# Remove old result bundle if exists
rm -rf TestResults.xcresult

# Run tests with optional xcpretty
CMD=(xcodebuild test -scheme CalmMind -destination "$DESTINATION" -only-testing:CalmMindTests -resultBundlePath TestResults.xcresult)

if command -v xcpretty >/dev/null 2>&1; then
  "${CMD[@]}" 2>&1 | xcpretty
  EXIT_CODE=${PIPESTATUS[0]}
else
  "${CMD[@]}"
  EXIT_CODE=$?
fi

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All unit tests passed"
else
  echo "❌ Unit tests failed"
  exit $EXIT_CODE
fi
