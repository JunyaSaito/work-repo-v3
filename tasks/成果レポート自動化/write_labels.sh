#!/bin/bash
SHEET_ID="1XcBmJkq4gh4lvcfj67PPoi5Ax_bZZLMywMOm9R26DgI"
WORKDIR="tasks/成果レポート自動化"

# Write header
gws sheets spreadsheets values update \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H1\", \"valueInputOption\": \"USER_ENTERED\"}" \
  --json '{"values": [["ラベル"]]}'

# Write labels from payload
PAYLOAD=$(cat "$WORKDIR/labels_payload.json")
gws sheets spreadsheets values update \
  --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H2\", \"valueInputOption\": \"USER_ENTERED\"}" \
  --json "$PAYLOAD"
