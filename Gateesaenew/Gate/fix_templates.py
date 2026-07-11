import os
import re

directory = r"d:\p\Gateesaenew\Gate\templates"
pattern = re.compile(r"\{%\s*include 'partials/messages\.html'\s*%\}[\s\S]*?\{%\s*endfor\s*%\}[\s\S]*?\{%\s*endif\s*%\}", re.IGNORECASE)

# We also need to catch the ones in scripts (if any). Let's see if this pattern works.
replacement = "{% include 'partials/messages.html' %}"

count = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.html'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = pattern.sub(replacement, content)
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Fixed {filepath}")
                count += 1

print(f"Total fixed: {count}")
