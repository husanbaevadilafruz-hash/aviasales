import os

def fix_encoding(filename):
    print(f"Fixing {filename}...")
    # Try different encodings to read the file
    encodings = ['utf-8-sig', 'utf-8', 'utf-16', 'cp1251']
    content = None
    for enc in encodings:
        try:
            with open(filename, 'r', encoding=enc) as f:
                content = f.read()
            print(f"Successfully read with {enc}")
            break
        except Exception:
            continue
    
    if content:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Successfully written as UTF-8 (no BOM)")
    else:
        print(f"Failed to read {filename} with any common encoding")

fix_encoding('main.py')
fix_encoding('schemas.py')
fix_encoding('models.py')
