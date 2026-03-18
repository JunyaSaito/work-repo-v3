// detect_columns.js
// Usage: node detect_columns.js HEADER_JSON_FILE
// Output: column config JSON to stdout
//
// HEADER_JSON_FILE: gws sheets values get の出力JSON（配信実績!1:1）
//
// 対応パターン:
//   1. 施策名|配信日|配信数|開封数|クリック数|CV数|CV金額
//   2. 施策名|配信日|配信数|開封数|クリック数|直接CV数|間接CV数|直接CV金額|間接CV金額
//   3. 施策名|配信日|配信数|開封数|クリック数|合計CV数|直接CV数|間接CV数|合計CV金額|直接CV金額|間接CV金額

const fs = require("fs");

const headerFile = process.argv[2];
const raw = JSON.parse(fs.readFileSync(headerFile, "utf-8"));
const header = raw.values[0];

function colLetter(index) {
  let s = "";
  let i = index;
  while (i >= 0) {
    s = String.fromCharCode(65 + (i % 26)) + s;
    i = Math.floor(i / 26) - 1;
  }
  return s;
}

// rateOf: この指標の「率」を計算するとき分母にする指標名
// rateOf が null → 率列を生成しない（金額系）
const RATE_MAP = {
  配信数: null,
  開封数: "配信数",
  クリック数: "開封数",
  CV数: "クリック数",
  合計CV数: "クリック数",
  直接CV数: "クリック数",
  間接CV数: "クリック数",
  CV金額: null,
  合計CV金額: null,
  直接CV金額: null,
  間接CV金額: null,
};

const metrics = [];
for (let i = 0; i < header.length; i++) {
  const h = header[i];
  if (h in RATE_MAP) {
    metrics.push({
      name: h,
      srcCol: colLetter(i),
      rateOf: RATE_MAP[h],
    });
  }
}

// ラベル列 = ヘッダーの次の空き列
const labelCol = colLetter(header.length);
const labelColIndex = header.length;

// サマリヘッダーを生成
const summaryHeader = ["年月"];
for (const m of metrics) {
  summaryHeader.push(m.name);
  if (m.rateOf) {
    summaryHeader.push(m.name.replace(/数$/, "率"));
  }
}

const SUMMARY_START = 5; // F列 = index 5
const summaryCols = summaryHeader.length;
const summaryEndCol = colLetter(SUMMARY_START + summaryCols - 1);
const summaryEndColIndex = SUMMARY_START + summaryCols; // exclusive (for batchUpdate)

const config = {
  metrics,
  labelCol,
  labelColIndex,
  summaryHeader,
  summaryCols,
  summaryStartCol: "F",
  summaryEndCol,
  summaryStartColIndex: SUMMARY_START,
  summaryEndColIndex,
};

console.log(JSON.stringify(config, null, 2));
