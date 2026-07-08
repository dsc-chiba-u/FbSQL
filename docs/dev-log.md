# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
実装・設計判断の詳細は `docs/` 配下の該当文書(`mvp-design.md`, `development.md`)を
参照し、本ファイルは要約に留める。

---

## 2026-07-08: Design Principles 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Design Principles 章のみ**を本文化(他章は TODO のまま)。
  導入 + 5原則(Set orientation / Declarative specification / Closure /
  Order independence / NULL semantics)+ 締めの
  「From glm to a family of modeling functions」の7小節構成
- 各原則を「SQL における意味 → 統計モデリングとの緊張 → FbSQL の仕様決定 →
  既存システムの異なるトレードオフ」の4点で記述
- 必須の主張を反映: PL/R で glm を呼べること自体は貢献ではない(内部利用と明記)/
  主張は SQL 設計原則に沿う DSL / glm は PoC で fit_rf・fit_lgbm・fit_xgb へ一般化 /
  **モデルは relation**(predict_glm が R なしの PL/pgSQL で動くことを
  「relation がモデルの完全表現である証拠」として使用)/ metadata JSONB と
  モデル粒度列の行反復は閉包性維持のための意図的非正規化
- 既存システムへの言い回しは慎重に統一("make different trade-offs" /
  "expose model objects" / "rely on procedural interfaces" /
  "preserve closure at the DataFrame level rather than the SQL level"。
  "violate" は不使用)
- 文献は既存 references.bib の9件のみ使用(codd1970relational,
  chambers1992statistical, hellerstein2012madlib, meng2016mllib, plr,
  postgresml, hivemall, h2o)。新規追加なし。JSS 専用マクロ(\proglang 等)は
  html / jss 両ビルド互換のため未使用(投稿整形時に導入)

### Changed Files

- `paper/paper.Rmd`: Design Principles 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用(`[@key]` / `???`)が出力に無いことを確認
- `make jss` → 成功(paper-jss.pdf 233KB、本文反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 章内から *Discussion* 節へ文中参照が3箇所ある(自動相互参照ではなく地の文)。
  Discussion 執筆時に対応関係(非正規化・named argument・木系 Atomic Relation)を
  忘れず回収すること

### Next Step

- Related Work 章の初稿(experiments の related_work.csv / 6システム比較表を素材に、
  Design Principles 章の5原則の軸でレビュー)

Commit: `Draft design principles section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: 論文ビルド環境の固定 — make html / pdf / jss すべて成功

### Summary

- **`paper/Dockerfile`(rocker/verse:4.4.2 ベース)で論文ビルド環境を固定**し、
  `make html` を含む3ターゲットすべてを実機で成功させた:
  `make html`(html_document)、`make pdf`(weasyprint)、
  **`make jss`(rticles::jss_article + pdflatex で JSS クラスの PDF 生成)**
- Makefile を Docker ラッパー化(`make image` でビルド、各ターゲットは非rootで
  コンテナ実行)。実験環境(fbsql-dev)とは完全分離
- **JSS ビルドの3つの障害を解決**:
  (1) rocker/verse の TinyTeX に JSS クラスの依存 LaTeX パッケージが不足 —
  非rootコンテナでは自動導入が効かないため、**イメージビルド時に明示インストール +
  rticles の JSS skeleton をレンダリングして `tinytex::parse_install()` で残りを
  焼き込む**方式を確立(orcidlink / pgf / thumbpdf / natbib / grfext 等)。
  (2) rticles の JSS テンプレートは `documentclass: jss` と構造化 title / keywords を
  要求 — render.sh の jss ターゲットで**一時コピーの YAML を JSS 形式に書き換える**
  (fbrglm の render_jss_pdf.R と同方式。ソース Rmd は非改変)。
  (3) クラス資産(jss.cls / jss.bst / jsslogo.jpg)は rticles の skeleton から
  ビルドディレクトリへ一時コピー(非コミット)
- 作業中に **/tmp(ルートFS)が満杯**になり出力キャプチャまで停止 → 検証済み・
  再取得可能な PostgresML イメージ(15GB)を削除して復旧(必要時は re-pull)
- paper.Rmd の修正は不要だった(YAML は初期化時のまま html ビルド成功)。本文未執筆

### Changed Files

- `paper/Dockerfile`: 新規(rocker/verse + weasyprint + rticles + JSS用LaTeX焼き込み)
- `paper/Makefile`: Docker ラッパー化(image / html / pdf / jss / clean)
- `paper/render.sh`: jss ターゲットを完成(skeleton資産コピー + YAML書き換え + 出力回収)
- `paper/README.md`: Building 節を実手順(make image → make html 等)に更新

### Validation

- `make html` → **成功**(paper.html 生成)
- `make pdf` → **成功**(weasyprint、CSS警告のみ)
- `make jss` → **成功**(paper-jss.pdf、196KB、JSSクラス)
- `make clean` → 生成物3種 + 中間物を削除
- `git status` にビルド生成物が残らないことを確認(.gitignore 済み)

### Known Issues

- render.sh 内の JSS 用 YAML(title / author / keywords)は paper.Rmd と手動同期
  (執筆時に注意。スクリプト内にコメントで明記済み)
- ディスク残量が逼迫気味(15GB空き)。PostgresML の再検証時はイメージ re-pull が必要

### Next Step

- Design Principles 章から本文執筆を開始(CLAUDE.md の構成案・mvp-design の
  決定事項・experiments の比較表を素材に)

Commit: `Add paper build environment`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: JSS 論文プロジェクトの初期化(paper/)

### Summary

- `paper/` を新設し、**fbrglm の paper 構成を踏襲**して論文プロジェクトを初期化
  (本文は未執筆 — 章立てと TODO コメントのみ)
- `paper.Rmd`: JSS 慣行の YAML(fbrglm と同形式。開発ビルドは html_document、
  JSS ビルドは一時コピーに rticles::jss_article を適用する2系統方式)+
  固定の10章構成(Abstract は YAML 内、Introduction 〜 Conclusion の9セクション)。
  各章に執筆時の論点を TODO コメントで1〜3行
- 共著者リストは fbrglm からの引き継ぎを仮定せず TODO 化(筆頭著者のみ記載)
- `references.bib`: シード9件(Codd 1970 / Chambers & Hastie 1992 / MADlib PVLDB
  2012 / MLlib JMLR 2016 / R Core / PostgresML / Hivemall / H2O / PL/R)。
  投稿前の全フィールド検証を TODO 明記
- `render.sh` + `Makefile`: html / pdf(weasyprint)/ jss の3ターゲット。
  ビルド環境は fbsql-dev イメージとは別(rmarkdown/pandoc/LaTeX が必要)で、
  執筆本格化時に固定する方針を README に明記
- **experiments との役割分担を paper/README.md に明文化**: paper/ は原稿管理のみ、
  図表・CSV・実験結果の生成は FbSQL-experiments が担当し、paper/ は成果物を
  引用するだけ(実験コードを持たない)
- 図表アセット計画(tables/related_work.tex, tables/running_example.tex,
  figures/system_overview.pdf, figures/running_example.pdf)を README の表で整理
  (実体は未作成)
- `.gitignore` に原稿ビルド生成物と journal/ 資産(rticles からビルド時取得、
  非コミット)を追加

### Changed Files

- `paper/paper.Rmd` / `references.bib` / `render.sh` / `Makefile` / `README.md`: 新規
- `paper/figures/` / `tables/` / `journal/`: .gitkeep で予約
- `.gitignore`: 原稿ビルド出力の除外

### Validation

- 文書・骨組みのみの変更(Extension コード無変更)。paper.Rmd の YAML は
  fbrglm-jss-draft.Rmd の形式を目視で照合。レンダリングは環境未固定のため未実行
  (「まだ完全に動かなくてよい」の方針通り、要件を README に記録)

### Known Issues

- 論文ビルド環境(rmarkdown + pandoc + weasyprint + rticles + LaTeX)は未固定
- 共著者・keywords・maintainer 連絡先など投稿メタデータに未確定項目あり(TODO)

### Next Step

- 論文ビルド環境の固定(専用 Dockerfile)と `make html` の初回成功確認、
  その後 Design Principles 章から本文執筆を開始(CLAUDE.md の構成案に沿う)

Commit: `Initialize JSS paper project`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: PGXN 公開準備の最小整備(META.json / Changes)

### Summary

- **`META.json` を新規作成**(PGXN Meta Spec v1.0.0 準拠): name / abstract /
  description / version 0.1.0 / maintainer / license mit / provides(install
  script と README を参照)/ prereqs(PostgreSQL 16.0.0 + plr 8.4.0)/
  resources(GitHub の homepage / bugtracker / repository)/ meta-spec / tags 8件
- **`Changes` を新規作成**(0.1.0 unreleased): skeleton / Docker+PL/R 環境 /
  fit_glm(gaussian・binomial・factor・NULL・metadata)/ predict_glm(R不使用・
  novel level)/ Running Example / pg_regress・CI を初期リリース候補として整理
- README に **Installation セクション**を追加(`make install` →
  `CREATE EXTENSION fbsql CASCADE`、PL/R の superuser 要件、PGXN 未投稿の明記)と
  **Related repositories**(FbSQL-experiments への導線、citation は論文公開時に追加)
- バージョン整合を確認: control(0.1.0)= install script ファイル名 = META.json =
  provides = Changes
- 不明項目は勝手に埋めず TODO 化: maintainer メールは fbrglm/CRAN と同じ hotmail を
  **仮置き(要本人確認)**、PostgreSQL prereq は検証済みの 16 のみ
- PGXN への実投稿は行っていない(意図的)

### Changed Files

- `META.json` / `Changes`: 新規
- `README.md`: Installation / Related repositories セクション追加
- `TODO.md`: META.json+Changes タスク完了化、「PGXN 投稿前チェックリスト」節を新設
  (正式バリデータ検証・maintainer確定・PGバージョン範囲・配布アーカイブ・
  Zenodo DOI・Changes 日付確定)

### Validation

- META.json: JSON 妥当性 OK、必須フィールド欠落なし、provides.file の実在確認、
  バージョン整合 0.1.0 で一致
- `scripts/docker-installcheck.sh` → **All 11 tests passed**(make install +
  pg_regress。コード無変更の回帰確認)
- PGXN の正式バリデータ(PGXN::Meta::Validator)は環境に Perl 依存を持ち込まないため
  未実行 — 投稿前チェックリストに記録

### Known Issues

- maintainer メールアドレスは仮置き(TODO 参照)
- prereqs の PostgreSQL 16.0.0 は「検証済み最小」であり、対応範囲の確定は今後

### Next Step

- **JSS 論文フェーズへ**: `FbSQL/paper/` に fbrglm の型(Rmd + jss.cls + 2系統ビルド)
  で骨組みを作り、設計原則・Running Example 実測・experiments の比較表を流し込む

Commit: `Add PGXN release metadata`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Running Example 統合テストと README 同期 — 本体 MVP 到達

### Summary

- 論文の Running Example(customer churn)を pg_regress 統合テスト化:
  `customer` テーブル(customer_id / created_at / age / gender / churn_flag)、
  2025年データで `churn_flag ~ age + gender` を binomial fit → 2026年データへ predict
- `churn_flag_predicted` が customer_id 粒度で返り、NULL age → NULL 予測、
  novel level('Nonbinary')は既定でエラー・`on_new_levels => 'na'` で該当行のみ NULL、
  をすべて1テストで検証
- 係数・予測確率とも R(glm / predict type="response")と4桁丸めで一致
- README を全面整理: PostgreSQL Extension であり R パッケージではないことの明示、
  Running Example の掲載、対応済み/未対応の正確なリスト(大規模・分散 GLM は
  スコープ外であることも明記)
- `docs/mvp-design.md` に「本体 MVP 到達点」セクションを追加
- 機能追加なし(統合テスト + 文書同期のみ)

### Changed Files

- `test/sql/running_example.sql` / expected: 新規(fit 係数確認 + predict 3パターン)
- `Makefile`: REGRESS に running_example 追加
- `scripts/parity_reference.R`: running example 参照セクション追加
- `README.md`: 全面整理(Running Example、Supported today / Not yet supported)
- `docs/mvp-design.md`: 本体 MVP 到達点セクション追加
- `TODO.md`: Running Example 統合テスト完了を記録

### Validation

- fit 係数(binomial, n=12): `(Intercept) −12.1071±7.1895`, `age 0.2981±0.1669`,
  `genderM −0.4305`, `genderOther −0.7049` — R と一致、分離・収束警告なし
- 2026年予測: c101(30, F)→ **0.0406**、c102(55, M)→ **0.9794**、
  c103(42, Other)→ **0.4280**、c104(age NULL)→ **NULL** — R と一致
- c105(gender 'Nonbinary'): 既定でエラー(既知水準一覧付き)、`'na'` で該当行のみ NULL
- `make installcheck` → **All 11 tests passed**
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- 本体 MVP として意図的に未対応: interaction、custom contrasts、offset / weights、
  prediction interval、class prediction、他 family / 非 canonical link、
  大規模・分散 GLM(Non-goal)

### Next Step

- 本体 MVP 完了につき、次は公開・論文系へ: (1) META.json / Changes 整備(PGXN 準備)、
  (2) FbSQL-experiments リポジトリ着手(関連システム比較・論文用素材)、
  (3) interaction 対応、の優先順位をメンテナと相談

Commit: `Add running example integration test`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: predict_glm() 第3段階 — factor 対応と on_new_levels

### Summary

- `predict_glm()` が factor predictor に対応。係数 term(`genderM` 等)を metadata の
  `xlevels` と突き合わせて `<factor><水準>` に分解し、treatment contrast のダミーを
  `((r.gender = 'M')::int)` の SQL 式で再構築(引き続き R 不使用)
- `on_new_levels text DEFAULT 'error'` 引数を追加(fbrglm 踏襲):
  `'error'` は novel 水準を水準名・既知水準一覧付きでエラー、`'na'` は該当行のみ
  予測値 NULL。不正な値は明示エラー
- factor 列 NULL の行は等値比較の NULL 伝播で自然に予測値 NULL(数値列と同一挙動)
- `contr.treatment` 以外の contrasts、解釈不能な係数 term(交互作用等)は明示エラーで防御
- gaussian / binomial の両方で数値・factor 混在モデルが R と一致
- **これで Running Example(churn 予測の fit → predict)がコア機能として一通り動作**

### Changed Files

- `sql/fbsql--0.1.0.sql`: predict_glm を第3段階に拡張(引数追加、term 分類、
  ダミー再構築、novel 検出プローブ、na 用 CASE ラップ、contrasts 検証)
- `test/sql/predict_glm_factor.sql` / expected: 新規(7ケース: error/na/正常/引数不正/
  混在/binomial+factor/NULL行)
- `test/sql/predict_glm_numeric.sql` / expected: 「factor はエラー」ケースを削除
  (成功に変わったため)
- `Makefile`: REGRESS に predict_glm_factor 追加
- `scripts/parity_reference.R`: factor/mixed/binomial+factor の predict 参照を追加
- `README.md` / `docs/mvp-design.md` / `TODO.md`: 対応状況更新。新規 TODO 2件
  (interaction 対応、novel 検出プローブの1パス化)

### Validation

- factor のみ(y ~ gender): F→1.25, M→2.25, Other→2.90, NULL→NULL — R と一致
- novel 'error': `factor 'gender' has new level 'Unknown' ... (known levels:
  ["F","M","Other"]); use on_new_levels => 'na' ...`
- novel 'na': Unknown 行のみ NULL、他は通常予測
- 混在(y ~ x1 + gender): 1.5333 / 3.6667 / NULL(gender NULL)/ NULL(x1 NULL)— R と一致
- binomial + factor: F→0.3333, M→0.6667 — R の type="response" と一致
- `make installcheck` → **All 10 tests passed**
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- `on_new_levels => 'error'` の novel 検出は factor ごとの事前プローブクエリのため、
  relation が複数回実行される(volatile な relation では注意。TODO に1パス化を記録)
- interaction は fit 側では通るが predict 側は「cannot interpret coefficient term」
  エラーで防御(TODO に対応を記録)

### Next Step

- コア機能一式が揃ったので、次は品質・公開系: interaction 対応 or META.json/Changes
  整備(PGXN 準備)or FbSQL-experiments リポジトリ着手、の優先順位付け

Commit: `Add factor predict_glm support`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: predict_glm() 第2段階 — binomial/logit の確率予測

### Summary

- `predict_glm()` を binomial/logit に対応(数値説明変数のみ)。線形予測子に
  逆リンク `1/(1+exp(-lp))` を適用し、R の `predict(type = "response")` 相当の
  確率を返す
- family/link の組を検証する方式に変更(gaussian/identity と binomial/logit のみ許可、
  それ以外は組を明示したエラー)
- `data_classes` の numeric チェックから**応答列を除外**: 応答は予測対象 relation に
  不要で、binomial では boolean(logical)応答が正当なため(Running Example の
  churn_flag)。boolean 応答モデルでの予測もテスト化
- 既存の predict_glm_numeric テストから「binomial はエラー」ケースを削除
  (成功ケースに変わったため新テストへ移動)
- 実装は引き続き PL/pgSQL・R 不使用・API 変更なし

### Changed Files

- `sql/fbsql--0.1.0.sql`: link 取得、family/link 検証、逆リンク適用、応答列除外
- `test/sql/predict_glm_binomial.sql` / expected: 新規(整数応答 + boolean 応答の2モデル)
- `test/sql/predict_glm_numeric.sql` / expected: binomial エラーケースを削除
- `Makefile`: REGRESS に predict_glm_binomial 追加
- `scripts/parity_reference.R`: binomial predict 参照セクション追加
- `README.md` / `docs/mvp-design.md` / `TODO.md`: 対応状況の更新

### Validation

- t_binomial(12行)で学習 → t_new_binomial の予測確率:
  x=0.5 → **0.3315**、x=1.5 → **0.4826**、x=2.5 → **0.6370** —
  R の `predict(glm(y ~ x, family=binomial()), newdata, type="response")` と一致
- boolean 応答(y::boolean)で学習したモデルでも同一の確率
- `make installcheck` → **All 9 tests passed**
- `scripts/docker-installcheck.sh`(CI同一経路)→ 成功

### Known Issues

- 極端な線形予測子(|lp| が非常に大きい)では float8 の exp() がオーバーフローしうる
  (実データ規模では非現実的。必要になれば飽和処理を検討)
- prediction `type` 引数(link スケール等)は未対応(意図的)

### Next Step

- `predict_glm()` 第3段階: factor 対応 — metadata の xlevels / contrasts を消費して
  ダミー列を SQL 式で再構築、`on_new_levels => 'error'|'na'` 引数と novel level 検出

Commit: `Add binomial predict_glm support`(本エントリを含むコミット)。
push 後の `git status`: clean。

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
