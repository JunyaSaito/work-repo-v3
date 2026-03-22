// gen_formats.js
// config.json の指標定義から、全サマリ列の数値書式＋罫線の batchUpdate リクエストを生成
// Usage: node gen_formats.js CONFIG_FILE SHEET_ID SECTION_TYPE START_ROW END_ROW OUT_FILE
//   SECTION_TYPE: "monthly" (年月別), "label" (ラベル別), "campaign" (施策一覧)
//   START_ROW: ヘッダー行 (1-based)
//   END_ROW: 最終データ行 (1-based, inclusive)
const fs = require("fs");
const [, , configFile, sheetId, sectionType, startRowStr, endRowStr, outFile] =
  process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));
const sid = parseInt(sheetId);
const startRow = parseInt(startRowStr); // 1-based header row
const endRow = parseInt(endRowStr); // 1-based last data row (inclusive)

// 施策一覧はK列(index 10)開始、それ以外はF列(index 5)開始
const SUMMARY_START = sectionType === "campaign" ? 10 : 5;

const BORDER = {
  style: "SOLID",
  width: 1,
  color: { red: 0.7176471, green: 0.7176471, blue: 0.7176471 },
};
const BORDERS = { top: BORDER, bottom: BORDER, left: BORDER, right: BORDER };

// 列ごとのフォーマットを決定
// 列順: [年月/ラベル, 指標1, (率1), 指標2, (率2), ...]
const colFormats = [];

// 1列目: 年月 or ラベル（施策一覧は指標のみなのでスキップ）
if (sectionType === "campaign") {
  // 施策一覧はK列から指標のみ、1列目なし
} else if (sectionType === "monthly") {
  colFormats.push({ type: "DATE", pattern: 'yyyy"/"m' });
} else {
  colFormats.push(null); // ラベル名はテキスト、数値書式不要
}

for (const metric of config.metrics) {
  // 指標列のフォーマット
  if (metric.name.includes("金額")) {
    colFormats.push({ type: "CURRENCY", pattern: '"¥"#,##0' });
  } else {
    colFormats.push({ type: "NUMBER", pattern: "#,##0" });
  }
  // 率列がある場合
  if (metric.rateOf) {
    colFormats.push({ type: "PERCENT", pattern: "0.00%" });
  }
}

const requests = [];

// 数値書式を列ごとに設定（ヘッダー行を除くデータ行のみ）
const dataStartIdx = startRow; // 0-based = startRow (ヘッダーの次の行)
const dataEndIdx = endRow; // 0-based = endRow (inclusive → exclusive として +0 は endRow が 1-based なのでそのまま)

colFormats.forEach((fmt, i) => {
  if (!fmt) return;
  const colIdx = SUMMARY_START + i;
  requests.push({
    repeatCell: {
      range: {
        sheetId: sid,
        startRowIndex: dataStartIdx,
        endRowIndex: dataEndIdx,
        startColumnIndex: colIdx,
        endColumnIndex: colIdx + 1,
      },
      cell: { userEnteredFormat: { numberFormat: fmt } },
      fields: "userEnteredFormat.numberFormat",
    },
  });
});

// 罫線を全列（ヘッダー含む）に設定
requests.push({
  repeatCell: {
    range: {
      sheetId: sid,
      startRowIndex: startRow - 1, // ヘッダー行も含む (0-based)
      endRowIndex: dataEndIdx,
      startColumnIndex: SUMMARY_START,
      endColumnIndex: SUMMARY_START + colFormats.length,
    },
    cell: { userEnteredFormat: { borders: BORDERS } },
    fields: "userEnteredFormat.borders",
  },
});

// ヘッダー行の背景色＋中央揃えを全列に設定
const HEADER_BG = { red: 0.9529412, green: 0.9529412, blue: 0.9529412 };
requests.push({
  repeatCell: {
    range: {
      sheetId: sid,
      startRowIndex: startRow - 1,
      endRowIndex: startRow,
      startColumnIndex: SUMMARY_START,
      endColumnIndex: SUMMARY_START + colFormats.length,
    },
    cell: {
      userEnteredFormat: {
        backgroundColor: HEADER_BG,
        horizontalAlignment: "CENTER",
        textFormat: { bold: true },
      },
    },
    fields: "userEnteredFormat.backgroundColor,userEnteredFormat.horizontalAlignment,userEnteredFormat.textFormat.bold",
  },
});

fs.writeFileSync(outFile, JSON.stringify({ requests }));
