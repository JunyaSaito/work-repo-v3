\# 作業リポジトリのルール



\## このリポジトリについて

日常業務の半自動化タスクをまとめたモノレポです。



\## スプレッドシート作成について

\- gwsコマンドを使ってGoogleスプレッドシートに書き込む

\- 書き込み前に対象シートのIDと構造を確認すること

\- 認証済みアカウント: junya.saito.titech@gmail.com



\## 成果レポート自動生成エージェント

ユーザーから「成果レポートを作って」「〇〇期間のレポートを作成して」と依頼されたら、以下の手順を自律的に実行すること。

\### 対象スプレッドシート

\- ID: `14KrcDYsm_9miLUfu4GrcoaKIHo6TpB70NtzTabO8d5Y`
\- 配信実績シート: 施策ごとの生データ。ヘッダーのパターンは複数ある:
  - パターン1: 施策名|配信日|配信数|開封数|クリック数|CV数|CV金額
  - パターン2: 施策名|配信日|配信数|開封数|クリック数|直接CV数|間接CV数|直接CV金額|間接CV金額
  - パターン3: 施策名|配信日|配信数|開封数|クリック数|合計CV数|直接CV数|間接CV数|合計CV金額|直接CV金額|間接CV金額
\- テンプレシート: 対象スプレッドシート内の「テンプレ」という名前のシート（write_report.sh が自動でsheetIdを取得する）

\### 使用するスプレッドシートの判断

ユーザーがURLを提示した場合は、そのURLからスプレッドシートIDを抽出して使う。

```
https://docs.google.com/spreadsheets/d/{スプレッドシートID}/edit...
                                         ^^^^^^^^^^^^^^^^^^^^^^^^
                                         この部分がID
```

URLが提示されない場合はデフォルトID（`14KrcDYsm_9miLUfu4GrcoaKIHo6TpB70NtzTabO8d5Y`）を使う。

\### 実行手順

1. **列構成を検出し、サマリ列をユーザーに提案する**

   **1-1. A列と1行目を読み取る**
   ```bash
   # 施策名一覧（A列全体）
   gws sheets spreadsheets values get \
     --params '{"spreadsheetId": "SHEET_ID", "range": "配信実績!A:A"}'

   # 1行目（ヘッダー行）を読み取る
   gws sheets spreadsheets values get \
     --params '{"spreadsheetId": "SHEET_ID", "range": "配信実績!1:1"}'
   ```

   **1-2. detect_columns.js でサマリ列構成を自動検出する**
   ```bash
   # ヘッダーのgws出力JSONをファイルに保存してから実行
   node tasks/成果レポート自動化/detect_columns.js HEADER_JSON_FILE > config.json
   ```
   - 出力される config.json に、各指標のソース列・ラベル列・サマリヘッダー等が含まれる
   - config.json の `summaryHeader` をユーザーに提示し、このサマリ列構成でよいか確認する
   - ユーザーが「合計CVは不要」等のフィードバックをした場合は、config.json の metrics から該当指標を削除して再生成する
   - 確定した config.json を `tasks/成果レポート自動化/columns_config.json` に保存する

   **1-3. ラベル候補を提案してユーザーに確認する**
   - A列のユニークな施策名を抽出し、施策名に含まれるキーワードからラベルを推定して提案する
   - ユーザーのフィードバックを受けてラベルを確定する
   - 確定したラベル一覧を config.json の `labels` 配列に保存する（`gen_label_summary.js` と `write_report.sh`/`write_label_summary.sh` がここからラベル数を読み取る）

   **1-4. ラベルをシートに書き込む**
   - config.json の `labelCol` に示された列（パターンによりH, J, L等）にラベルを書き込む
   - 確定したラベルを施策名との対応表にまとめ、各行のA列施策名に対応するラベルを書き込む
   - 日本語を含む gws コマンドは必ず .sh ファイルに書き出してから `bash` で実行すること

2. **レポートシートを作成する**（期間・シートID・config.jsonを引数で渡す）
   ```bash
   bash tasks/成果レポート自動化/write_report.sh "開始日" "終了日" "スプレッドシートID" "tasks/成果レポート自動化/columns_config.json"
   ```

3. **ラベル別サマリをシートに書き込む**
   ```bash
   bash tasks/成果レポート自動化/write_label_summary.sh "開始日" "終了日" "スプレッドシートID" "tasks/成果レポート自動化/columns_config.json"
   ```
   - テンプレシートの固定位置にラベル別サマリを配置する
   - write_report.sh がラベル数 > テンプレ行数の場合に最初のラベルデータ行の下へ行挿入済み（inheritFromBefore:true）のため、追加挿入は不要
   - 列構成は config.json に従い動的に決定される（F列から開始、列数はパターンにより異なる）
   - 集計にはB列（配信日）の `>=開始日 AND <=終了日` と config.json の `labelCol`（ラベル列）のSUMIFSを使う

4. **施策一覧サマリをシートに書き込む**
   ```bash
   bash tasks/成果レポート自動化/write_campaign_summary.sh "開始日" "終了日" "スプレッドシートID" "tasks/成果レポート自動化/columns_config.json"
   ```
   - テンプレの施策一覧構造（タイトル・ヘッダー・5データ行）を活かし、不足分のみ最初のデータ行の下に行挿入（inheritFromBefore:true）
   - タイトル行のG列に最終月（YYYY年M月）を書き込み
   - ヘッダー行はK列以降に指標ヘッダーを書き込み（施策名ヘッダーは不要）
   - F列に施策名（F〜J列に展開）、K列以降にSUMIFS数式をチャンク分割で書き込み
   - F〜J列（施策名エリア）はテンプレの書式をcopyPaste(PASTE_FORMAT)でコピー
   - K列以降（指標列）はgen_formats.jsで動的にフォーマット適用（列数はconfigから自動決定）
   - 最終データ行と示唆セクションの間に空白行を挿入
   - 出力される `INSIGHT_CELL` を示唆書き込み先として使用する

5. **示唆を生成する**
   write_report.sh が出力する `RAW_DATA`（年月別サマリ）と write_label_summary.sh が出力する `LABEL_RAW_DATA`（ラベル別サマリ）の両方を分析し、マーケターへの示唆を3〜4点、「・」始まりの箇条書きで作成する。
   - 年月別サマリ: 月ごとの配信数・開封率・クリック率・CV数・CV金額のトレンド
   - ラベル別サマリ: 施策カテゴリ（全体メルマガ・購入レコメンド・かご落ち・閲覧落ち）ごとのパフォーマンス比較

6. **示唆をシートに書き込む**
   生成した示唆を `tasks/成果レポート自動化/` 配下に一時的な .sh ファイルを作り、gws で対象シートに1行1個で書き込む。
   - 書き込み先: `INSIGHT_CELL`（スクリプトが出力する値）を起点に、示唆の数だけ行を使う（例: 示唆4点なら `C25:C28`）
   - valuesは `[["示唆1"],["示唆2"],["示唆3"],["示唆4"]]` の形式で渡す
   - 日本語を含むgwsコマンドは必ず .sh ファイルに書き出してから `bash` で実行すること（インラインだとエンコードエラーになる）

\### 注意事項

\- スクリプトはテンプレシートを複製してシートを作成するため、同名シートが既に存在するとエラーになる。その場合は既存シートを削除してから再実行する。
\- `claude -p` コマンドはClaude Codeセッション内では使用不可。示唆生成は必ずClaude Code自身が行う。
\- フォーマット（数値カンマ・%・¥）はテンプレの書式が引き継がれる。データ行が4行以上の場合はスクリプトが自動でフォーマットをコピーする。

---

\## gws sheets コマンド早見表

\### 値の読み取り

```bash
# 生の数値で読む（集計結果取得に使う）
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "ID", "range": "シート!A1:Z10", "valueRenderOption": "UNFORMATTED_VALUE"}'

# 表示フォーマット済みで読む（確認用）
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "ID", "range": "シート!A1:Z10", "valueRenderOption": "FORMATTED_VALUE"}'

# 数式として読む
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "ID", "range": "シート!A1:Z10", "valueRenderOption": "FORMULA"}'
```

\### 値の書き込み

```bash
# USER_ENTERED: 数式・文字列・日付を自然に解釈（通常はこれを使う）
gws sheets spreadsheets values update \
  --params '{"spreadsheetId": "ID", "range": "シート!A1", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["セルA1", "セルB1"], ["セルA2", "セルB2"]]}'

# RAW: 文字列として書き込む（数式を文字列として保存したい場合）
# valueInputOption: "RAW"
```

\### 複数範囲を一括書き込み（batchUpdate）

```bash
gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId": "ID"}' \
  --json '{
    "valueInputOption": "USER_ENTERED",
    "data": [
      {"range": "シート!A20", "values": [["2026/01", ...]]},
      {"range": "シート!C4",  "values": [["配信対象期間：..."]]}
    ]
  }'
```

\### 範囲クリア

```bash
gws sheets spreadsheets values clear \
  --params '{"spreadsheetId": "ID", "range": "シート!A20:I30"}'
```

---

\## テンプレシートのセル位置

| セル | 内容 |
|------|------|
| B2 | 「前提」ラベル |
| C4 | 配信対象期間テキスト |
| B7 | 「分析結果」ラベル |
| E9 | 「メール施策の成果」ラベル |
| F11:I11 | KPIヘッダー行（施策数(月間), CV数(月間), CV金額(月間), ROAS） |
| F12:I12 | KPIデータ行 |
| E15 | 「年月別サマリ」ラベル |
| F17:{動的}17 | 年月別ヘッダー行（列数はconfig.jsonのsummaryColsに従う） |
| F18:{動的}〜 | 年月別データ行（月数分、テンプレデフォルト3行） |
| E23 | 「ラベル別サマリ」ラベル |
| F25:{動的}25 | ラベル別ヘッダー行 |
| F26:{動的}〜 | ラベル別データ行（テンプレデフォルト5行） |
| E31 | 「施策一覧サマリ」ラベル（※テンプレでは行30の直後、空白行なし。生成時にLABEL_LIST_GAP=2行を挿入） |
| G31 | 施策一覧の対象期間（YYYY年M月） |
| F33 | 施策一覧ヘッダー行（F:施策名（F〜Jに展開）、K〜:成果指標。ヘッダーはスクリプトが書き込み） |
| F34:{動的}〜 | 施策一覧データ行（テンプレデフォルト5行） |
| B39 | 「示唆」ラベル |
| C41 | 示唆本文（起点。実際の行はINSIGHT_CELLに従う） |

\### 生成時の行挿入による位置シフト

テンプレの固定位置は、以下の行挿入により下方にシフトする:
- **年月別サマリ**: 月数 > 3 の場合、行18の下に不足分を挿入（以降すべてシフト）
- **ラベル別サマリ**: ラベル数 > 5 の場合、行26の下に不足分を挿入（inheritFromBefore:true）
- **ラベル/施策間空白**: LABEL_LIST_GAP=2行をラベル別サマリ最終行の下に挿入
- **示唆前セパレーター**: 施策一覧最終行と示唆セクションの間に1行挿入
- **施策一覧サマリ**: 施策数 > 5 の場合、最初のデータ行の下に不足分を挿入（inheritFromBefore:true）

各スクリプトはこれらのシフトを自動計算し、`INSIGHT_CELL`（示唆書き込み先）を出力する。

---

\## ハマりどころ・注意点

\- `valueRenderOption` を省略すると `FORMATTED_VALUE`（文字列）が返る。数値計算には `UNFORMATTED_VALUE` を使う。
\- `valueInputOption` を省略すると `RAW` になり、数式が文字列として保存される。数式を書くときは必ず `USER_ENTERED` を指定。
\- Sheets の再計算は書き込み直後でも完了している場合が多いが、SUMIFS が重い場合は `sleep 2` してから読み取るとよい。
\- JSON の `--params` 内でシート名が日本語の場合はそのまま渡せる（URLエンコード不要）。
\- 日本語を含む gws コマンドはインラインだとエンコードエラーになるため、必ず .sh ファイルに書き出してから `bash` で実行する。

