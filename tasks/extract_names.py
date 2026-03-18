import json

with open(r'C:\Users\user\.claude\projects\C--Users-user-projects-work-repo\28ba693f-e66b-4d4f-b8dd-e2c15941141e\tool-results\b8g2rl1zm.txt', 'r', encoding='utf-8') as f:
    data = json.load(f)
names = set()
for row in data['values'][1:]:
    if row:
        names.add(row[0])
for n in sorted(names):
    print(n)
