#!/bin/bash
SHEET_ID="1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY"

gws sheets spreadsheets values update \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H1\", \"valueInputOption\": \"USER_ENTERED\"}" \
  --json-file tasks/labels_data.json
