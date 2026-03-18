#!/bin/bash
SHEET_ID="1_wdvXZVZ_GU50reBN0--hx8_FeAWXEETA8_KAAhJ6Bw"
SID="1881736904"

gws sheets spreadsheets batchUpdate \
  --params "{\"spreadsheetId\":\"$SHEET_ID\"}" \
  --json "{\"requests\":[{\"deleteSheet\":{\"sheetId\":$SID}}]}"
