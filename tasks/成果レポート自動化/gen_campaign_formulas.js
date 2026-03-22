// gen_campaign_formulas.js
// Usage: node gen_campaign_formulas.js CONFIG_FILE AB_DATA_FILE J_DATA_FILE LAST_YEAR LAST_MONTH DATA_START_ROW OUT_DIR
//
// AB_DATA_FILE: gws values get の出力JSON（配信実績!A:B）
// J_DATA_FILE:  gws values get の出力JSON（配信実績!J:J）※ラベル列
// LAST_YEAR/LAST_MONTH: 最終月の年・月（数値）
// DATA_START_ROW: 施策一覧データ開始行（1-based）
// OUT_DIR: 出力先ディレクトリ
//
// 出力ファイル:
//   OUT_DIR/names.json          - F列用の施策名 values
//   OUT_DIR/formulas_N.json     - K列以降の数式 values（チャンクN）
//   stdout: NUM_CAMPAIGNS=数, CHUNK_COUNT=数

const fs = require("fs");
const path = require("path");
const { colLetter } = require("./utils");

const [, , configFile, abFile, jFile, lastYearStr, lastMonthStr, dataStartRowStr, outDir] =
  process.argv;

const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));
const abData = JSON.parse(fs.readFileSync(abFile, "utf-8"));
const jData = JSON.parse(fs.readFileSync(jFile, "utf-8"));
const lastYear = parseInt(lastYearStr);
const lastMonth = parseInt(lastMonthStr);
const dataStartRow = parseInt(dataStartRowStr);

// ── 最終月のユニーク施策名を抽出 ──
const abRows = abData.values.slice(1);
const jRows = jData.values.slice(1);

const campaignMap = new Map(); // name -> label
const datePattern = new RegExp(
  `${lastYear}[/\\-]${lastMonth}(?:[/\\-]|$)|` +
  `${lastYear}[/\\-]${String(lastMonth).padStart(2, "0")}(?:[/\\-]|$)`
);

for (let i = 0; i < abRows.length; i++) {
  const name = abRows[i][0];
  const date = abRows[i][1];
  const label = jRows[i] ? jRows[i][0] : "";
  if (!name || !date) continue;
  if (datePattern.test(date)) {
    if (!campaignMap.has(name)) {
      campaignMap.set(name, label);
    }
  }
}

// ラベル順 → 施策名順でソート
const sorted = [...campaignMap.entries()].sort((a, b) =>
  a[1].localeCompare(b[1]) || a[0].localeCompare(b[0])
);

const numCampaigns = sorted.length;

// ── 施策名 values 生成（F列用）──
const names = sorted.map(([name]) => [name]);
fs.writeFileSync(path.join(outDir, "names.json"), JSON.stringify({ values: names }));

// ── 数式 values 生成（K列以降）──
// 施策一覧は F~J:施策名, K以降:指標（施策名が長いためF~J列を使用）
const LIST_METRICS_START = 10; // K列

// 最終月の日付範囲
const lastDay = new Date(lastYear, lastMonth, 0).getDate();
const ds = `DATE(${lastYear},${lastMonth},1)`;
const de = `DATE(${lastYear},${lastMonth},${lastDay})`;

function sumifs(srcCol, row) {
  return `=SUMIFS('配信実績'!${srcCol}:${srcCol},'配信実績'!A:A,F${row},'配信実績'!B:B,">="&${ds},'配信実績'!B:B,"<="&${de})`;
}

const allFormulas = sorted.map((_, i) => {
  const r = dataStartRow + i;
  const row = [];
  const metricColMap = {};
  let colIdx = 0;

  for (const metric of config.metrics) {
    const summaryCol = colLetter(LIST_METRICS_START + colIdx);
    metricColMap[metric.name] = summaryCol;
    row.push(sumifs(metric.srcCol, r));
    colIdx++;

    if (metric.rateOf) {
      const denomCol = metricColMap[metric.rateOf];
      const rateCol = colLetter(LIST_METRICS_START + colIdx);
      row.push(`=IFERROR(${summaryCol}${r}/${denomCol}${r},0)`);
      colIdx++;
    }
  }
  return row;
});

// チャンク分割（gws 引数長制限対策）
const CHUNK_SIZE = 20;
let chunkCount = 0;
for (let i = 0; i < allFormulas.length; i += CHUNK_SIZE) {
  const chunk = allFormulas.slice(i, i + CHUNK_SIZE);
  const startRow = dataStartRow + i;
  const endRow = startRow + chunk.length - 1;
  const startCol = colLetter(LIST_METRICS_START);
  const endCol = colLetter(LIST_METRICS_START + (chunk[0] ? chunk[0].length - 1 : 0));
  fs.writeFileSync(
    path.join(outDir, `formulas_${chunkCount}.json`),
    JSON.stringify({ values: chunk })
  );
  fs.writeFileSync(
    path.join(outDir, `formulas_${chunkCount}_range.txt`),
    `${startCol}${startRow}:${endCol}${endRow}`
  );
  chunkCount++;
}

// メトリクス列情報も出力
const metricsColCount = allFormulas[0] ? allFormulas[0].length : 0;
const metricsEndCol = colLetter(LIST_METRICS_START + metricsColCount - 1);

console.log(`NUM_CAMPAIGNS=${numCampaigns}`);
console.log(`CHUNK_COUNT=${chunkCount}`);
console.log(`METRICS_START_COL=${colLetter(LIST_METRICS_START)}`);
console.log(`METRICS_END_COL=${metricsEndCol}`);
console.log(`METRICS_END_COL_IDX=${LIST_METRICS_START + metricsColCount}`);
