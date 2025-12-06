#!/bin/bash
# Test runner script with overall timeout
# Usage: ./tool/run_tests.sh [timeout_seconds] [test_file_pattern]

set -e

# Default timeout: 5 minutes (300 seconds)
TIMEOUT=${1:-300}
TEST_PATTERN=${2:-test/*_test.dart}

echo "Running tests with ${TIMEOUT}s overall timeout..."
echo "Test pattern: $TEST_PATTERN"
echo ""

# Run tests with timeout
timeout ${TIMEOUT}s dart test $TEST_PATTERN || {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "ERROR: Tests exceeded ${TIMEOUT}s timeout!"
    exit 124
  else
    echo ""
    echo "Tests failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
  fi
}

echo ""
echo "All tests completed within timeout!"

