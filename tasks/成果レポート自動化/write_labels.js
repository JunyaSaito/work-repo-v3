const fs = require('fs');
const data = JSON.parse(fs.readFileSync('tasks/成果レポート自動化/a_column.json', 'utf-8'));
const values = data.values.map(r => r[0] || '');

const rules = [
  { pattern: /【全店メルマガ/, label: '全体メルマガ' },
  { pattern: /全店メルマガ配信用/, label: '全体メルマガ' },
  { pattern: /【個店メルマガ】/, label: '個店メルマガ' },
  { pattern: /【かご落ち】/, label: 'かご落ち' },
  { pattern: /閲覧リタゲ/, label: '閲覧落ち' },
  { pattern: /お気に入り/, label: 'お気に入りリタゲ' },
  { pattern: /【F2転換】/, label: 'F2転換' },
  { pattern: /【バースデー特典】/, label: 'バースデー特典' },
  { pattern: /ランクアップ/, label: 'ランクアップ' },
  { pattern: /Gold特典メール/, label: '会員特典' },
  { pattern: /【THANKS招待】/, label: 'THANKS招待' },
  { pattern: /【クーポンメール】/, label: 'クーポンメール' },
  { pattern: /【INFO】/, label: 'INFO' },
  { pattern: /RNオープンメルマガ/, label: 'RNオープン' },
  { pattern: /mobility/, label: 'mobility' },
  { pattern: /BAY閉店メルマガ/, label: '閉店メルマガ' },
];

function getLabel(name) {
  for (const rule of rules) {
    if (rule.pattern.test(name)) return rule.label;
  }
  return '';
}

const labels = values.map(v => [getLabel(v)]);

// Output as JSON for gws
const output = JSON.stringify({ values: labels });
fs.writeFileSync('tasks/成果レポート自動化/labels_payload.json', output, 'utf-8');
console.log(`Generated ${labels.length} labels`);

// Show label distribution
const counts = {};
labels.forEach(([l]) => { if (l) counts[l] = (counts[l] || 0) + 1; });
console.log(JSON.stringify(counts, null, 2));
