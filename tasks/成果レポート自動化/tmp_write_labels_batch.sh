#!/bin/bash
set -euo pipefail

SHEET_ID="1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY"
WIN_TEMP=$(cygpath -w /tmp)
LABELS_FILE="${WIN_TEMP}\\labels.json"
BATCH_FILE="/tmp/labels_batch.json"
BATCH_SIZE=500

TOTAL=$(node -e "const d=JSON.parse(require('fs').readFileSync(String.raw\`$LABELS_FILE\`,'utf8')); console.log(d.values.length);")
echo "Total rows: $TOTAL"

for ((start=0; start<TOTAL; start+=BATCH_SIZE)); do
  end=$((start + BATCH_SIZE))
  if [ $end -gt $TOTAL ]; then end=$TOTAL; fi
  row_num=$((start + 1))

  node -e "
    const d = JSON.parse(require('fs').readFileSync(String.raw\`$LABELS_FILE\`,'utf8'));
    const batch = d.values.slice($start, $end);
    require('fs').writeFileSync(String.raw\`${WIN_TEMP}\\labels_batch.json\`, JSON.stringify({values: batch}));
  "

  # Write using --json with command substitution from file
  gws sheets spreadsheets values update \
    --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H${row_num}\", \"valueInputOption\": \"USER_ENTERED\"}" \
    --json "$(cat "$BATCH_FILE")"
  echo "  → H${row_num}:H${end} 書き込み完了"
done

echo "✅ ラベル書き込み完了"
