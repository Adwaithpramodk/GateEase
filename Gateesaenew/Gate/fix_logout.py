import os
import re

directory = r"d:\p\Gateesaenew\Gate\templates"

count = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.html'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Fix escaping issue from previous injection
            new_content = content.replace(r"return confirm(\'Are you sure you want to logout?\');", "return confirm('Are you sure you want to logout?');")
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                count += 1

print(f"Fixed {count} files")
