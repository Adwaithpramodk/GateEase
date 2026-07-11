import os
import re

directory = r"d:\p\Gateesaenew\Gate\templates"
pattern = re.compile(r'\{%\s*if messages\s*%\}[\s\S]*?\{%\s*endif\s*%\}', re.IGNORECASE)

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.html') and file != 'messages.html':
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if '{% if messages %}' in content:
                new_content = pattern.sub("{% include 'partials/messages.html' %}", content)
                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {filepath}")
