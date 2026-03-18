#!/bin/bash
SID=215253313
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"17hbZF5p8t0O254YV7LKXWkcABBvqwsRn-GqV60e5OlQ"}' \
  --json '{
    "requests": [
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":10,"endRowIndex":13,"startColumnIndex":13,"endColumnIndex":14},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"NUMBER","pattern":"#,##0"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":10,"endRowIndex":13,"startColumnIndex":14,"endColumnIndex":15},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"PERCENT","pattern":"0.00%"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":10,"endRowIndex":13,"startColumnIndex":15,"endColumnIndex":17},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"CURRENCY","pattern":"\"¥\"#,##0"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":16,"endRowIndex":30,"startColumnIndex":13,"endColumnIndex":14},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"NUMBER","pattern":"#,##0"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":16,"endRowIndex":30,"startColumnIndex":14,"endColumnIndex":15},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"PERCENT","pattern":"0.00%"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      },
      {
        "repeatCell": {
          "range": {"sheetId":'$SID',"startRowIndex":16,"endRowIndex":30,"startColumnIndex":15,"endColumnIndex":17},
          "cell": {"userEnteredFormat": {"numberFormat": {"type":"CURRENCY","pattern":"\"¥\"#,##0"}}},
          "fields": "userEnteredFormat.numberFormat"
        }
      }
    ]
  }'
