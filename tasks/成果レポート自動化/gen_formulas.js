// gen_formulas.js
// Usage: node gen_formulas.js CONFIG_FILE N month1 month2 ...
// CONFIG_FILE: detect_columns.js が出力した JSON
const fs = require("fs");
const { colLetter } = require("./utils");
const [, , configFile, n, ...months] = process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));
const dateCol = config.dateCol || "B";

const FIRST = 18; // データ開始行
const SUMMARY_START = 5; // F列 = index 5

function sumifs(srcCol, row) {
  return `=SUMIFS('配信実績'!$${srcCol}$2:$${srcCol},'配信実績'!$${dateCol}$2:$${dateCol},">="&$F${row},'配信実績'!$${dateCol}$2:$${dateCol},"<"&EDATE($F${row},1))`;
}

const values = months.map((ym, i) => {
  const [y, m] = ym.split("/");
  const r = FIRST + i;
  const row = [];

  // 1列目: 日付
  row.push(`=DATE(${y},${m},1)`);

  // 各指標のサマリ列位置を記録（率の分母参照用）
  const metricColMap = {};
  let colIdx = 1; // 0 は日付列

  for (const metric of config.metrics) {
    const summaryCol = colLetter(SUMMARY_START + colIdx);
    metricColMap[metric.name] = summaryCol;
    row.push(sumifs(metric.srcCol, r));
    colIdx++;

    if (metric.rateOf) {
      const denomCol = metricColMap[metric.rateOf];
      row.push(`=IFERROR(${summaryCol}${r}/${denomCol}${r},0)`);
      colIdx++;
    }
  }

  return row;
});

console.log(JSON.stringify({ values }));
