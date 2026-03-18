#!/bin/bash
SID=215253313
BORDER='{"style":"SOLID","width":1,"color":{"red":0.7176471,"green":0.7176471,"blue":0.7176471}}'
CELL='{"userEnteredFormat":{"borders":{"top":'$BORDER',"bottom":'$BORDER',"left":'$BORDER',"right":'$BORDER'}}}'
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"17hbZF5p8t0O254YV7LKXWkcABBvqwsRn-GqV60e5OlQ"}' \
  --json '{
    "requests": [
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":9,"endRowIndex":13,"startColumnIndex":15,"endColumnIndex":17},
          "cell": '$CELL',
          "fields": "userEnteredFormat.borders"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":15,"endRowIndex":30,"startColumnIndex":15,"endColumnIndex":17},
          "cell": '$CELL',
          "fields": "userEnteredFormat.borders"
        }
      }
    ]
  }'
