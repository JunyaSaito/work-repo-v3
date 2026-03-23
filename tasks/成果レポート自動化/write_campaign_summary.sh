#!/bin/bash
# 施策一覧サマリを成果レポートシートに書き込む
# Usage: ./write_campaign_summary.sh "開始日" "終了日" "スプレッドシートID" "config.json"
#
# 前提: write_report.sh と write_label_summary.sh が実行済みであること
# 出力: INSIGHT_CELL=C{行番号} を stdout に出力（示唆書き込み先）

set -euo pipefail

START_DATE="${1:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
END_DATE="${2:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
SHEET_ID="${3:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
CONFIG_FILE="${4:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"

# テンプレの固定位置
TEMPLATE_ROWS=3               # 年月別サマリのデフォルト行数（行18-20）
TEMPLATE_LABEL_ROWS=5         # ラベル別サマリのデフォルト行数（行26-30）
TEMPLATE_LIST_TITLE_ROW=31    # E31: 施策一覧サマリ タイトル
TEMPLATE_LIST_DATA_START=34   # F34: 施策一覧データ開始行
TEMPLATE_LIST_DATA_ROWS=5     # テンプレのデータ行数（行34-38）
TEMPLATE_INSIGHT_LABEL_ROW=39 # B39: 示唆 ラベル

WORK="$(cd "$(dirname "$0")" && pwd)/.work_campaign_$$"; mkdir -p "$WORK"; trap "rm -rf $WORK" EXIT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v cygpath &>/dev/null; then
  WORK_NODE="$(cygpath -m "$WORK")"
  SCRIPT_DIR_NODE="$(cygpath -m "$SCRIPT_DIR")"
else
  WORK_NODE="$WORK"
  SCRIPT_DIR_NODE="$SCRIPT_DIR"
fi

# ── config 読み取り ──
eval "$(node -e "
const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf-8'));
console.log('SUMMARY_END_COL='+c.summaryEndCol);
console.log('SUMMARY_END_COL_IDX='+c.summaryEndColIndex);
console.log('SUMMARY_COLS='+c.summaryCols);
console.log('NUM_LABELS='+((c.labels||[]).length));
console.log('CAMPAIGN_COL='+(c.campaignCol||'A'));
console.log('DATE_COL='+(c.dateCol||'B'));
console.log('LABEL_COL='+(c.labelCol||'J'));
")"

# ── 月数・オフセット計算 ──
start_y=$(echo "$START_DATE" | cut -d/ -f1)
start_m=$(echo "$START_DATE" | cut -d/ -f2 | sed 's/^0//')
end_y=$(echo "$END_DATE"     | cut -d/ -f1)
end_m=$(echo "$END_DATE"     | cut -d/ -f2 | sed 's/^0//')
n=$(( (end_y - start_y) * 12 + end_m - start_m + 1 ))

extra_months=$((n > TEMPLATE_ROWS ? n - TEMPLATE_ROWS : 0))
extra_label_rows=$((NUM_LABELS > TEMPLATE_LABEL_ROWS ? NUM_LABELS - TEMPLATE_LABEL_ROWS : 0))

# シート名
s=$(printf '%04d%02d' "$start_y" "$start_m")
e=$(printf '%04d%02d' "$end_y"   "$end_m")
SHEET="成果レポート_${s}-${e}"

# 施策一覧セクションの現在位置（テンプレ位置 + 年月追加分 + ラベル追加分 + ラベル/施策間空白行）
LABEL_LIST_GAP=2  # write_report.sh と合わせる
offset=$((extra_months + extra_label_rows + LABEL_LIST_GAP))
list_title_row=$((TEMPLATE_LIST_TITLE_ROW + offset))
list_data_start=$((TEMPLATE_LIST_DATA_START + offset))

echo "▶ シート: $SHEET"
echo "▶ 施策一覧タイトル行: $list_title_row, データ開始行: $list_data_start"

# ════════════════════════════════════════════════
# 0. レポートシートの sheetId を取得
# ════════════════════════════════════════════════
echo "[0/6] sheetId を取得..."
cat > "$WORK/get_sheets.sh" <<SH
gws sheets spreadsheets get \
  --params '{"spreadsheetId":"$SHEET_ID","fields":"sheets.properties"}'
SH
bash "$WORK/get_sheets.sh" > "$WORK/sheets.json"
SID=$(node -e "
const d=JSON.parse(require('fs').readFileSync('$WORK_NODE/sheets.json','utf-8'));
const s=d.sheets.find(s=>s.properties.title==='$SHEET');
if(!s){console.error('ERROR: 「$SHEET」シートが見つかりません');process.exit(1)}
console.log(s.properties.sheetId);
")
echo "  → sheetId: $SID"

# ════════════════════════════════════════════════
# 1. 配信実績データを読み取り、最終月の施策を抽出
# ════════════════════════════════════════════════
echo "[1/6] 配信実績データを読み取り..."
cat > "$WORK/read_name.sh" <<SH
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"$SHEET_ID","range":"配信実績!${CAMPAIGN_COL}:${CAMPAIGN_COL}","valueRenderOption":"FORMATTED_VALUE"}'
SH
cat > "$WORK/read_date.sh" <<SH
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"$SHEET_ID","range":"配信実績!${DATE_COL}:${DATE_COL}","valueRenderOption":"FORMATTED_VALUE"}'
SH
cat > "$WORK/read_label.sh" <<SH
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"$SHEET_ID","range":"配信実績!${LABEL_COL}:${LABEL_COL}"}'
SH
bash "$WORK/read_name.sh" > "$WORK/name.json"
bash "$WORK/read_date.sh" > "$WORK/date.json"
bash "$WORK/read_label.sh" > "$WORK/label.json"

eval "$(node "$SCRIPT_DIR_NODE/gen_campaign_formulas.js" \
  "$CONFIG_FILE" "$WORK_NODE/name.json" "$WORK_NODE/date.json" "$WORK_NODE/label.json" \
  "$end_y" "$end_m" "$list_data_start" "$WORK_NODE")"
echo "  → 最終月(${end_y}/${end_m})のユニーク施策数: $NUM_CAMPAIGNS"

# ════════════════════════════════════════════════
# 2. 行挿入（テンプレ5行を超える分を最初のデータ行の下に挿入）
# ════════════════════════════════════════════════
extra_campaigns=$((NUM_CAMPAIGNS > TEMPLATE_LIST_DATA_ROWS ? NUM_CAMPAIGNS - TEMPLATE_LIST_DATA_ROWS : 0))

if [[ $extra_campaigns -gt 0 ]]; then
    echo "[2/6] データ行を${extra_campaigns}行追加挿入..."
    insert_idx=$list_data_start  # 0-based: 最初のデータ行の直後
    cat > "$WORK/insert_rows.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$insert_idx,"endIndex":$((insert_idx + extra_campaigns))},"inheritFromBefore":true}}]}'
SH
    bash "$WORK/insert_rows.sh"
    echo "  → 完了"
else
    echo "[2/6] 行挿入不要（${NUM_CAMPAIGNS}施策 ≤ テンプレ${TEMPLATE_LIST_DATA_ROWS}行）"
fi

list_data_end=$((list_data_start + NUM_CAMPAIGNS - 1))

# ════════════════════════════════════════════════
# 3. タイトル・ヘッダーを書き込み
# ════════════════════════════════════════════════
echo "[3/6] タイトル・ヘッダーを書き込み..."

# タイトル行のG列にYYYY年M月
cat > "$WORK/write_title.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!G${list_title_row}","valueInputOption":"USER_ENTERED"}' \
  --json '{"values":[["${end_y}年${end_m}月"]]}'
SH
bash "$WORK/write_title.sh"

# ヘッダー行（K列以降に指標ヘッダー、施策名ヘッダーは不要）
list_header_row=$((list_title_row + 2))
node -e "
const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf-8'));
const header=c.summaryHeader.slice(1);
require('fs').writeFileSync('$WORK_NODE/list_header.json',JSON.stringify({values:[header]}));
console.log('LIST_HEADER_END_COL_IDX='+(10+header.length));
" > "$WORK/list_meta.txt"
eval "$(cat $WORK/list_meta.txt)"
LIST_HEADER_END_COL=$(node -e "
const {colLetter}=require('$SCRIPT_DIR_NODE/utils');
console.log(colLetter($LIST_HEADER_END_COL_IDX - 1));
")
cat > "$WORK/write_header.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!K${list_header_row}:${LIST_HEADER_END_COL}${list_header_row}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $WORK/list_header.json)"
SH
bash "$WORK/write_header.sh"
echo "  → タイトル(G${list_title_row}) + ヘッダー(K${list_header_row}:${LIST_HEADER_END_COL}${list_header_row}) 完了"

# ════════════════════════════════════════════════
# 4. 施策名と数式を書き込み
# ════════════════════════════════════════════════
echo "[4/6] 施策名を書き込み (F${list_data_start}:F${list_data_end})..."
cat > "$WORK/write_names.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${list_data_start}:F${list_data_end}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $WORK/names.json)"
SH
bash "$WORK/write_names.sh"

echo "  数式を書き込み (${CHUNK_COUNT}チャンク)..."
for ((i=0; i<CHUNK_COUNT; i++)); do
    CHUNK_RANGE=$(cat "$WORK/formulas_${i}_range.txt")
    cat > "$WORK/write_formulas_${i}.sh" <<SH
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!${CHUNK_RANGE}","valueInputOption":"USER_ENTERED"}' \
  --json "\$(cat $WORK/formulas_${i}.json)"
SH
    bash "$WORK/write_formulas_${i}.sh"
    echo "    → チャンク${i} (${CHUNK_RANGE}) 完了"
done

# テンプレの余剰列（metrics終端〜U列）をクリア
TEMPLATE_CAMPAIGN_MAX_COL_IDX=21  # U列+1 (0-based exclusive)
if [[ $METRICS_END_COL_IDX -lt $TEMPLATE_CAMPAIGN_MAX_COL_IDX ]]; then
    clear_start_row=$((list_header_row - 1))  # 0-based
    clear_end_row=$list_data_end              # 0-based exclusive
    cat > "$WORK/clear_extra_cols.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"updateCells":{"range":{"sheetId":$SID,"startRowIndex":$clear_start_row,"endRowIndex":$clear_end_row,"startColumnIndex":$METRICS_END_COL_IDX,"endColumnIndex":$TEMPLATE_CAMPAIGN_MAX_COL_IDX},"fields":"userEnteredValue,userEnteredFormat"}}]}'
SH
    bash "$WORK/clear_extra_cols.sh"
    echo "  → 不要列($(node -e "const {colLetter}=require('$SCRIPT_DIR_NODE/utils');console.log(colLetter($METRICS_END_COL_IDX))")〜U)の書式・値をクリア完了"
fi

# ════════════════════════════════════════════════
# 5. フォーマットを統一
# ════════════════════════════════════════════════
echo "[5/6] フォーマットを適用..."

# F~J列（施策名エリア）はテンプレの書式をcopyPasteでコピー
if [[ $NUM_CAMPAIGNS -gt 1 ]]; then
    src_start_row=$((list_data_start - 1))  # 0-based
    src_end_row=$list_data_start            # 0-based exclusive
    dst_start_row=$list_data_start          # 0-based
    dst_end_row=$((list_data_end))          # 0-based exclusive
    cat > "$WORK/copy_fmt_names.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"copyPaste":{"source":{"sheetId":$SID,"startRowIndex":$src_start_row,"endRowIndex":$src_end_row,"startColumnIndex":5,"endColumnIndex":10},"destination":{"sheetId":$SID,"startRowIndex":$dst_start_row,"endRowIndex":$dst_end_row,"startColumnIndex":5,"endColumnIndex":10},"pasteType":"PASTE_FORMAT"}}]}'
SH
    bash "$WORK/copy_fmt_names.sh"
    echo "  → F~J列の書式をcopyPaste完了"
fi

# K列以降（指標列）はgen_formats.jsで動的にフォーマット適用（列数不問）
node "$SCRIPT_DIR_NODE/gen_formats.js" "$CONFIG_FILE" "$SID" "campaign" "$list_header_row" "$list_data_end" "$WORK_NODE/fmt_campaign.json"
cat > "$WORK/apply_fmt_campaign.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json "\$(cat $WORK/fmt_campaign.json)"
SH
bash "$WORK/apply_fmt_campaign.sh"
echo "  → K列以降の数値書式・罫線・ヘッダー書式を適用完了"

# テンプレ行数未満の場合、余分なテンプレ行をクリア
if [[ $NUM_CAMPAIGNS -lt $TEMPLATE_LIST_DATA_ROWS ]]; then
    clear_start=$((list_data_start + NUM_CAMPAIGNS - 1))  # 0-based
    clear_end=$((list_data_start + TEMPLATE_LIST_DATA_ROWS - 1))  # 0-based exclusive
    cat > "$WORK/clear_leftover.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"updateCells":{"range":{"sheetId":$SID,"startRowIndex":$clear_start,"endRowIndex":$clear_end,"startColumnIndex":5,"endColumnIndex":$METRICS_END_COL_IDX},"fields":"userEnteredValue"}}]}'
SH
    bash "$WORK/clear_leftover.sh"
    echo "  → 余分なテンプレ行をクリア完了"
fi

# ════════════════════════════════════════════════
# 6. 空白行を挿入（施策一覧サマリ最終行と示唆セクションの間）
# ════════════════════════════════════════════════
echo "[6/6] 空白行を挿入..."
separator_idx=$((list_data_end))  # 0-based: 最終データ行の直後
cat > "$WORK/insert_separator.sh" <<SH
gws sheets spreadsheets batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json '{"requests":[{"insertDimension":{"range":{"sheetId":$SID,"dimension":"ROWS","startIndex":$separator_idx,"endIndex":$((separator_idx + 1))},"inheritFromBefore":false}},{"repeatCell":{"range":{"sheetId":$SID,"startRowIndex":$separator_idx,"endRowIndex":$((separator_idx + 1)),"startColumnIndex":0,"endColumnIndex":26},"cell":{"userEnteredFormat":{"backgroundColor":{"red":1,"green":1,"blue":1}}},"fields":"userEnteredFormat.backgroundColor"}}]}'
SH
bash "$WORK/insert_separator.sh"
echo "  → 完了"

# ════════════════════════════════════════════════
# 出力: 示唆セクションの位置
# ════════════════════════════════════════════════
# 示唆ラベル行 = テンプレ位置 + 各セクションの追加行数 + セパレーター行
# write_report.sh の separator(1) + 施策一覧の extra_campaigns + 施策一覧後の separator(1)
insight_label_row=$((TEMPLATE_INSIGHT_LABEL_ROW + offset + 1 + extra_campaigns + 1))
insight_row=$((insight_label_row + 2))

echo ""
echo "SHEET_NAME=$SHEET"
echo "INSIGHT_CELL=C${insight_row}"
echo "✅ 施策一覧サマリを書き込みました（シート: $SHEET）"
