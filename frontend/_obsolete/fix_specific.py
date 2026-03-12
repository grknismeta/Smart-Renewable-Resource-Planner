import codecs, re, os

lib_dir = r"c:\Projelerim\smart_renewable_resource_planner\frontend\lib"
pkg_name = 'frontend'

file_map = {}
for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            rel_to_lib = os.path.relpath(os.path.join(root, f), lib_dir).replace('\\', '/')
            file_map[f] = f"package:{pkg_name}/{rel_to_lib}"

with codecs.open('analyze_res2_utf8.txt', 'r', encoding='utf-8') as f:
    text = f.read()

changes = 0
for line in text.split('\n'):
    m = re.search(r"Target of URI doesn't exist: '([^']+)' - ([^:]+):(\d+)", line)
    if m:
        bad_uri = m.group(1)
        filepath = m.group(2).strip()
        filename = os.path.basename(bad_uri)
        
        if filename in file_map:
            abs_path = os.path.join(r"c:\Projelerim\smart_renewable_resource_planner\frontend", filepath)
            if os.path.exists(abs_path):
                with codecs.open(abs_path, 'r', encoding='utf-8') as f2:
                    content = f2.read()
                new_content = content.replace(bad_uri, file_map[filename])
                if new_content != content:
                    with codecs.open(abs_path, 'w', encoding='utf-8') as f2:
                        f2.write(new_content)
                    changes += 1

print(f"Fixed {changes} missing URIs from analyze list.")
