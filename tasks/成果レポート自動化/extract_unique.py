import json

with open('/tmp/a_column.json', encoding='utf-8') as f:
    data = json.load(f)

values = [row[0] for row in data.get('values', []) if row]
unique = sorted(set(values))

with open('/tmp/unique_names.txt', 'w', encoding='utf-8') as out:
    for v in unique:
        out.write(v + '\n')

print(f"Found {len(unique)} unique names, saved to /tmp/unique_names.txt")
