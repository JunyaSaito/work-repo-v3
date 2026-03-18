const fs = require('fs');
const data = JSON.parse(fs.readFileSync('tasks/成果レポート自動化/labels_payload.json', 'utf-8'));
const values = data.values;
const BATCH_SIZE = 500;

for (let i = 0; i < values.length; i += BATCH_SIZE) {
  const batch = values.slice(i, i + BATCH_SIZE);
  const batchNum = Math.floor(i / BATCH_SIZE);
  const startRow = i + 2; // +2 because row 1 is header, data starts at row 2
  fs.writeFileSync(
    `tasks/成果レポート自動化/labels_batch_${batchNum}.json`,
    JSON.stringify({ values: batch }),
    'utf-8'
  );
  console.log(`Batch ${batchNum}: rows ${startRow}-${startRow + batch.length - 1} (${batch.length} rows)`);
}
