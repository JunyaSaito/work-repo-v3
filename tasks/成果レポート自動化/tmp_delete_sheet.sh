#!/bin/bash
# シートID 1218800940 を削除
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId": "1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY"}' \
  --json '{"requests":[{"deleteSheet":{"sheetId":1218800940}}]}'
