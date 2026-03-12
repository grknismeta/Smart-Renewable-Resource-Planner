import re
from collections import defaultdict

with open('analyze_results.txt', 'r', encoding='utf-16') as f:
    lines = f.readlines()

errors = defaultdict(int)
files = set()

for line in lines:
    if ' - ' in line and '.dart:' in line:
        parts = line.strip().split(' - ')
        if len(parts) >= 2:
            file_part = parts[0].strip()
            msg_part = parts[1].strip()
            if '.dart:' in file_part:
                filename = file_part.split('.dart:')[0] + '.dart'
                files.add(filename)
            
            # Extract common errors
            m = re.search(r"Undefined name '([^']+)'", msg_part)
            if m: errors['Undefined name ' + m.group(1)] += 1
            
            m = re.search(r"Undefined class '([^']+)'", msg_part)
            if m: errors['Undefined class ' + m.group(1)] += 1
            
            m = re.search(r"The method '([^']+)' isn't defined", msg_part)
            if m: errors['Undefined method ' + m.group(1)] += 1
            
            m = re.search(r"Target of URI doesn't exist: '([^']+)'", msg_part)
            if m: errors['Missing URI ' + m.group(1)] += 1

print(f'Affected files: {len(files)}')
print('Top errors:')
for k, v in sorted(errors.items(), key=lambda x: x[1], reverse=True)[:30]:
    print(f'  {k}: {v}')
