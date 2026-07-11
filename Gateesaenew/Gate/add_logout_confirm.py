import os
import re

directory = r"d:\p\Gateesaenew\Gate\templates"
pattern = re.compile(r'href="/Logout"(?! onclick)')
replacement = r'href="/Logout" onclick="return confirm(\'Are you sure you want to logout?\');"'

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.html'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'href="/Logout"' in content:
                new_content = pattern.sub(replacement, content)
                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {filepath}")
