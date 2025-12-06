#!/usr/bin/env python3
"""
Script to add timeouts to all async tests in Dart test files.
This ensures tests don't hang forever.
"""

import re
import sys
from pathlib import Path

# Default timeout for most tests (5 seconds)
DEFAULT_TIMEOUT = 5
# Longer timeout for network/discovery tests (10 seconds)
NETWORK_TIMEOUT = 10

def add_timeout_to_test(content: str, test_name: str, timeout: int = DEFAULT_TIMEOUT) -> str:
    """Add timeout to a single test if it doesn't already have one."""
    # Pattern to match test('name', () async { ... });
    # We need to find the closing }); and add timeout before it
    pattern = rf"(test\s*\(\s*['\"]({re.escape(test_name)}|.*?)['\"].*?\)\s*async\s*{{.*?}})(\s*;?\s*$)"
    
    # Check if timeout already exists
    if 'timeout:' in content or 'Timeout(' in content:
        return content
    
    # More general pattern: find test(...) async { ... }); and add timeout
    # This is tricky because we need to match balanced braces
    # For now, let's use a simpler approach: find the pattern and replace
    
    # Pattern: test('name', () async { ... });
    # We'll look for the closing }); and add timeout before it
    test_pattern = r"(test\s*\([^)]+\)\s*async\s*\{[^}]*\})\s*;"
    
    def add_timeout(match):
        test_code = match.group(0)
        if 'timeout:' in test_code or 'Timeout(' in test_code:
            return test_code
        # Replace closing }); with }, timeout: Timeout(Duration(seconds: X)));
        return re.sub(r'(\})\s*;', rf'}}, timeout: Timeout(Duration(seconds: {timeout})));', test_code)
    
    return re.sub(test_pattern, add_timeout, content, flags=re.DOTALL)

def process_file(file_path: Path, network_test: bool = False):
    """Process a single test file to add timeouts."""
    timeout = NETWORK_TIMEOUT if network_test else DEFAULT_TIMEOUT
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Check if file already has timeouts
        if 'timeout: Timeout(Duration(seconds:' in content:
            print(f"  {file_path.name}: Already has timeouts, skipping")
            return False
        
        # Find all async tests without timeouts
        async_test_pattern = r"test\s*\([^)]+\)\s*async\s*\{"
        matches = list(re.finditer(async_test_pattern, content))
        
        if not matches:
            return False
        
        # For each async test, add timeout before the closing });
        # We need to be careful with nested braces
        lines = content.split('\n')
        modified = False
        
        # Simple approach: find lines ending with }); after async tests
        # and add timeout parameter
        for i, line in enumerate(lines):
            if re.search(r"test\s*\([^)]+\)\s*async", line):
                # Find the matching closing brace
                # Look ahead for the closing });
                j = i + 1
                brace_count = 1
                while j < len(lines) and brace_count > 0:
                    brace_count += lines[j].count('{') - lines[j].count('}')
                    if brace_count == 0 and '});' in lines[j]:
                        # Add timeout before the closing });
                        if 'timeout:' not in lines[j] and 'Timeout(' not in lines[j]:
                            lines[j] = lines[j].replace('});', f'}}, timeout: Timeout(Duration(seconds: {timeout})));')
                            modified = True
                        break
                    j += 1
        
        if modified:
            new_content = '\n'.join(lines)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"  {file_path.name}: Added timeouts")
            return True
        
        return False
        
    except Exception as e:
        print(f"  Error processing {file_path.name}: {e}")
        return False

def main():
    """Main function to process all test files."""
    test_dir = Path('test')
    if not test_dir.exists():
        print("Error: test directory not found")
        sys.exit(1)
    
    test_files = list(test_dir.glob('*_test.dart'))
    network_test_files = {'discovery_test.dart', 'zonegroupstate_test.dart'}
    
    print(f"Found {len(test_files)} test files")
    print("Adding timeouts to async tests...")
    print()
    
    modified_count = 0
    for test_file in sorted(test_files):
        is_network_test = test_file.name in network_test_files
        if process_file(test_file, network_test=is_network_test):
            modified_count += 1
    
    print()
    print(f"Modified {modified_count} files")
    print("Done! Please review the changes and run tests to verify.")

if __name__ == '__main__':
    main()

