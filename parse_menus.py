import os
import re
from pathlib import Path

def find_files(d):
    for root, _, files in os.walk(d):
        for file in files:
            if file.endswith('.swift'):
                yield os.path.join(root, file)

for f in find_files('Echo/Sources'):
    content = Path(f).read_text()
    
    lines = content.split('\n')
    
    # We want to find contexts like `.contextMenu { ... }`, `CommandGroup(...) { ... }`, `CommandMenu(...) { ... }`, `Menu(...) { ... }`
    # and extract buttons/labels inside them.
    # A simpler approach: just print every line containing 'Button(' or 'Label(' or 'NSMenuItem' in files that have menus.
    # But wait, we only want to evaluate menu items.
    
    for i, line in enumerate(lines):
        if re.search(r'\b(Button|Label|NSMenuItem)\b', line):
            if 'systemImage:' in line or '...' in line or '…' in line:
                print(f"{f}:{i+1}: {line.strip()}")

