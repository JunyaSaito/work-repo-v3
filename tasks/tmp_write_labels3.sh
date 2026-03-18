#!/bin/bash
SHEET_ID="1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY"
JSON_DATA=$(cat tasks/labels_data.json)

gws sheets spreadsheets values update \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H1\", \"valueInputOption\": \"USER_ENTERED\"}" \
  --json "$JSON_DATA"
