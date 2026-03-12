import os
import ast
import sys

def get_imports(path):
    imports = set()
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in ('venv', '.venv', '__pycache__', 'alembic')]
        for file in files:
            if file.endswith('.py'):
                try:
                    with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                        tree = ast.parse(f.read(), filename=file)
                        for node in ast.walk(tree):
                            if isinstance(node, ast.Import):
                                for n in node.names:
                                    imports.add(n.name.split('.')[0])
                            elif isinstance(node, ast.ImportFrom):
                                if node.module:
                                    imports.add(node.module.split('.')[0])
                except Exception as e:
                    pass
    return imports

if __name__ == '__main__':
    backend_path = os.path.join(sys.argv[1], 'backend')
    imports = get_imports(backend_path)
    
    # Filter out standard library modules
    stdlib = {'os', 'sys', 'ast', 'datetime', 'json', 'time', 'math', 'typing', 
              'collections', 'itertools', 'functools', 're', 'logging', 'pathlib',
              'shutil', 'subprocess', 'random', 'concurrent', 'asyncio', 'io', 'csv',
              'warnings', 'unittest', 'traceback', 'sqlite3', 'urllib', 'base64', 'uuid',
              'html', 'copy', 'enum', '__future__'}
    
    third_party = sorted([i for i in imports if i not in stdlib and i != 'app' and i != 'crud' and i != 'db' and i != 'schemas' and i != 'services' and i != 'config' and i != 'depends' and i != 'middlewares' and i != 'models' and i != 'routers' and i != 'utils' and i != 'core'])
    print('\n'.join(third_party))
