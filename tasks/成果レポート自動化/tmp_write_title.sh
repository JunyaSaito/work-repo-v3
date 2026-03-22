gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"17hbZF5p8t0O254YV7LKXWkcABBvqwsRn-GqV60e5OlQ"}' \
  --json '{
    "valueInputOption": "USER_ENTERED",
    "data": [
      {"range": "成果レポート_202510-202512!E41", "values": [["施策一覧サマリ"]]},
      {"range": "成果レポート_202510-202512!G41", "values": [["2025年12月"]]},
      {"range": "成果レポート_202510-202512!F43", "values": [["施策名"]]},
      {"range": "成果レポート_202510-202512!K43:U43", "values": [["配信数","開封数","開封率","クリック数","クリック率","直接CV数","直接CV率","間接CV数","間接CV率","直接CV金額","間接CV金額"]]}
    ]
  }'
