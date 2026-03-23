// gen_label_summary.js
// Usage: node gen_label_summary.js CONFIG_FILE START_DATE END_DATE SECTION_TITLE_ROW SHEET_NAME OUT_FILE
// CONFIG_FILE: detect_columns.js が出力した JSON（labels フィールドにラベル一覧を含む）
const fs = require("fs");
const { colLetter } = require("./utils");
const [, , configFile, startDate, endDate, sectionTitleRowStr, sheet, outFile] =
  process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));

if (!config.labels || config.labels.length === 0) {
  console.error("ERROR: config.labels が未定義です。columns_config.json に labels を追加してください。");
  process.exit(1);
}
const LABELS = config.labels;

const [sy, sm, sd] = startDate.split("/").map(Number);
const [ey, em, ed] = endDate.split("/").map(Number);

const ds = `DATE(${sy},${sm},${sd})`;
const de = `DATE(${ey},${em},${ed})`;

const SUMMARY_START = 5; // F列 = index 5
const labelCol = config.labelCol;
const dateCol = config.dateCol || "B";

function sumifs(srcCol, label) {
  return `SUMIFS('配信実績'!$${srcCol}$2:$${srcCol},'配信実績'!$${dateCol}$2:$${dateCol},">="&${ds},'配信実績'!$${dateCol}$2:$${dateCol},"<="&${de},'配信実績'!$${labelCol}$2:$${labelCol},"${label}")`;
}

const sectionTitleRow = parseInt(sectionTitleRowStr);
const headerRow = sectionTitleRow + 2; // タイトルとヘッダー間に空白行あり
const dataStartRow = headerRow + 1;

const labelRows = LABELS.map((label, i) => {
  const r = dataStartRow + i;
  const row = [];

  // 1列目: ラベル名
  row.push(label);

  const metricColMap = {};
  let colIdx = 1;

  for (const metric of config.metrics) {
    const summaryCol = colLetter(SUMMARY_START + colIdx);
    metricColMap[metric.name] = summaryCol;
    row.push(`=${sumifs(metric.srcCol, label)}`);
    colIdx++;

    if (metric.rateOf) {
      const denomCol = metricColMap[metric.rateOf];
      row.push(`=IFERROR(${summaryCol}${r}/${denomCol}${r},0)`);
      colIdx++;
    }
  }

  return row;
});

// ラベル数を出力（シェルスクリプトから参照）
console.error(`NUM_LABELS=${LABELS.length}`);

// ラベル別サマリ用ヘッダー（「年月」→「ラベル」に差し替え）
const labelHeader = config.summaryHeader.map((h, i) => (i === 0 ? "ラベル" : h));

const endCol = config.summaryEndCol;

const payload = {
  valueInputOption: "USER_ENTERED",
  data: [
    {
      range: `${sheet}!E${sectionTitleRow}`,
      values: [["ラベル別サマリ"]],
    },
    {
      range: `${sheet}!F${headerRow}:${endCol}${headerRow}`,
      values: [labelHeader],
    },
    {
      range: `${sheet}!F${dataStartRow}:${endCol}${dataStartRow + LABELS.length - 1}`,
      values: labelRows,
    },
  ],
};

fs.writeFileSync(outFile, JSON.stringify(payload));
