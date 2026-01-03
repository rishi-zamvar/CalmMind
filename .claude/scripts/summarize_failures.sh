#!/bin/bash

echo "📊 Summarizing Test Failures..."

if [ -d "TestResults.xcresult" ]; then
  xcrun xcresulttool get --path TestResults.xcresult --format json 2>/dev/null | \
    python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('Test failures found. Check TestResults.xcresult for details.')
except:
    print('Could not parse test results.')
" 2>/dev/null || echo "Could not parse test results. Check TestResults.xcresult manually."
else
  echo "No test results found. Run tests first."
fi
