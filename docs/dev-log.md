# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
実装・設計判断の詳細は `docs/` 配下の該当文書(`mvp-design.md`, `development.md`)を
参照し、本ファイルは要約に留める。

---

## 2026-07-08: predict_glm() MVP 第1段階(数値・gaussian・R不使用)

### Summary

- `fbsql.predict_glm(relation, model)` を **PL/pgSQL で実装(R 不使用)**。係数
  リレーション + metadata だけから `intercept + Σ coef·x` を動的 SQL で計算し、
  リレーションがモデル表現として完結していることを実証
- 出力形式は **`SETOF record` + 呼び出し側の列定義リスト**(第一候補)を採用。
  入力全列 + `<response>_predicted` を返し「同じ粒度のリレーション」を維持。
  第二候補(row_id固定)は入力列を失い意味論を崩すため不採用 — 判断理由を
  mvp-design.md に明記
- 行順序非依存: 係数は term 名で照合し、metadata.coef_terms と行数・完全性を検証
- NULL 説明変数の行は予測値 NULL(R の predict() の NA と一致)
- 動的 SQL は %I / %L でクォート(細工された model リレーションからの注入も防止)
- PL/pgSQL のためエラーは1行目から `predict_glm:` で始まる(PL/R のような
  ラッパー行なし)

### Changed Files

- `sql/fbsql--0.1.0.sql`: `fbsql.predict_glm()` 追加(PL/pgSQL、検証6種:
  引数・metadata有無・meta_version・family・data_classes・係数完全性)
- `test/sql/predict_glm_numeric.sql` / expected: 新規(fit→predict の一連 +
  NULL行 + binomial/factor モデルへの明瞭なエラー)
- `Makefile`: REGRESS に predict_glm_numeric 追加
- `scripts/parity_reference.R`: predict 参照セクション追加
- `README.md`: predict_glm の現状(numeric gaussian MVP、SETOF record 記法)を明記
- `docs/mvp-design.md`: predict_glm 第1段階の設計・出力形式の判断を追記
- `TODO.md`: 第1段階完了、第2段階(binomial)・第3段階(factor)に分割

### Validation

- t_train(5行、y = 1 + x)→ t_new の予測: id=1(x=1.5)→ **2.5**、id=2(x=3.5)→
  **4.5**、id=3(x=NULL)→ **NULL** — R の `predict(glm(...), newdata)` と一致
- binomial モデル → `predict_glm: family 'binomial' is not supported yet`
- factor モデル → `predict_glm: only numeric predictors are supported yet`
- `make installcheck` → **All 8 tests passed**(既存7 + predict_glm_numeric)
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- SETOF record のため呼び出し側に列定義リストが必須。記述を不要にする手段
  (C 実装・ビュー生成等)は将来課題として論文 Discussion で扱う
- 予測対象 relation に必要列がない場合は PostgreSQL ネイティブの
  「column does not exist」エラーになる(明瞭なので MVP はそのまま)

### Next Step

- `predict_glm()` 第2段階: binomial 対応(logit の逆リンク `1/(1+exp(-lp))` を
  SQL 式に追加、出力は確率)

Commit: `Add numeric predict_glm MVP`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: fit_glm() に metadata jsonb 列を実装(17列目)

### Summary

- 確定済みスキーマ(meta_version 1)通りに `metadata jsonb` 列を実装。全係数行に
  同一の JSONB が入る(DISTINCT で1行になることをテストで検証)
- フィールド: meta_version / response / term_labels / intercept / data_classes /
  xlevels / contrasts / coef_terms。すべて R の fit オブジェクトから取得
  (`terms(fit)` の各属性、`fit$xlevels`、`fit$contrasts`、`names(coef(fit))`)
- PL/R 実行環境に jsonlite がないため、JSON は base R で手組み(エスケープ関数付き)。
  jsonb がキー順を正規化するため出力は決定的で pg_regress 安定
- 数値のみモデルでは xlevels / contrasts が空オブジェクト `{}` になることを検証
- **既存6テストは expected 無変更で通過**(全テストが明示的列リストで SELECT している
  ため。設計時の予測通り)

### Changed Files

- `sql/fbsql--0.1.0.sql`: `fbsql.glm_fit` に `metadata jsonb` 追加、`fit_glm()` に
  JSON 構築ロジック(esc / jstr / jarr / jobj ヘルパー + terms 属性の収集)
- `test/sql/fit_glm_metadata.sql` / expected: 新規(jsonb_pretty 全体、`->`/`->>`
  個別フィールド、数値のみモデルの空オブジェクト、計4クエリ)
- `Makefile`: REGRESS に fit_glm_metadata 追加
- `README.md`: 出力列に metadata を追記、predict_glm の記述を「fit側は準備完了」に更新
- `docs/mvp-design.md`: §3・§4 を実装済みに更新
- `TODO.md`: metadata タスク完了化

### Validation

- factor 込みモデル(y ~ x1 + gender)で全フィールドが設計通りの値:
  response=y, term_labels=["x1","gender"], coef_terms=["(Intercept)","x1","genderM",
  "genderOther"], xlevels={"gender":["F","M","Other"]}, contrasts=contr.treatment,
  data_classes={y:numeric, x1:numeric, gender:factor}
- `make installcheck` → **All 7 tests passed**(既存6 + fit_glm_metadata)
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- metadata の JSON 手組みは将来フィールドが増えると煩雑になる。R パッケージ追加
  (jsonlite)はイメージ肥大とのトレードオフなので、必要になった時点で判断

### Next Step

- `predict_glm()` MVP の実装(数値のみ → factor 対応の順)。入力: モデル relation +
  予測対象 relation、出力: `<response>_predicted` 列を持つ relation

Commit: `Add fit_glm metadata column`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: predict_glm() に向けた metadata 設計の確定(文書のみ)

### Summary

- `fit_glm()` 出力への **`metadata jsonb` 列(17列目)追加を正式決定**(実装は次回)
- JSONB スキーマ(meta_version 1)を確定: response / term_labels / intercept /
  data_classes / xlevels / contrasts / coef_terms の7フィールド + バージョン
- フラット列(family, link, formula, n_obs 等)と重複する情報は metadata に持たない
  (単一情報源の原則。例外は整合性チェック用の coef_terms)
- novel factor level ポリシーは metadata ではなく `predict_glm(on_new_levels =>
  'error'|'na')` の引数として設計(既定 'error'、fbrglm 踏襲)— 未決事項を解消
- 既存 pg_regress への影響なしを確認(全テストが明示的列リストで SELECT しているため、
  列追加で expected は変わらない)
- コード・テスト・expected の変更は一切なし(設計文書のみ)

### Changed Files

- `docs/mvp-design.md`: §4 の「推奨」を「確定した設計」に置換(スキーマ表、
  各フィールドの R での由来と predict での役割、テスト影響、トレードオフの明文化、
  次回実装の作業範囲)。§3 に17列目追加の予告
- `TODO.md`: metadata 形式と novel level ポリシーの未決事項2件を解決済み化、
  「MVP 後」を実装順に再構成(metadata 列実装 → predict_glm MVP)
- `README.md`: predict_glm 未実装の記述を「fit側設計は確定済み」に更新

### Validation

- 文書のみの変更のため実行検証なし(git status clean を確認)

### Known Issues

- JSONB 内部スキーマは事実上 API の一部になる — meta_version で管理し、変更時は
  バージョンを上げる規律が必要(論文にもスキーマを明記予定)

### Next Step

- `fbsql.glm_fit` に `metadata` 列を追加し、`fit_glm()` で全フィールドを一括実装 +
  `fit_glm_metadata` テスト新設(1回分の実装作業。スキーマ確定済みなので迷いなし)

Commit: `Document fit_glm metadata design`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: fit_glm() MVP の品質固め(エラー処理・テスト整理・文書同期)

### Summary

- エラー処理を強化: formula parse 失敗、formula が参照する列の不存在(利用可能列の
  一覧付き)、R の fitting エラーを `fit_glm:` 接頭辞付きの明瞭なメッセージ化
- **重要な発見**: `pg.spi.exec` を tryCatch で捕捉してから `pg.throwerror` を呼ぶと
  バックエンドがクラッシュする(SPI エラーで abort したトランザクション上で R ハンドラ
  からエラーを投げるため)。壊れた relation SQL は PostgreSQL ネイティブエラーを
  そのまま伝播させる方式に確定し、設計判断としてコード・設計書に明記
- エラーテストを `fit_glm_errors.sql` に集約(6ケース)。gaussian テストからエラー
  ケースを移動
- README を現在の実装に同期(fbsql.fit_glm が正式API、対応family、predict_glm 未実装、
  モデルオブジェクト非露出、出力列一覧)
- MVP 全タスク完了を TODO.md に明記

### Changed Files

- `sql/fbsql--0.1.0.sql`: formula parse / 列存在チェック / glm エラーの tryCatch 化、
  pg.spi.exec を tryCatch しない理由のコメント
- `test/sql/fit_glm_errors.sql` / expected: 新規(6エラーケース)
- `test/sql/fit_glm_gaussian.sql` / expected: エラーケースを errors テストへ移動
- `Makefile`: REGRESS に fit_glm_errors 追加
- `README.md`: 実装と同期した全面改訂
- `docs/mvp-design.md`: エラー処理の決定事項を実装確定版に更新(クラッシュ回避の設計判断含む)
- `TODO.md`: MVP 完了の明記、PL/R エラー1行目整形の調査項目を追加

### Validation

- エラー6ケースすべて確認: poisson(未対応family)/ 'not a formula'(parse失敗)/
  missing_col(列不存在、available: y, x 付き)/ no_such_table(PGネイティブエラー伝播)/
  0行 relation / binomial に範囲外応答(R メッセージ保持: 'y values must be 0 <= y <= 1')
- クラッシュ再現 → 修正 → 全ケースでクラッシュなしを確認
- `make installcheck` → **All 6 tests passed**(version / gaussian / binomial / nulls /
  factor / errors)
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- PL/R エラーの1行目は常に `R interpreter expression evaluation error` で、本体は
  DETAIL 行に出る(TODO に調査項目として記録、優先度低)
- 壊れた relation SQL のエラーは pg.spi.exec 由来の2行 DETAIL になる(内容は明瞭)

### Next Step

- `predict_glm()` の metadata 設計確定(JSONB 案A の具体スキーマ:
  xlevels / contrasts / terms / 列型情報)— 実装前に設計文書の更新として1回分

Commit: `Harden fit_glm MVP error handling`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: fit_glm() の factor(カテゴリカル説明変数)対応

### Summary

- 文字列列を含む relation で `fit_glm()` が動くようにした(`y ~ gender`)
- PL/R は text 列を character で渡し R >= 4 は自動 factor 化しないため、`fit_glm()` 内で
  **明示的に** `factor()` 変換する方針を採用(levels ソート順・第1水準参照・treatment
  contrast = R の `glm()` 既定と一致)
- term 名(`genderM`, `genderOther`)・係数・SE・統計量・p値すべて R と丸め一致
- テストの `ORDER BY term` に `COLLATE "C"` を付与(DB ロケール依存の行順を排除)
- MVP タスク完了: これで gaussian / binomial / NULL / factor + CI が揃った

### Changed Files

- `sql/fbsql--0.1.0.sql`: character 列の明示的 factor 変換を追加(設計判断コメント付き)
- `test/sql/fit_glm_factor.sql` / expected: 新規(6行・3水準の t_factor)
- `Makefile`: REGRESS に fit_glm_factor 追加
- `scripts/parity_reference.R`: t_factor セクション追加
- `docs/mvp-design.md`: factor 処理の決定事項を §2 に追加、§4 に「fit の factor 規約が
  predict metadata(xlevels 等)の必要性を裏付けた」ことを追記
- `TODO.md`: t_factor と CI(installcheck)タスクを完了化

### Validation

- fixture: 6行・gender 3水準('F', 'M', 'Other'、各2行)
- PostgreSQL: `(Intercept) 1.25±0.2121`, `genderM 1.00±0.30 (p=0.0446)`,
  `genderOther 1.65±0.30 (p=0.0118)`, AIC 6.4207 — **R と全16列一致**
- 参照水準は R の既定通りソート第1水準の 'F'(係数表に現れない)
- `make installcheck` → **All 5 tests passed**
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- 参照水準はロケール依存のソートに従う(コンテナ環境では en_US.utf8 / R側 C で
  ASCII 英大文字のみなら差は出ない)。多バイト水準名を使う場合の挙動は未検証
- interactions(`y ~ x * gender`)・contrast 切り替え・novel level は未対応(スコープ外)

### Next Step

- MVP(fit_glm)完了につき、`predict_glm()` の metadata 設計確定(JSONB 案A の
  具体スキーマ: xlevels / contrasts / terms / 型情報)に着手
- あわせて gaussian + factor 以外の組み合わせ(binomial + factor)のテスト拡充を検討

Commit: `Add factor predictor support to fit_glm`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: fit_glm() の binomial 対応と NULL 処理テスト

### Summary

- `fbsql.fit_glm()` に `family = 'binomial'`(logit リンク)を追加。gaussian と同じ
  16列の出力 relation を維持し、binomial では `statistic` が z 値になる
- boolean 応答(Running Example の `churn_flag` 相当)が 0/1 整数と同じ結果になることを検証
- `t_nulls` テストを追加: t_gaussian の12行 + NULL入り3行で、Complete Case Analysis が
  ちょうど3行を除外し(n_obs=15, n_used=12, n_dropped=3)、係数が gaussian テストと
  一致することを回帰テスト化
- R の `stats::glm()` との一致を binomial / nulls とも全列(4桁丸め)で確認
- 未対応 family のエラーテストは `poisson` に変更(binomial が対応済みになったため)

### Changed Files

- `sql/fbsql--0.1.0.sql`: family 検証を supported ベクタ化、`switch` で family オブジェクト
  解決、`link` は `fam$link` から取得
- `test/sql/fit_glm_binomial.sql` / expected: 新規(フル16列 + boolean 応答の2ケース)
- `test/sql/fit_glm_nulls.sql` / expected: 新規(Complete Case 検証)
- `test/sql/fit_glm_gaussian.sql` / expected: エラーケースを poisson に変更、
  エラーメッセージの supported families 表記更新
- `Makefile`: REGRESS に fit_glm_binomial, fit_glm_nulls を追加
- `scripts/parity_reference.R`: family 汎用化、t_binomial / t_nulls セクション追加
- `TODO.md`: binomial / NULL テストのタスクを完了化

### Validation

- binomial fixture(手書き12行、0/1 が x 範囲で交互に出現し完全分離なし、収束警告なし):
  `(Intercept) −1.0172±1.2677 (z=−0.8023, p=0.4224)`, `x 0.6318±0.6925 (z=0.9124,
  p=0.3616)`, AIC 19.7413, deviance 15.7413, null_deviance 16.6355 — **R と全列一致**
- boolean 応答 → 0/1 整数と同一の係数・SE
- t_nulls → n_obs=15 / n_used=12 / n_dropped=3、係数は完全ケース12行の R と一致
- `make installcheck` → **All 4 tests passed**(version / gaussian / binomial / nulls)
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- 非 canonical link(probit 等)は未対応(TODO 済み)
- factor 変数のテスト(`t_factor`)が MVP タスクの残り1件
- ユーザー提示のエラーケース「gaussian データ + family='binomial'」は、binomial 対応後は
  「y values must be 0 <= y <= 1」という R 由来のエラーになる(仕様通りだがメッセージは
  R のまま)

### Next Step

- `t_factor` テスト(factor 変数、term 名と参照水準が R の既定と一致すること)
- その後 MVP 残タスクの CI 拡充を経て `predict_glm()` の設計確定へ

Commit: `Add binomial fit_glm support and NULL handling test`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: gaussian fit_glm() MVP実装

### Summary

- `fbsql.fit_glm(relation, formula, family)` を PL/R で実装(gaussian のみ、内部で `stats::glm()`)
- 出力は設計書通りの16列リレーション(`fbsql.glm_fit` 複合型): term粒度7列 + モデル粒度9列
- R の `stats::glm()` と**全16列が4桁丸めで完全一致**することを確認(parity_reference.R)
- Complete Case Analysis(NULL行除外)と n_obs / n_used / n_dropped の計数が正しく動作
- 未対応 family は `pg.throwerror` で明示的にエラー
- 名前空間方針を確定: 正式APIは `fbsql.fit_glm()`、`public.fit_glm()` は作らない
  (README・論文では `SET search_path TO fbsql, public;` で短縮表記)

### Changed Files

- `sql/fbsql--0.1.0.sql`: `fbsql.glm_fit` 複合型 + `fbsql.fit_glm()`(PL/R)を追加
- `fbsql.control`: `requires = 'plr'` を追加
- `test/sql/fit_glm_gaussian.sql` / `test/expected/fit_glm_gaussian.out`: 新規テスト
  (フル16列・family省略時・未対応familyエラーの3ケース、4桁丸め、ORDER BY term)
- `test/sql/fbsql_version.sql` / expected: `CREATE EXTENSION fbsql CASCADE` に変更(plr依存)
- `Makefile`: REGRESS に fit_glm_gaussian 追加
- `scripts/parity_reference.R`: 同一データで R 参照値を印字(新規)
- `docs/mvp-design.md` / `TODO.md` / `CLAUDE.md` / `README.md`: 名前空間決定の反映、タスク完了化

### Validation

- fixture: 残差入り手書き12行(y = 2 + 1.5·x1 − 0.5·x2 + 手書き残差。完全一致
  データは SE/p値 が数値不安定になるため意図的に残差を入れた)
- PostgreSQL: `(Intercept) 2.1078, x1 1.4892, x2 −0.5101`、SE/statistic/CI/AIC 含め
  R の出力(Rscript scripts/parity_reference.R)と**全列一致**
- NULL 混入 6 行(y NULL 1行 + x NULL 1行)→ n_obs=6, n_used=4, n_dropped=2、
  係数は完全ケース4行での R と一致
- `make installcheck`(pg_regress)→ **All 2 tests passed**
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- `pg.throwerror` のエラーは `ERROR: R interpreter expression evaluation error` +
  DETAIL にメッセージ、という形式(PL/R の仕様)。メッセージ自体は明瞭だが、
  第一行をきれいにする方法は今後の検討事項
- rank deficiency(線形従属列)は未対応(gaussian MVP では扱わない。将来 fbrglm 同様の
  NA 報告を検討)
- t_nulls / t_factor の専用 pg_regress テストは未追加(TODO の次タスク)

### Next Step

- `fit_glm()` binomial 対応(logit、boolean 応答)+ `t_binomial` テスト
- `t_nulls` の専用 pg_regress テスト(n_dropped 検証を回帰テスト化)

Commit: `Add gaussian fit_glm MVP`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: PostgreSQL Extension 最小骨格の作成

### Summary

- `CREATE EXTENSION fbsql;` が通る最小骨格(control / PGXS Makefile / install script)を作成
- `fbsql` スキーマと、動作確認用のダミー関数 `fbsql.version()`('FbSQL development version' を返す)のみを定義
- pg_regress による回帰テスト基盤を稼働(テスト1本: `SELECT fbsql.version();`)
- CI を「イメージbuild + make install + installcheck」まで拡張
- `fit_glm()` / PL/R / R コードには未着手(意図的)

### Changed Files

- `fbsql.control`: extension 定義(default_version 0.1.0、relocatable=false)
- `Makefile`: PGXS。`REGRESS` + `REGRESS_OPTS --inputdir=test --outputdir=test`
- `sql/fbsql--0.1.0.sql`: `CREATE SCHEMA fbsql` + `fbsql.version()`
- `test/sql/fbsql_version.sql` / `test/expected/fbsql_version.out`: pg_regress テスト
- `scripts/docker-installcheck.sh`: 一時コンテナで make / install / installcheck を一括実行(CIと共用)
- `.gitignore`: pg_regress 出力(`test/results/` 等)を除外
- `.github/workflows/docker-build.yml`: installcheck ステップ追加
- `docs/development.md`: Extension のビルド・テスト手順とテスト追加手順を追記
- `TODO.md`: 骨格タスクを完了化

### Validation

- コンテナ内で `make` → `make install` → **成功**
- `CREATE EXTENSION fbsql;` → **成功**、`SELECT fbsql.version();` → `FbSQL development version`
- `make installcheck`(pg_regress) → **All 1 tests passed**
- `scripts/docker-installcheck.sh` 単体でも通しで成功(CIと同一経路)

### Known Issues

- `\dx` 上の extension 登録スキーマは public(関数実体は fbsql スキーマ)。関数の
  名前空間方針(`fbsql.fit_glm` vs public の `fit_glm`)は TODO.md の未決事項のまま
- ~~CI は GitHub Actions 上での成功をまだ確認していない~~ → push 後に確認済み:
  run 28917262130(build + installcheck)成功

### Next Step

- gaussian のみの `fit_glm()` を PL/R で実装(control に `requires = 'plr'` 追加)
- `t_gaussian` fixture の pg_regress テスト + `scripts/parity_reference.R` で R と丸め一致確認

Commit: `Add PostgreSQL extension skeleton`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Docker開発環境(PostgreSQL + PL/R + R)の構築

### Summary

- FbSQL の開発・テスト環境を Docker で固定した(`postgres:16-bookworm` ベース)
- PL/R はソースビルドを避け、PGDG の apt パッケージ `postgresql-16-plr`(8.4.8.6)を採用(安定性優先)
- `CREATE EXTENSION plr;` と PL/R 関数経由の R 実行(R 4.2.2)を実機検証した
- 将来の `CREATE EXTENSION fbsql` / `pg_regress` 実行に備え `postgresql-server-dev-16` + `make` を同梱
- Docker build が通ることだけを確認する最小 CI を追加
- `fit_glm()` 等の実装はまだ行っていない(意図的)

### Changed Files

- `docker/Dockerfile`: 開発イメージ定義
- `docker/initdb/10-plr.sql`: 初回起動時に plr を自動インストール
- `scripts/docker-build.sh` / `scripts/docker-run.sh`: イメージビルド・開発用起動
- `scripts/check-plr.sh` / `scripts/check-plr.sql`: 一時コンテナでの PL/R 動作検証
- `docs/development.md`: 構成の選定理由・手順・検証済みバージョン表・注意点
- `.github/workflows/docker-build.yml`: 最小 CI(build のみ)
- `README.md`: Development セクション追記
- `TODO.md`: Docker 環境タスクを完了化、R バージョン方針を未決事項に追加
- `docs/dev-log.md`: 本ログを新設

### Validation

- `scripts/docker-build.sh` → **成功**(`postgresql-16-plr` 1:8.4.8.6-1.pgdg12+1 導入)
- `scripts/check-plr.sh` → **成功**: `CREATE EXTENSION plr` が通り、PL/R 関数が
  `R version 4.2.2 Patched (2022-11-10 r83330)` を返した
- イメージ内に `pg_regress` / `make` / `pg_config`(PostgreSQL 16.14)を確認
- コミット直前に `check-plr.sh` を再実行し再現を確認

### Known Issues

- R が 4.2.2(Debian bookworm)とやや古い。MVP(base R の `stats::glm()` のみ使用)には
  十分。論文で報告するバージョン方針は TODO.md の未決事項へ
- CI は build 確認のみ。PL/R 検証・pg_regress の CI 組み込みは Extension 骨組み後
- ホストの docker ソケット権限は `chmod 666` の一時対応(デーモン再起動で戻る。
  恒久対応は docker グループ作成)

### Next Step

- `fbsql.control` + `Makefile`(PGXS)+ 骨組みの `sql/fbsql--0.1.0.sql` で
  `CREATE EXTENSION fbsql;` をイメージ内で通す
- gaussian のみの `fit_glm()` + pg_regress テスト1本 + `scripts/parity_reference.R`

Commit: `Add Docker development environment for PL/R`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: MVP設計書とTODO backlogの整備

### Summary

- `fit_glm()` MVP の設計を `docs/mvp-design.md` として文書化(実装なし)
- リポジトリ構成計画(control / PGXS Makefile / test/ 分離 / META.json の優先度)を確定
- 出力 relation を 16 列で設計(term 粒度 + モデル粒度の同値繰り返し。閉包性 vs 正規化のトレードオフを明文化)
- predict 用 metadata(xlevels / contrasts / terms / link)の論点を整理し、JSONB 列(案A)を第一候補として保留
- テストデータ4テーブル(gaussian / binomial / NULL / factor、手書き・決定的)と R との4桁丸め比較方針を策定
- `TODO.md` を新設、README を概要 + SQL 例に更新

### Changed Files

- `docs/mvp-design.md`: MVP 設計書(新規)
- `TODO.md`: backlog(新規)
- `README.md`: 概要・SQL 例・Status を追加

### Validation

- 文書のみの変更のため実行検証なし

### Known Issues

- 未決事項(関数の名前空間、metadata 格納形式、relation 引数の拡張等)は TODO.md に列挙

### Next Step

- Docker で PostgreSQL + PL/R + R 環境を固定し `CREATE EXTENSION plr` を確認
  (→ 上のエントリで完了)

Commit: 9dccb79 `Add MVP design document, TODO backlog, and README overview`。
