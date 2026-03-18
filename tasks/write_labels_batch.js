const fs = require('fs');
const { execSync } = require('child_process');

const data = JSON.parse(fs.readFileSync('tasks/labels_data.json', 'utf-8'));
const values = data.values;
const SHEET_ID = '1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY';
const BATCH_SIZE = 200;

for (let i = 0; i < values.length; i += BATCH_SIZE) {
  const batch = values.slice(i, i + BATCH_SIZE);
  const rowStart = i + 1; // 1-indexed
  const range = `配信実績!H${rowStart}`;
  const jsonPayload = JSON.stringify({ values: batch });

  // Write payload to temp file
  const tmpFile = `tasks/tmp_batch_${i}.json`;
  fs.writeFileSync(tmpFile, jsonPayload);

  // Build shell script
  const shContent = `#!/bin/bash
gws sheets spreadsheets values update \\
  --params '{"spreadsheetId": "${SHEET_ID}", "range": "${range}", "valueInputOption": "USER_ENTERED"}' \\
  --json '${jsonPayload.replace(/'/g, "'\\''")}'
`;
  const shFile = `tasks/tmp_batch_${i}.sh`;
  fs.writeFileSync(shFile, shContent);

  try {
    const result = execSync(`bash ${shFile}`, { encoding: 'utf-8', timeout: 30000 });
    console.log(`Batch ${i}-${i + batch.length}: OK`);
  } catch (e) {
    console.error(`Batch ${i} failed:`, e.stderr || e.message);
  }

  // Cleanup
  fs.unlinkSync(tmpFile);
  fs.unlinkSync(shFile);
}
console.log('Done');
