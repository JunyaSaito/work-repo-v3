const fs = require('fs');
const data = JSON.parse(fs.readFileSync('C:/Users/user/.claude/projects/C--Users-user-projects-work-repo/28ba693f-e66b-4d4f-b8dd-e2c15941141e/tool-results/b8g2rl1zm.txt', 'utf-8'));
const rows = data.values;
const result = [];
for (let i = 0; i < rows.length; i++) {
  const name = rows[i][0] || '';
  let label = '';
  if (i === 0) {
    label = 'ラベル';
  } else if (name.includes('かご落ち')) {
    label = 'かご落ち';
  } else if (name === '閲覧リタゲ') {
    label = '閲覧リタゲ';
  } else if (name.includes('お気に入り')) {
    label = 'お気に入りリタゲ';
  } else if (name.includes('F2転換')) {
    label = 'F2転換';
  } else if (name.includes('バースデー特典')) {
    label = 'バースデー特典';
  } else if (name.includes('ランクアップ')) {
    label = 'ランクアップ';
  } else if (name.includes('個店メルマガ')) {
    label = '個店メルマガ';
  } else if (name === 'Gold特典メール' || name.includes('THANKS招待')) {
    label = '会員特典';
  } else if (name.includes('全店メルマガ') || name.includes('週間ランキング') || name.includes('レコメンド')) {
    label = '全店メルマガ';
  } else if (name.includes('mobility') || name.includes('BAY閉店') || name.includes('RNオープン') || name.includes('INFO') || name.includes('クーポンメール')) {
    label = 'その他';
  } else {
    label = 'その他';
  }
  result.push([label]);
}
fs.writeFileSync('tasks/labels_data.json', JSON.stringify({values: result}));
console.log('Generated ' + result.length + ' labels');
