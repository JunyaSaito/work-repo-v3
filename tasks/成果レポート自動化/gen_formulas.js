// gen_formulas.js
// Usage: node gen_formulas.js CONFIG_FILE N month1 month2 ...
// CONFIG_FILE: detect_columns.js が出力した JSON
const fs = require("fs");
const [, , configFile, n, ...months] = process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));

const FIRST = 18; // データ開始行
const SUMMARY_START = 5; // F列 = index 5

function colLetter(index) {
  let s = "";
  let i = index;
  while (i >= 0) {
    s = String.fromCharCode(65 + (i % 26)) + s;
    i = Math.floor(i / 26) - 1;
  }
  return s;
}

function sumifs(srcCol, row) {
  return `=SUMIFS('配信実績'!$${srcCol}$2:$${srcCol},'配信実績'!$B$2:$B,">="&$F${row},'配信実績'!$B$2:$B,"<"&EDATE($F${row},1))`;
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
