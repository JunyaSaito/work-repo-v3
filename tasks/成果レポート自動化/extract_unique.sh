#!/bin/bash
SHEET_ID="1XcBmJkq4gh4lvcfj67PPoi5Ax_bZZLMywMOm9R26DgI"
WORKDIR="tasks/成果レポート自動化"

# Get A column data and save
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!A2:A\"}" > "$WORKDIR/a_column.json"

# Extract unique names using node
node -e "
const fs = require('fs');
const path = require('path');
const filePath = path.resolve('$WORKDIR', 'a_column.json');
const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
const values = data.values.filter(r => r.length > 0).map(r => r[0]);
const unique = [...new Set(values)].sort();
unique.forEach(v => console.log(v));
"
