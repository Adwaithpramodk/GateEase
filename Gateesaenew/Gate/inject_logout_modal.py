import os
import re

directory = r"d:\p\Gateesaenew\Gate\templates"

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.html'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Replace the old return confirm(...) with the new modal function
            # We must be careful because previously we replaced it with return confirm('...')
            content = re.sub(
                r'onclick="return confirm\(\'Are you sure you want to logout\?\'\);"',
                'onclick="showLogoutModal(event);"',
                content
            )
            content = re.sub(
                r'onclick=\'return confirm\("Are you sure you want to logout\?"\);\'',
                'onclick="showLogoutModal(event);"',
                content
            )
            
            # Inject the modal before </body> if it's not already there and if the page has the new onclick
            if 'showLogoutModal(event)' in content and "{% include 'partials/logout_modal.html' %}" not in content:
                content = re.sub(
                    r'(</body>)',
                    r"{% include 'partials/logout_modal.html' %}\n\1",
                    content,
                    flags=re.IGNORECASE
                )
            
            if content != original_content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {file}")

print("Done.")
