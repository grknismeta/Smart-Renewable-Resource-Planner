import os, re

lib_dir = r"c:\Projelerim\smart_renewable_resource_planner\frontend\lib"
pkg_name = 'frontend'
old_pkg_name = 'smart_renewable_resource_planner'

file_map = {}
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            rel_to_lib = os.path.relpath(os.path.join(root, f), lib_dir).replace('\\', '/')
            file_map[f] = f"package:{pkg_name}/{rel_to_lib}"

import_pattern = re.compile(r"import\s+['\"]([^'\"]+\.dart)['\"]")

changes = 0
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            def replacer(match):
                import_path = match.group(1)
                
                if import_path.startswith('dart:'):
                    return match.group(0)
                
                # If it's a third party package, leave it alone.
                if import_path.startswith('package:') and not import_path.startswith(f"package:{pkg_name}/") and not import_path.startswith(f"package:{old_pkg_name}/"):
                    return match.group(0) 
                
                filename = os.path.basename(import_path)
                if filename in file_map:
                    return f"import '{file_map[filename]}'"
                else:
                    return match.group(0)
            
            new_content = import_pattern.sub(replacer, content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                changes += 1

print(f"Fixed final imports in {changes} files.")
