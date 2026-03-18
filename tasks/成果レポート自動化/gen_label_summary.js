// gen_label_summary.js
// Usage: node gen_label_summary.js CONFIG_FILE START_DATE END_DATE SECTION_TITLE_ROW SHEET_NAME OUT_FILE
// CONFIG_FILE: detect_columns.js が出力した JSON
const fs = require("fs");
const [, , configFile, startDate, endDate, sectionTitleRowStr, sheet, outFile] =
  process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));

const LABELS = [
  "全店メルマガ",
  "週間ランキング",
  "レコメンド",
  "個店メルマガ",
  "かご落ち",
  "閲覧リタゲ",
  "お気に入りリタゲ",
  "F2転換",
  "バースデー特典",
  "ランクアップ",
  "Gold特典",
  "THANKS招待",
  "クーポンメール",
  "INFO",
];

const [sy, sm, sd] = startDate.split("/").map(Number);
const [ey, em, ed] = endDate.split("/").map(Number);

const ds = `DATE(${sy},${sm},${sd})`;
const de = `DATE(${ey},${em},${ed})`;

const SUMMARY_START = 5; // F列 = index 5
const labelCol = config.labelCol;

function colLetter(index) {
  let s = "";
  let i = index;
  while (i >= 0) {
    s = String.fromCharCode(65 + (i % 26)) + s;
    i = Math.floor(i / 26) - 1;
  }
  return s;
}

function sumifs(srcCol, label) {
  return `SUMIFS('配信実績'!$${srcCol}$2:$${srcCol},'配信実績'!$B$2:$B,">="&${ds},'配信実績'!$B$2:$B,"<="&${de},'配信実績'!$${labelCol}$2:$${labelCol},"${label}")`;
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
