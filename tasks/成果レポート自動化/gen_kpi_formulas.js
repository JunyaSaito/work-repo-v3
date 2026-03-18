// gen_kpi_formulas.js
// 「メール施策の成果」セクションの数式を生成
// Usage: node gen_kpi_formulas.js CONFIG_FILE START_DATE END_DATE N_MONTHS
// 出力: {"values": [[施策数(月間), CV数(月間), CV金額(月間), ROAS]]}
const fs = require("fs");
const [, , configFile, startDate, endDate, nMonthsStr] = process.argv;
const config = JSON.parse(fs.readFileSync(configFile, "utf-8"));
const nMonths = parseInt(nMonthsStr);

const [sy, sm, sd] = startDate.split("/").map(Number);
const [ey, em, ed] = endDate.split("/").map(Number);
const ds = `DATE(${sy},${sm},${sd})`;
const de = `DATE(${ey},${em},${ed})`;
const dateFilter = `'配信実績'!$B$2:$B,">="&${ds},'配信実績'!$B$2:$B,"<="&${de}`;

// 施策数(月間): 期間内のユニーク施策数 / 月数
const f_count = `=COUNTA(UNIQUE(FILTER('配信実績'!$A$2:$A,'配信実績'!$B$2:$B>=${ds},'配信実績'!$B$2:$B<=${de})))/${nMonths}`;

// CV数(月間): CV系指標の合計 / 月数
const cvMetrics = config.metrics.filter(
  (m) => m.name.includes("CV数")
);
const cvSumifs = cvMetrics
  .map((m) => `SUMIFS('配信実績'!$${m.srcCol}$2:$${m.srcCol},${dateFilter})`)
  .join("+");
const f_cv = `=(${cvSumifs})/${nMonths}`;

// CV金額(月間): CV金額系指標の合計 / 月数
const amountMetrics = config.metrics.filter(
  (m) => m.name.includes("CV金額")
);
const amountSumifs = amountMetrics
  .map((m) => `SUMIFS('配信実績'!$${m.srcCol}$2:$${m.srcCol},${dateFilter})`)
  .join("+");
const f_amount = `=(${amountSumifs})/${nMonths}`;

// ROAS: CV金額合計 / 配信コスト（コストデータなし → 空文字）
const f_roas = "";

console.log(JSON.stringify({ values: [[f_count, f_cv, f_amount, f_roas]] }));
