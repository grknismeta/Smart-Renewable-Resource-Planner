import os
import sys

def print_tree(startpath, extensions=None, ignore_dirs=None):
    if ignore_dirs is None:
        ignore_dirs = {'.git', '.idea', 'venv', '__pycache__', 'build', '.dart_tool'}
    
    for root, dirs, files in os.walk(startpath):
        # Modify dirs in-place to skip ignored directories
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        level = root.replace(startpath, '').count(os.sep)
        indent = ' ' * 4 * (level)
        print(f'{indent}{os.path.basename(root)}/')
        subindent = ' ' * 4 * (level + 1)
        for f in files:
            if extensions and not f.endswith(tuple(extensions)):
                continue
            print(f'{subindent}{f}')

# Redirect stdout to a file with utf-8 encoding
if __name__ == "__main__":
    with open('tree_structure.txt', 'w', encoding='utf-8') as f:
        sys.stdout = f
        print("BACKEND STRUCTURE:")
        print_tree('backend', extensions=['.py'], ignore_dirs={'venv', '__pycache__', '.idea', 'alembic'})
        print("\n" + "="*50 + "\n")
        print("FRONTEND STRUCTURE:")
        print_tree('frontend/lib', extensions=['.dart'])
