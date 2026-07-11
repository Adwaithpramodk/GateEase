import os

PWA_SNIPPET = """
    <!-- PWA Setup -->
    <link rel="manifest" href="/manifest.json">
    <meta name="theme-color" content="#1e293b">
    <script>
        if ('serviceWorker' in navigator) {
            window.addEventListener('load', () => {
                navigator.serviceWorker.register('/sw.js')
                    .then(reg => console.log('ServiceWorker registered'))
                    .catch(err => console.log('ServiceWorker registration failed: ', err));
            });
        }
    </script>
"""

templates_dir = r"d:\p\Gateesaenew\Gate\templates"

def inject_pwa_to_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'rel="manifest"' in content or 'serviceWorker' in content:
        print(f"Skipping {filepath} (already injected)")
        return
        
    if '</head>' in content:
        new_content = content.replace('</head>', PWA_SNIPPET + '</head>')
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Injected into {filepath}")
    else:
        print(f"No </head> found in {filepath}")

for root, _, files in os.walk(templates_dir):
    for file in files:
        if file.endswith('.html'):
            inject_pwa_to_file(os.path.join(root, file))

print("Done")
