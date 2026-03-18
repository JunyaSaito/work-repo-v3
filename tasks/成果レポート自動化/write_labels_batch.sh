#!/bin/bash
SHEET_ID="1XcBmJkq4gh4lvcfj67PPoi5Ax_bZZLMywMOm9R26DgI"
WORKDIR="tasks/成果レポート自動化"

for i in 0 1 2 3; do
  case $i in
    0) ROW=2 ;;
    1) ROW=502 ;;
    2) ROW=1002 ;;
    3) ROW=1502 ;;
  esac
  echo "Writing batch $i starting at row $ROW..."
  PAYLOAD=$(cat "$WORKDIR/labels_batch_${i}.json")
  gws sheets spreadsheets values update \
    --params "{\"spreadsheetId\": \"$SHEET_ID\", \"range\": \"配信実績!H${ROW}\", \"valueInputOption\": \"USER_ENTERED\"}" \
    --json "$PAYLOAD"
  echo "Done batch $i"
done
