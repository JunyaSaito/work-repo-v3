#!/bin/bash
LABELS_JSON=$(cat "$TEMP/labels.json")
gws sheets spreadsheets values update \
  --params '{"spreadsheetId": "1qpehXW9GP_2R_S4ZSGc0yWmMQ6X1SyeXTMMpRTKmRYY", "range": "配信実績!H1", "valueInputOption": "USER_ENTERED"}' \
  --json "$LABELS_JSON"
