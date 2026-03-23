#!/bin/bash
# 成果レポート自動生成スクリプト
# Usage: ./write_report.sh "2025/9/1" "2026/1/31" "スプレッドシートID" "config.json"

set -euo pipefail

START_DATE="${1:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
END_DATE="${2:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
SHEET_ID="${3:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
CONFIG_FILE="${4:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
TEMPLATE_SHEET_NAME="テンプレ"
FIRST_ROW=18              # データ開始行（行17はヘッダー）
TEMPLATE_ROWS=3           # テンプレのデフォルトデータ行数（行18-20）
TEMPLATE_LABEL_ROWS=5     # テンプレのラベルプレースホルダー行数（行26-30）
KPI_DATA_ROW=12           # メール施策の成果 データ行
# テンプレの固定位置（行挿入前の基準値）
TEMPLATE_LABEL_TITLE_ROW=23   # E23: ラベル別サマリ タイトル
TEMPLATE_INSIGHT_LABEL_ROW=39 # B39: 示唆 ラベル
LABEL_LIST_GAP=2              # ラベル別サマリと施策一覧サマリの間の空白行数

WORK="$(cd "$(dirname "$0")" && pwd)/.work_$$"; mkdir -p "$WORK"; trap "rm -rf $WORK" EXIT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Windows環境ではNode.jsがUnixパスを解釈できないため変換
if command -v cygpath &>/dev/null; then
  WORK_NODE="$(cygpath -m "$WORK")"
  SCRIPT_DIR_NODE="$(cygpath -m "$SCRIPT_DIR")"
else
  WORK_NODE="$WORK"
  SCRIPT_DIR_NODE="$SCRIPT_DIR"
fi

# ── config から動的値を一括読み取り ────────────────────────
eval "$(node -e "
const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf-8'));
console.log('SUMMARY_END_COL='+c.summaryEndCol);
console.log('SUMMARY_END_COL_IDX='+c.summaryEndColIndex);
console.log('SUMMARY_COLS='+c.summaryCols);
console.log('NUM_LABELS='+((c.labels||[]).length));
console.log('SUMMARY_HEADER_JSON='+JSON.stringify(JSON.stringify(c.summaryHeader)));
")"

echo "▶ サマリ列: F:$SUMMARY_END_COL (${SUMMARY_COLS}列)"

# ── 月リスト生成 ──────────────────────────────────────
start_y=$(echo "$START_DATE" | cut -d/ -f1)
start_m=$(echo "$START_DATE" | cut -d/ -f2 | sed 's/^0//')
end_y=$(echo "$END_DATE"     | cut -d/ -f1)
end_m=$(echo "$END_DATE"     | cut -d/ -f2 | sed 's/^0//')

months=(); y=$start_y; m=$start_m
while [[ $y -lt $end_y || ($y -eq $end_y && $m -le $end_m) ]]; do
    months+=("$y/$m")
    ((m++)) || true
    if [[ $m -gt 12 ]]; then m=1; ((y++)); fi
done
n=${#months[@]}

echo "▶ 対象月: ${months[0]} ~ ${months[-1]} (${n}ヶ月)"

# ── シート名 ──────────────────────────────────────────
s=$(printf '%04d%02d' "$start_y" "$start_m")
e=$(printf '%04d%02d' "$end_y"   "$end_m")
SHEET="成果レポート_${s}-${e}"
echo "▶ シート名: $SHEET"

# ════════════════════════════════════════════════
# 0. テンプレシートのIDを動的に取得
# ════════════════════════════════════════════════
echo "[0/9] テンプレシートID取得..."
cat > "$WORK/get_sheets.sh" <<SH
gws sheets spreadsheets get \
  --params '{"spreadsheetId":"$SHEET_ID","fields":"sheets.properties"}'
SH
bash "$WORK/get_sheets.sh" > "$WORK/sheets.json"
TEMPLATE_SHEET_ID=$(node -e "
const d=JSON.parse(require('fs').readFileSync('$WORK_NODE/sheets.json','utf-8'));
const s=d.sheets.find(s=>s.properties.title==='$TEMPLATE_SHEET_NAME');
if(!s){console.error('ERROR: 「$TEMPLATE_SHEET_NAME」シートが見つかりません');process.exit(1)}
console.log(s.properties.sheetId);
")
echo "  → $TEMPLATE_SHEET_NAME sheetId: $TEMPLATE_SHEET_ID"

# ════════════════════════════════════════════════
# 1. テンプレ複製
# ════════════════════════════════════════════════
echo "[1/9] テンプレを複製..."
cat > "$WORK/dup.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"duplicateSheet":{"sourceSheetId":$TEMPLATE_SHEET_ID,"insertSheetIndex":2,"newSheetName":"$SHEET"}}]}'
SH
result=$(bash "$WORK/dup.sh")
SID=$(echo "$result" | grep -o '"sheetId": [0-9]*' | head -1 | tr -dc '0-9')
echo "  → sheetId: $SID"

# テンプレの最大列数（Q列 = index 16 まで）を超える列をクリア
TEMPLATE_MAX_COL_IDX=17  # Q列+1 (0-based exclusive)
if [[ $SUMMARY_END_COL_IDX -lt $TEMPLATE_MAX_COL_IDX ]]; then
    # 年月別: ヘッダー行(17) + テンプレデータ行(18-20) → 0-based 16-20
    # ラベル別: ヘッダー行(25) + テンプレデータ行(26-30) → 0-based 24-30
    cat > "$WORK/clear_extra_cols.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"updateCells":{"range":{"sheetId":$SID,"startRowIndex":16,"endRowIndex":20,"startColumnIndex":$SUMMARY_END_COL_IDX,"endColumnIndex":$TEMPLATE_MAX_COL_IDX},"fields":"userEnteredValue,userEnteredFormat"}},{"updateCells":{"range":{"sheetId":$SID,"startRowIndex":24,"endRowIndex":30,"startColumnIndex":$SUMMARY_END_COL_IDX,"endColumnIndex":$TEMPLATE_MAX_COL_IDX},"fields":"userEnteredValue,userEnteredFormat"}}]}'
SH
    bash "$WORK/clear_extra_cols.sh"
    echo "  → 不要列($(node -e "const {colLetter}=require('$SCRIPT_DIR_NODE/utils');console.log(colLetter($SUMMARY_END_COL_IDX))")〜Q)の書式・値をクリア完了"
fi

# 月数がテンプレ行数を超える場合、データ行を追加挿入
extra_months=0
if [[ $n -gt $TEMPLATE_ROWS ]]; then
    extra_months=$((n - TEMPLATE_ROWS))
    insert_idx=$((FIRST_ROW - 1 + TEMPLATE_ROWS))  # 0-based index 13
    cat > "$WORK/insert_month_rows.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$insert_idx,"endIndex":$((insert_idx + extra_months))},"inheritFromBefore":true}}]}'
SH
    bash "$WORK/insert_month_rows.sh"
    echo "  → データ用に${extra_months}行追加挿入完了"
fi

# ════════════════════════════════════════════════
# 2. ヘッダー行を書き込み（動的列に対応）
# ════════════════════════════════════════════════
HEADER_ROW=$((FIRST_ROW - 1))  # 行10
echo "[2/9] ヘッダーを書き込み (F${HEADER_ROW}:${SUMMARY_END_COL}${HEADER_ROW})..."
node -e "
const header = $SUMMARY_HEADER_JSON;
const payload = JSON.stringify({values: [header]});
require('fs').writeFileSync('$WORK_NODE/header_payload.json', payload);
"
cat > "$WORK/write_header.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${HEADER_ROW}:${SUMMARY_END_COL}${HEADER_ROW}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $WORK/header_payload.json)"
SH
bash "$WORK/write_header.sh"
echo "  → 完了"

# ════════════════════════════════════════════════
# 3. 数式JSON生成
# ════════════════════════════════════════════════
echo "[3/9] 数式JSONを生成..."
node "$SCRIPT_DIR_NODE/gen_formulas.js" "$CONFIG_FILE" "$n" "${months[@]}" > "$WORK/formulas.json"
echo "  → 生成完了"

# ════════════════════════════════════════════════
# 4. 数式書き込み
# ════════════════════════════════════════════════
last_row=$((FIRST_ROW + n - 1))
echo "[4/9] 数式を書き込み (F${FIRST_ROW}:${SUMMARY_END_COL}${last_row})..."
FORMULAS_PATH="$WORK/formulas.json"
cat > "$WORK/write_formulas.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${FIRST_ROW}:${SUMMARY_END_COL}${last_row}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $FORMULAS_PATH)"
SH
bash "$WORK/write_formulas.sh"
echo "  → 完了"

# ════════════════════════════════════════════════
# 5. 前提テキスト更新（C4）
# ════════════════════════════════════════════════
echo "[5/9] 前提テキストを更新 (C4)..."
cat > "$WORK/premise.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!C4","valueInputOption":"USER_ENTERED"}' \
  --json '{"values":[["配信対象期間：$START_DATE~$END_DATE"]]}'
SH
bash "$WORK/premise.sh"
echo "  → 完了"

# ════════════════════════════════════════════════
# 6. メール施策の成果 KPI数式書き込み
# ════════════════════════════════════════════════
echo "[6/9] メール施策の成果 KPI数式を書き込み (F${KPI_DATA_ROW}:I${KPI_DATA_ROW})..."
node "$SCRIPT_DIR_NODE/gen_kpi_formulas.js" "$CONFIG_FILE" "$START_DATE" "$END_DATE" "$n" > "$WORK/kpi.json"
cat > "$WORK/write_kpi.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${KPI_DATA_ROW}:I${KPI_DATA_ROW}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $WORK/kpi.json)"
SH
bash "$WORK/write_kpi.sh"
echo "  → 完了"

# ════════════════════════════════════════════════
# 7. 集計値を読み取り（示唆生成用）
# ════════════════════════════════════════════════
echo "[7/9] 集計値を読み取り..."
sleep 2  # Sheets再計算待ち
cat > "$WORK/read.sh" <<SH
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${FIRST_ROW}:${SUMMARY_END_COL}${last_row}","valueRenderOption":"FORMATTED_VALUE"}'
SH
raw=$(bash "$WORK/read.sh")
echo "  → 完了"

# ════════════════════════════════════════════════
# 8. 集計データ出力（示唆はClaude Codeで生成）
# ════════════════════════════════════════════════
echo "[8/9] 集計データを出力..."
extra_label_rows=0
if [[ $NUM_LABELS -gt $TEMPLATE_LABEL_ROWS ]]; then
    extra_label_rows=$((NUM_LABELS - TEMPLATE_LABEL_ROWS))
fi
SEPARATOR_ROW=1  # ラベル別サマリと示唆セクションの間の空白行
label_title_row=$((TEMPLATE_LABEL_TITLE_ROW + extra_months))
insight_label_row=$((TEMPLATE_INSIGHT_LABEL_ROW + extra_months + extra_label_rows + LABEL_LIST_GAP + SEPARATOR_ROW))
insight_row=$((insight_label_row + 2))  # 示唆ラベル行 + 空白1行 + 本文行
echo "SHEET_NAME=$SHEET"
echo "LABEL_SUMMARY_ROW=${label_title_row}"
echo "INSIGHT_CELL=C${insight_row}"
echo "RAW_DATA=$raw"

# ════════════════════════════════════════════════
# 9. フォーマット整形
# ════════════════════════════════════════════════
echo "[9/9] フォーマット整形..."

# 年月別サマリの数値書式＋罫線を config から動的に適用
HEADER_ROW_1=$((FIRST_ROW - 1))  # ヘッダー行 (1-based)
node "$SCRIPT_DIR_NODE/gen_formats.js" "$CONFIG_FILE" "$SID" "monthly" "$HEADER_ROW_1" "$last_row" "$WORK_NODE/fmt_monthly.json"
cat > "$WORK/apply_fmt_monthly.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json "\$(cat $WORK/fmt_monthly.json)"
SH
bash "$WORK/apply_fmt_monthly.sh"
echo "  → 年月別サマリのフォーマット適用完了 (行${HEADER_ROW_1}:${last_row})"

# テンプレのデータ行数未満の場合は余分なテンプレ数式をクリア
if [[ $n -lt $TEMPLATE_ROWS ]]; then
    clear_start=$((FIRST_ROW - 1 + n))            # e.g., index 12 for n=2
    clear_end=$((FIRST_ROW - 1 + TEMPLATE_ROWS))  # index 13

    cat > "$WORK/clear_leftover.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"updateCells":{"range":{"sheetId":$SID,"startRowIndex":$clear_start,"endRowIndex":$clear_end,"startColumnIndex":5,"endColumnIndex":$SUMMARY_END_COL_IDX},"fields":"userEnteredValue"}}]}'
SH
    bash "$WORK/clear_leftover.sh"
    echo "  → 余分なテンプレ数式クリア完了"
fi

# ラベル数がテンプレ行数を超える場合、最初のラベルデータ行（26行目相当）の下に不足分を挿入
# inheritFromBefore:true でラベル行の書式を引き継ぎ、施策一覧セクションは自然に下へずれる
if [[ $extra_label_rows -gt 0 ]]; then
    first_label_data_row=$((label_title_row + 3))  # 1-based (26 + extra_months)
    insert_idx=$first_label_data_row                # 0-based: row 26 の直後
    cat > "$WORK/insert_label_rows.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$insert_idx,"endIndex":$((insert_idx + extra_label_rows))},"inheritFromBefore":true}}]}'
SH
    bash "$WORK/insert_label_rows.sh"
    echo "  → ラベル用に${extra_label_rows}行を行${first_label_data_row}の下に追加挿入完了"
fi

# セクション間の空白行を示唆セクション前に挿入
if [[ $SEPARATOR_ROW -gt 0 ]]; then
    separator_idx=$((TEMPLATE_INSIGHT_LABEL_ROW - 1 + extra_months + extra_label_rows))  # 0-based
    cat > "$WORK/insert_separator.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$separator_idx,"endIndex":$((separator_idx + SEPARATOR_ROW))},"inheritFromBefore":false}}]}'
SH
    bash "$WORK/insert_separator.sh"
    # 背景色を白にリセット
    cat > "$WORK/reset_bg.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"repeatCell":{"range":{"sheetId":$SID,"startRowIndex":$separator_idx,"endRowIndex":$((separator_idx + SEPARATOR_ROW)),"startColumnIndex":0,"endColumnIndex":26},"cell":{"userEnteredFormat":{"backgroundColor":{"red":1,"green":1,"blue":1}}},"fields":"userEnteredFormat.backgroundColor"}}]}'
SH
    bash "$WORK/reset_bg.sh"
    echo "  → 空白${SEPARATOR_ROW}行を示唆セクション前に挿入完了"
fi

# ラベル別サマリの数値書式＋罫線を config から動的に適用
label_header_row=$((label_title_row + 2))  # 1-based（タイトルとヘッダー間に空白行あり）
label_data_last=$((label_header_row + NUM_LABELS))  # 1-based, inclusive
node "$SCRIPT_DIR_NODE/gen_formats.js" "$CONFIG_FILE" "$SID" "label" "$label_header_row" "$label_data_last" "$WORK_NODE/fmt_label.json"
cat > "$WORK/apply_fmt_label.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json "\$(cat $WORK/fmt_label.json)"
SH
bash "$WORK/apply_fmt_label.sh"
echo "  → ラベル別サマリのフォーマット適用完了 (行${label_header_row}:${label_data_last})"

# ラベル別サマリと施策一覧サマリの間に空白行を挿入
if [[ $LABEL_LIST_GAP -gt 0 ]]; then
    gap_idx=$label_data_last  # 0-based: ラベル最終データ行の直後
    cat > "$WORK/insert_gap.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$gap_idx,"endIndex":$((gap_idx + LABEL_LIST_GAP))},"inheritFromBefore":false}},{"repeatCell":{"range":{"sheetId":$SID,"startRowIndex":$gap_idx,"endRowIndex":$((gap_idx + LABEL_LIST_GAP)),"startColumnIndex":0,"endColumnIndex":26},"cell":{"userEnteredFormat":{"backgroundColor":{"red":1,"green":1,"blue":1}}},"fields":"userEnteredFormat.backgroundColor"}}]}'
SH
    bash "$WORK/insert_gap.sh"
    echo "  → ラベル別サマリと施策一覧の間に空白${LABEL_LIST_GAP}行を挿入完了"
fi

echo ""
echo "✅ 完了！シート「$SHEET」が作成されました"
echo "   https://docs.google.com/spreadsheets/d/$SHEET_ID/"
