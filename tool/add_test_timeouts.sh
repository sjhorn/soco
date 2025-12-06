#!/bin/bash
# Script to add timeouts to all async tests in test files
# This ensures tests don't hang forever

# Find all test files with async tests
for test_file in test/*_test.dart; do
  if grep -q "test.*async" "$test_file"; then
    echo "Processing $test_file..."
    # This is a helper script - actual edits should be done manually or with a more sophisticated tool
  fi
done

echo "Done. Please review and add timeouts manually or use a proper refactoring tool."

