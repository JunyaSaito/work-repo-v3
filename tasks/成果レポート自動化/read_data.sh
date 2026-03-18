#!/bin/bash
SHEET_ID="1XcBmJkq4gh4lvcfj67PPoi5Ax_bZZLMywMOm9R26DgI"

echo "=== A列（施策名） ==="
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!A:A\"}"

echo ""
echo "=== 1行目（ヘッダー） ==="
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!1:1\"}"
