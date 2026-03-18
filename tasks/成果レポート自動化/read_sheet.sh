#!/bin/bash
SHEET_ID="1_wdvXZVZ_GU50reBN0--hx8_FeAWXEETA8_KAAhJ6Bw"

echo "=== A列（施策名） ==="
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!A:A\"}"

echo ""
echo "=== 1行目（ヘッダー） ==="
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!1:1\"}"
