#!/usr/bin/env python3
import os

HEADER = [
    "## Copyright © 2022-2026, Oracle and/or its affiliates.",
    "## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl"
]
HEADER_BLOCK = '\n'.join(HEADER) + '\n\n'

def has_exact_header(lines):
    return lines[:2] == HEADER

def starts_with_oracle(lines):
    if not lines: return False
    line0 = lines[0].strip().removeprefix('#').strip().lower()
    return (line0.startswith('copyright') and 'oracle and/or its affiliates' in line0)

def fix_file(fn):
    with open(fn, 'r') as f:
        lines = f.readlines()
    orig = lines[:]

    # If already has good header, do nothing.
    if has_exact_header([l.rstrip('\n') for l in lines[:2]]):
        return

    # Remove old Oracle copyright at top (if any; handle up to 3 lines)
    n = 0
    while n < min(3, len(lines)):
        line = lines[n].strip().removeprefix('#').strip().lower()
        if line.startswith('copyright') and 'oracle and/or its affiliates' in line:
            n += 1
        elif 'all rights reserved.' in line and 'oracle.com' in line:
            n += 1
        else:
            break
    # Remove up to 2 blank lines after an old header too
    while n < len(lines) and lines[n].strip() == '':
        n += 1

    # Write updated content with header.
    new_content = HEADER_BLOCK + ''.join(lines[n:])
    with open(fn + '.bak', 'w') as bak:
        bak.writelines(orig)
    with open(fn, 'w') as f:
        f.write(new_content)
    print(f"Header inserted/replaced: {fn}")

def walk():
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file.endswith('.tf'):
                fix_file(os.path.join(root, file))

if __name__ == '__main__':
    walk()
    print("All .tf files checked and headers inserted/replaced as needed. Backups saved with .bak extension.")
