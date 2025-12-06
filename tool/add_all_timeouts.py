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

def add_timeout_to_file(file_path: Path, timeout: int = DEFAULT_TIMEOUT):
    """Add timeout to all async tests in a file that don't already have one."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern to match: test('...', () async { ... });
        # We need to find async tests and add timeout before the closing });
        
        # Find all async test declarations
        async_test_pattern = r"test\s*\([^)]+\)\s*async\s*\{"
        
        # For each async test, we need to find its closing });
        # This is tricky because of nested braces, so we'll use a simpler approach:
        # Find lines that end with }); after an async test and add timeout
        
        lines = content.split('\n')
        modified_lines = []
        i = 0
        modified = False
        
        while i < len(lines):
            line = lines[i]
            modified_lines.append(line)
            
            # Check if this line starts an async test
            if re.search(r"test\s*\([^)]+\)\s*async\s*\{", line):
                # Look ahead to find the matching closing });
                brace_count = line.count('{') - line.count('}')
                j = i + 1
                
                # Track the lines we're scanning
                test_lines = [line]
                
                while j < len(lines) and brace_count > 0:
                    test_lines.append(lines[j])
                    brace_count += lines[j].count('{') - lines[j].count('}')
                    j += 1
                
                # If we found the closing, check if it needs timeout
                if j < len(lines) and '});' in lines[j-1]:
                    closing_line = lines[j-1]
                    if 'timeout:' not in closing_line and 'Timeout(' not in closing_line:
                        # Add timeout before the closing });
                        modified_lines[-1] = closing_line.replace(
                            '});',
                            f'}}, timeout: Timeout(Duration(seconds: {timeout})));'
                        )
                        modified = True
                        # Skip the original closing line since we've replaced it
                        i = j
                        continue
            
            i += 1
        
        if modified:
            new_content = '\n'.join(modified_lines)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            return True
        
        return False
        
    except Exception as e:
        print(f"  Error processing {file_path.name}: {e}")
        return False

def process_file_simple(file_path: Path, timeout: int = DEFAULT_TIMEOUT):
    """Simpler approach: find }); after async tests and add timeout."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already has timeouts
        if 'timeout: Timeout(Duration(seconds:' in content:
            return False
        
        # Find all async test patterns and their positions
        async_pattern = r"test\s*\([^)]+\)\s*async\s*\{"
        matches = list(re.finditer(async_pattern, content))
        
        if not matches:
            return False
        
        # For each match, find the next }); that closes it
        # We'll work backwards from the end to avoid position shifts
        lines = content.split('\n')
        modified = False
        
        # Simple heuristic: if a line has }); and the previous lines contain async test,
        # add timeout if not present
        for i in range(len(lines) - 1, -1, -1):
            if '});' in lines[i] and 'timeout:' not in lines[i] and 'Timeout(' not in lines[i]:
                # Check if there's an async test above this line
                for j in range(max(0, i - 50), i):
                    if re.search(r"test\s*\([^)]+\)\s*async", lines[j]):
                        # Found async test, add timeout
                        lines[i] = lines[i].replace(
                            '});',
                            f'}}, timeout: Timeout(Duration(seconds: {timeout})));'
                        )
                        modified = True
                        break
        
        if modified:
            new_content = '\n'.join(lines)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
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
    
    # Files already processed
    processed_files = {'core_test.dart', 'alarms_test.dart', 'discovery_test.dart'}
    
    print(f"Found {len(test_files)} test files")
    print("Adding timeouts to async tests...")
    print()
    
    modified_count = 0
    for test_file in sorted(test_files):
        if test_file.name in processed_files:
            print(f"  {test_file.name}: Already processed, skipping")
            continue
            
        is_network_test = test_file.name in network_test_files
        timeout = NETWORK_TIMEOUT if is_network_test else DEFAULT_TIMEOUT
        
        if process_file_simple(test_file, timeout=timeout):
            print(f"  {test_file.name}: Added timeouts")
            modified_count += 1
        else:
            print(f"  {test_file.name}: No changes needed or already has timeouts")
    
    print()
    print(f"Modified {modified_count} files")
    print("Done! Please review the changes and run tests to verify.")

if __name__ == '__main__':
    main()

