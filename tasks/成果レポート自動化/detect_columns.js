// detect_columns.js
// Usage: node detect_columns.js HEADER_JSON_FILE [DATE_HEADER_JSON_FILE]
// Output: column config JSON to stdout
//
// HEADER_JSON_FILE:      gws sheets values get の出力JSON（配信実績!1:1）
// DATE_HEADER_JSON_FILE: 日付列ヘッダーが別ファイルの場合（省略可）
//
// 対応パターン（列名の別名も自動正規化）:
//   - 施策名列: 施策名, 配信設定名, メールコンテンツ名, メール件名, キャンペーン名, 件名
//   - 日付列:   配信年月日, 配信日, 日付, 送信日, 実施日
//   - 指標列:   直接コンバージョン数→直接CV数, 間接受注金額→間接CV金額, など

const fs = require("fs");
const { colLetter } = require("./utils");

const headerFile = process.argv[2];
const raw = JSON.parse(fs.readFileSync(headerFile, "utf-8"));
const header = raw.values[0];

// ── 施策名列・日付列の自動検出 ────────────────────────────
const CAMPAIGN_KEYWORDS = ["施策名", "配信設定名", "メールコンテンツ名", "メール件名", "キャンペーン名", "件名"];
const DATE_KEYWORDS     = ["配信年月日", "配信日", "日付", "送信日", "実施日"];

let campaignColIndex = -1;
let dateColIndex = -1;
for (let i = 0; i < header.length; i++) {
  if (campaignColIndex === -1 && CAMPAIGN_KEYWORDS.includes(header[i])) campaignColIndex = i;
  if (dateColIndex     === -1 && DATE_KEYWORDS.includes(header[i]))     dateColIndex     = i;
}
// 見つからない場合のフォールバック（従来通り A列=施策名, B列=日付）
if (campaignColIndex === -1) campaignColIndex = 0;
if (dateColIndex     === -1) dateColIndex     = 1;

const campaignCol = colLetter(campaignColIndex);
const dateCol     = colLetter(dateColIndex);

// ── 列名の別名マッピング（元の列名 → 正規化後のサマリ表示名） ──
const ALIASES = {
  // コンバージョン系
  "直接コンバージョン数": "直接CV数",
  "間接コンバージョン数": "間接CV数",
  "合計コンバージョン数": "合計CV数",
  "コンバージョン数":     "CV数",
  "CV":                  "CV数",
  // 受注・売上系
  "直接受注金額":         "直接CV金額",
  "間接受注金額":         "間接CV金額",
  "合計受注金額":         "合計CV金額",
  "受注金額":            "CV金額",
  "売上金額":            "CV金額",
  "直接売上金額":         "直接CV金額",
  "間接売上金額":         "間接CV金額",
  // 受注数系
  "直接受注数":           "直接CV数",
  "間接受注数":           "間接CV数",
  "受注数":              "CV数",
};

// ── 指標列の検出（rateOf: 率の分母となる指標の summaryName） ──
const RATE_MAP = {
  配信数:    null,
  開封数:    "配信数",
  クリック数: "開封数",
  CV数:      "クリック数",
  合計CV数:  "クリック数",
  直接CV数:  "クリック数",
  間接CV数:  "クリック数",
  CV金額:    null,
  合計CV金額: null,
  直接CV金額: null,
  間接CV金額: null,
};

const metrics = [];
const seenSummaryNames = new Set();
for (let i = 0; i < header.length; i++) {
  const h = header[i];
  const summaryName = ALIASES[h] || h;  // 別名があれば正規化、なければそのまま
  if (summaryName in RATE_MAP && !seenSummaryNames.has(summaryName)) {
    seenSummaryNames.add(summaryName);
    metrics.push({
      name: h,                          // 元の列名（SUMIFS の srcCol 参照用）
      summaryName,                      // サマリ表示名（ヘッダー・rateOf 参照用）
      srcCol: colLetter(i),
      rateOf: RATE_MAP[summaryName],
    });
  }
}

// ── ラベル列 = ヘッダーの次の空き列（ただし dateCol の次以降に配置） ──
const lastUsedIndex = Math.max(header.length - 1, dateColIndex);
const labelColIndex = lastUsedIndex + 1;
const labelCol = colLetter(labelColIndex);

// ── サマリヘッダーを生成 ─────────────────────────────────
const summaryHeader = ["年月"];
for (const m of metrics) {
  summaryHeader.push(m.summaryName);
  if (m.rateOf) {
    summaryHeader.push(m.summaryName.replace(/数$/, "率"));
  }
}

const SUMMARY_START = 5; // F列 = index 5
const summaryCols = summaryHeader.length;
const summaryEndCol = colLetter(SUMMARY_START + summaryCols - 1);
const summaryEndColIndex = SUMMARY_START + summaryCols; // exclusive (for batchUpdate)

const config = {
  campaignCol,
  dateCol,
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
