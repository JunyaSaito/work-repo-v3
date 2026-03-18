#!/bin/bash
# ラベル別サマリを成果レポートシートに書き込む
# Usage: ./write_label_summary.sh "開始日" "終了日" "スプレッドシートID" "config.json"

set -euo pipefail

START_DATE="${1:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
END_DATE="${2:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
SHEET_ID="${3:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"
CONFIG_FILE="${4:?Usage: $0 START_DATE END_DATE SHEET_ID CONFIG_FILE}"

# テンプレの固定位置（write_report.shと合わせる）
TEMPLATE_ROWS=3                # テンプレのデフォルトデータ行数（行18-20）
TEMPLATE_LABEL_TITLE_ROW=22    # E22: ラベル別サマリ タイトル

# config から動的値を読み取り
SUMMARY_END_COL=$(node -e "const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf-8'));console.log(c.summaryEndCol)")

# 月数を算出
start_y=$(echo "$START_DATE" | cut -d/ -f1)
start_m=$(echo "$START_DATE" | cut -d/ -f2 | sed 's/^0//')
end_y=$(echo "$END_DATE"   | cut -d/ -f1)
end_m=$(echo "$END_DATE"   | cut -d/ -f2 | sed 's/^0//')
n=$(( (end_y - start_y) * 12 + end_m - start_m + 1 ))

# シート名
s=$(printf '%04d%02d' "$start_y" "$start_m")
e=$(printf '%04d%02d' "$end_y"   "$end_m")
SHEET="成果レポート_${s}-${e}"

# 月数超過分だけ位置をずらす
extra_months=$((n > TEMPLATE_ROWS ? n - TEMPLATE_ROWS : 0))
section_title_row=$((TEMPLATE_LABEL_TITLE_ROW + extra_months))

echo "▶ シート: $SHEET"
echo "▶ サマリ列: F:$SUMMARY_END_COL"
echo "▶ ラベル別サマリ開始行: $section_title_row（ヘッダー: $((section_title_row + 2))、データ: $((section_title_row + 3))〜）"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$SCRIPT_DIR/.work_label_$$"; mkdir -p "$WORK"; trap "rm -rf $WORK" EXIT
if command -v cygpath &>/dev/null; then
  WORK_NODE="$(cygpath -m "$WORK")"
  SCRIPT_DIR_NODE="$(cygpath -m "$SCRIPT_DIR")"
else
  WORK_NODE="$WORK"
  SCRIPT_DIR_NODE="$SCRIPT_DIR"
fi

echo "[1/3] 数式JSONを生成..."
node "$SCRIPT_DIR_NODE/gen_label_summary.js" \
  "$CONFIG_FILE" "$START_DATE" "$END_DATE" "$section_title_row" "$SHEET" "$WORK_NODE/payload.json"
echo "  → 完了"

echo "[2/3] シートに書き込み..."
cat > "$WORK/write.sh" <<SH
gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"$SHEET_ID"}' \
  --json "\$(cat $WORK/payload.json)"
SH
bash "$WORK/write.sh"
echo "  → 完了"

echo "[3/3] ラベル別集計値を読み取り..."
NUM_LABELS=14  # gen_label_summary.jsのラベル数と合わせる
data_start=$((section_title_row + 3))
data_end=$((data_start + NUM_LABELS - 1))
sleep 2  # Sheets再計算待ち
cat > "$WORK/read.sh" <<SH
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"$SHEET_ID","range":"$SHEET!F${data_start}:${SUMMARY_END_COL}${data_end}","valueRenderOption":"FORMATTED_VALUE"}'
SH
label_raw=$(bash "$WORK/read.sh")
echo "  → 完了"

echo "LABEL_RAW_DATA=$label_raw"

echo "✅ ラベル別サマリを書き込みました（シート: $SHEET）"
