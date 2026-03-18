#!/bin/bash
SHEET_ID="1XcBmJkq4gh4lvcfj67PPoi5Ax_bZZLMywMOm9R26DgI"
SID=1101291603

gws sheets spreadsheets batchUpdate \
  --params "{\"spreadsheetId\": \"$SHEET_ID\"}" \
  --json '{"requests":[{"repeatCell":{"range":{"sheetId":'$SID',"startRowIndex":21,"endRowIndex":31,"startColumnIndex":1,"endColumnIndex":5},"cell":{"userEnteredFormat":{"backgroundColor":{"red":1,"green":1,"blue":1}}},"fields":"userEnteredFormat.backgroundColor"}},{"repeatCell":{"range":{"sheetId":'$SID',"startRowIndex":21,"endRowIndex":31,"startColumnIndex":14,"endColumnIndex":26},"cell":{"userEnteredFormat":{"backgroundColor":{"red":1,"green":1,"blue":1}}},"fields":"userEnteredFormat.backgroundColor"}}]}'
