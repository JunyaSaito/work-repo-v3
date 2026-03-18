echo "=== 年月別サマリ ==="
gws sheets spreadsheets values get --params '{"spreadsheetId": "17hbZF5p8t0O254YV7LKXWkcABBvqwsRn-GqV60e5OlQ", "range": "成果レポート_202510-202512!F10:Q13", "valueRenderOption": "FORMATTED_VALUE"}'
echo ""
echo "=== ラベル別サマリ (先頭3行) ==="
gws sheets spreadsheets values get --params '{"spreadsheetId": "17hbZF5p8t0O254YV7LKXWkcABBvqwsRn-GqV60e5OlQ", "range": "成果レポート_202510-202512!F16:Q19", "valueRenderOption": "FORMATTED_VALUE"}'
