# CLAUDE.md — FbSQL プロジェクトコンテキスト

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

このファイルは本リポジトリの背景・目的・方針に関する開発者向けコンテキストの主要な
情報源である(詳細は README・論文・ソースコードも参照)。今後の Claude Code
セッションが、まずこのファイルを読めばプロジェクト全体を把握できることを目指す。

## FbSQL とは何か

**FbSQL (Formula-based SQL)** は、*閉包性を保存した formula ベースの統計モデリング
DSL* を提案する **PostgreSQL Extension** である。

論文仮タイトル:
**"FbSQL: A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL"**

論文は以下の3つを同時に提案する位置付けを目指す:

1. **PostgreSQL Extension**(リファレンス実装)
2. **SQL言語設計**(FbSQL という DSL そのもの)
3. **Relation設計**(統計関数の出力リレーションはどうあるべきか)

### 最重要の位置付け — 何よりも先にこれを理解すること

- FbSQL は **Rパッケージではない**。PostgreSQL Extension である。R(PL/R 経由の
  `glm()`)はあくまで内部実装であり、**ユーザーが利用する API は SQL** である。
- 主目的は「SQLから統計解析を呼び出すこと」**ではない**。「**SQLの設計原則を維持した
  まま統計解析を記述する言語仕様の提案**」である。論文の主題は「統計モデリングを
  *SQLらしく* 書くにはどうあるべきか」。
- `glm` は **Proof of Concept** にすぎない。同じ設計思想を将来的に Random Forest
  (`fit_rf`)、LightGBM(`fit_lgbm`)、XGBoost(`fit_xgb`)等へ適用することを目指す。
  論文が「PostgreSQLでglmを動かしました」と読まれることは絶対に避ける。

### 解決したい課題

既存のSQL向け機械学習システム(MADlib、PostgresML、Spark MLlib、Hivemall、
H2O-3 + Sparkling Water。BigQuery ML は非OSSのため比較対象外)は、
それぞれの設計目標のもとでモデルオブジェクトや手続き的インターフェースを導入して
おり、SQLの設計原則(特に Relation-in / Relation-out)との間にトレードオフを抱えて
いる。FbSQL は既存システムを「崩している」と断定するのではなく、モデルオブジェクト・
手続き的インターフェース・SQL設計原則とのトレードオフという観点から比較した上で、
「統計解析もSQLらしく書くにはどうあるべきか」を提案する。

## 設計原則(Design Principles)

FbSQL は以下の5つのSQL設計原則を基本とする。論文の Related Work では、既存システムを
この5軸でレビューする(単純な機能比較ではなく、SQL言語設計の観点からの比較):

1. **集合指向(Set-oriented)** — 行やオブジェクトではなくリレーションに対する操作
2. **宣言的(Declarative)** — 「どうやるか」ではなく「何をするか」を記述
3. **閉包性(Closure)** — すべての操作がリレーションを受け取りリレーションを返す
   (Relation-in / Relation-out。**FbSQL 最大の特徴**)
4. **順序独立性(Order Independence)** — 行順序・引数順序に依存しない
5. **NULLセマンティクス(三値論理)** — NULL の扱いはSQLの慣習に準拠

### 原則と仕様の対応

- **閉包性 / Relation-in Relation-out**: `fit_glm()` も `predict_glm()` もリレーションを
  受け取りリレーションを返す。R/Python 流のモデルオブジェクトは一切露出しない —
  これが FbSQL の大原則。
- **宣言的・順序独立なモデル指定**: モデル指定記法として **R の formula 記法**
  (例: `'churn_flag ~ age + gender'`)を採用する。
- **順序独立な引数**: 統計関数は多引数になりやすいため、**Named Argument**
  (`name => value`、PostgreSQL/Oracle 系の記法。標準SQLではない)を採用する。
  Discussion では「標準SQLへの提案としてもこちらの方が自然ではないか」程度に
  慎重に議論する。
- **NULLセマンティクス**: fit / predict どちらの入力リレーションでも、NULL を含む行は
  R の `glm()` と同様 **Complete Case Analysis** とし、SQL の NULL の扱いに準拠する
  仕様として論文に明記する。

### 出力リレーション設計: Minimum Atomic Relation

`fit_xxx()` の出力は「**分析の解釈と予測の当てはめに必要な Minimum Atomic Relation
とは何か?**」という観点から設計する。

`fit_glm()` の場合: Intercept および formula に入れた説明変数ごとに1行、列は R の
`summary()` に含まれるような
`coefficient`, `std_error`, `p_value`, `conf_low_95`, `conf_high_95`。

AIC や R² などモデル全体で1つのスカラー指標は、リレーションを複数に分ける**のではなく**、
1つの列に全行同じ値が入ることを許容する。これは正規化の観点でのトレードオフだが、
`fit_xxx` の出力を**1つのリレーションのみ**とし閉包性を維持するための現実的な
トレードオフとして採用する(Discussion で議論予定)。

`predict_xxx()` は2つのリレーション(fit でできた統計モデルのリレーション + 予測を
当てはめたいリレーション)を受け取り、予測対象と同じ粒度のリレーションを返す。
意図的に `ORDER BY` しない限り**行順序は保証しない**(順序独立性)。

### 提案するAPI(PoC範囲)

最初の論文では `fit_glm()` と `predict_glm()` の2関数のみ。

```sql
CREATE TEMPORARY TABLE logit_model AS
SELECT *
FROM
 fit_glm(
  relation => $$
   SELECT *
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2025
  $$,
  formula => 'churn_flag ~ age + gender',
  family => 'binomial')
;

SELECT customer_id, churn_flag_predicted
FROM
 predict_glm(
  relation => $$
   SELECT customer_id, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2026
  $$,
  model => $$ SELECT * FROM logit_model $$
 ) AS p(customer_id varchar, age integer, gender varchar,
        churn_flag_predicted double precision)
;
```

(確定仕様: `model` はモデルリレーションを返す **SQL 文字列**として渡す —
名前解決やレジストリは無い。`predict_glm` は `SETOF record` を返すため
呼び出し側が列定義リストを書く。`on_new_levels => 'error' | 'na'` 引数あり。)

正式な関数名は **`fbsql.fit_glm()` / `fbsql.predict_glm()`**(`fbsql` スキーマ配下。
`public` には置かない。2026-07-08 確定)。論文や README の例では
`SET search_path TO fbsql, public;` を前提に上記のように短く表記できる。

### Running Example(論文全体を通して使用)

`customer` テーブル:
`customer_id (VARCHAR)`, `created_at (TIMESTAMP)`, `age (INTEGER)`,
`gender (VARCHAR)`, `churn_flag (BOOLEAN)`。
`created_at` が2025年のデータで churn モデルを学習し、2026年のデータに予測を当てはめる。

## 実装戦略

- **`fit_glm()`**: **PL/R** で実装し、内部で R の `glm()` を呼んで上記の Atomic
  Relation を返す。
- **`predict_glm()`**: モデルリレーション + 予測対象リレーションから予測を計算する。
  実装言語はまだ設計上の仮説段階であり、固定しない — 初期実装では PL/R を利用しても
  よく、将来的に SQL / PL/pgSQL / C 実装へ置き換え可能な設計とする。重要なのは
  実装手段ではなく、入出力がリレーションであるという言語仕様の方である。
- **初回論文のスコープは意図的に最小限にする**: `weights` や `offset` は実装コストが
  低いが、査読者の認知コストを下げるため初回論文には*入れない*。
- Discussion で将来展望を書く: C 実装、および木系アンサンブル(`fit_rf`, `fit_lgbm`,
  `fit_xgb`)の Atomic Relation 設計例を挙げ、この設計が GLM を超えて一般化することを示す。

## fbrglm との関係

**fbrglm**(`../fbrglm`、github.com/dsc-chiba-u/fbrglm)は同じ作者の先行プロジェクト:
Rパッケージ("Safe Formula-Based Regularized GLM"、glmnet の formula ベースラッパー)で、
CRAN 公開済み(バージョン表記はメモの 0.1.0 と CRAN 表示の 0.0.1 が不一致 —
論文投稿前に要照合)、`paper/` に JSS 原稿を同梱し、companion リポジトリ
`../fbrglm-experiments`(Zenodo アーカイブ済みの JSS replication material)を持つ。

FbSQL は **fbrglm で確立したプロジェクト運営の型を引き継ぐ**が、成果物の種類は
根本的に異なる。

### fbrglm から引き継ぐもの(踏襲すべき型)

- **2リポジトリ分離**: 本体リポジトリ + ベンチマーク・再現実験・論文用テーブル/図を
  分離した `-experiments` リポジトリ
- **formula 記法**をモデル指定インターフェースとすること
- ソフトウェア/システム論文の型(Running Example、Related Work 比較表、
  Replication material 節を持つ構成)。※投稿先は fbrglm の JSS と異なり
  **The VLDB Journal**(2026-07-13 共著者合意で転針)
- **MIT ライセンス**、GitHub org `dsc-chiba-u`(Data Science Core, Chiba University)
- リリース時に両リポジトリを **Zenodo で DOI アーカイブ**
- **コミットスタイル**: 英語・命令形・大文字始まりの1行サマリ
  ("Add ...", "Fix ...", "Split ...")。Conventional Commits 形式の接頭辞は不使用、本文なし
- 本体リポジトリに **GitHub Actions の CI**(Docker イメージ公開は将来。
  GHCR/DockerHub)。experiments 側は CI なしで、代わりに Docker で環境を固定
- experiments 側の**再現性の規律**: シード固定、合成データジェネレータ、結果を git に
  コミット、開発者固有パスの排除

### fbrglm と異なるもの(盲目的にコピーしないこと)

| | fbrglm | FbSQL |
|---|---|---|
| 成果物 | Rパッケージ | **PostgreSQL Extension** |
| ユーザーAPI | R関数 | **SQL**(`fit_glm`, `predict_glm`) |
| Rの役割 | プロダクトそのもの | 内部エンジンのみ(PL/R が `glm()` を呼ぶ) |
| 公開レジストリ | CRAN | **PGXN** |
| CIの形 | `R CMD check --as-cran` | PostgreSQL + PL/R に対する回帰テスト(`pg_regress` 等) |
| 核心的主張 | glmnet への安全な glm 互換ワークフロー | **SQL の設計原則に忠実な統計モデリング DSL** |
| モデルの出力 | S3 オブジェクト(`fbrglm` クラス) | **リレーション**(設計上モデルオブジェクトを持たない) |

FbSQL は Rパッケージではないため、fbrglm の R 固有の仕組み(DESCRIPTION、roxygen2、
testthat、vignette、cran-comments)はそのまま持ち込まない。PostgreSQL Extension
エコシステムでの対応物は: extension control ファイル + SQL スクリプト + `Makefile`
(PGXS)、`META.json`(PGXN)、`pg_regress` 系のテスト。

## リポジトリの役割分担

- **`FbSQL`(本リポジトリ)**: PostgreSQL Extension 本体 — Extension のソース、
  インストール手順・テスト、ドキュメント、そして(fbrglm の型に従えば)最終的に
  `paper/` 配下の原稿(The VLDB Journal 向け)。
- **`FbSQL-experiments`**(兄弟リポジトリ、稼働中): 関連システム比較
  (Tier 1 = MADlib 実測必須 / Tier 2 = PostgresML・Spark MLlib 実測 /
  Tier 3 = Hivemall・H2O 文献ベース。BigQuery ML は非OSSのため除外)、
  running example の R parity、`data/related_work.csv`(比較表の source of
  truth)と論文表の生成(script 50/51)。各システムの環境は Docker で固定。
  投稿時に replication material として Zenodo にアーカイブする。

## 開発方針

1. **言語設計が第一、実装は第二。** すべての実装判断は5つの設計原則のいずれかに
   遡れること。原則を破るショートカット(例: モデルオブジェクトの露出)は取らない —
   取る場合は、スカラー指標の同値列繰り返しのように、明示的に議論するトレードオフ
   として文書化する。
2. **PoC のスコープは最小限に保つ。** 2関数、glm のみ、weights/offset なし。
   拡張は実装ではなく Discussion に書く。
3. **論文と Extension は共進化する。** fbrglm 同様、原稿の framing を磨くコミットが
   多数発生することを想定する。設計が変わったらこのファイルも更新すること。
4. **初日から再現性を。** 査読者が再実行すべきものはすべて、環境固定・シード固定の
   上で FbSQL-experiments に置く。
5. **作業のたびに記録して push する。** 特段の指示がなければ、各作業セッションの
   終わりに `docs/dev-log.md`(進捗共有用ログ。最新を一番上に、1回分 200〜400語)へ
   要約を追記し、コミットして `main` に push する。

## コーディング規約・コミット方針

- **コミット**: 英語・命令形・大文字始まり・具体的な1行サマリ
  (例: "Add fit_glm output relation for binomial family")。接頭辞なし、本文なし。
- **SQL**: キーワードは大文字。Named Argument 呼び出し(`=>`)。relation 引数には
  上記例のようにドル引用符(`$$...$$`)を使う。
- **R(PL/R 内部実装)**: fbrglm のスタイルに従う — インデントはスペース4、
  snake_case、内部ヘルパーは `.` 接頭辞、引数検証は関数冒頭に集約、
  `stop(..., call. = FALSE)` + `sprintf` 整形メッセージ、「なぜ」を説明する
  設計判断コメント。
- **ドキュメント等の公開成果物はすべて英語**(このコンテキストファイルは例外的に
  日本語)。メンテナとの会話は日本語で構わない。

## 公開・投稿計画(最終目標)

1. PostgreSQL Extension としての **OSS 公開**(MIT ライセンス、GitHub `dsc-chiba-u` org)
2. **PGXN**(PostgreSQL Extension Network)への公開 — CRAN 相当のマイルストーン
3. ベンチマーク・再現実験を **`FbSQL-experiments`** として分離し、Zenodo で DOI 付き
   アーカイブ(fbrglm-experiments の型を踏襲)
4. **The VLDB Journal**(Springer)へ投稿(2026-07-13 に JSS から転針。
   svjour3 2カラム・25ページ上限・番号引用・keywords 4〜6個・single-blind、
   Declarations 必須)。構成: 動機 → 5つの設計原則によるRelated Work レビュー
   → 言語・リレーション設計 → PoC 実装 → Running Example → ベンチマーク
   (FbSQL-experiments から)→ 一般化(木系アンサンブル、C実装)とトレードオフの Discussion

## 開発コマンド

すべて Docker 前提(ホストに R / PostgreSQL 不要)。環境は
PostgreSQL 16.14 + PL/R 8.4.8.6 + R 4.2.2(`docker/Dockerfile`)。

```bash
scripts/docker-build.sh          # 開発イメージ fbsql-dev のビルド(最初に1回)
scripts/check-plr.sh             # CREATE EXTENSION plr の疎通確認
scripts/docker-installcheck.sh   # make → install → pg_regress 全11本(CI と同じ)
```

- 単一テスト: 常駐コンテナ内で `make installcheck REGRESS=running_example` の
  ように PGXS の `REGRESS` を上書き(テスト一覧は `Makefile` の REGRESS)
- R 側の参照値: `Rscript scripts/parity_reference.R`(fbsql-dev コンテナ内)。
  テストは全数値を R と**4桁丸め**で照合し、`ORDER BY term COLLATE "C"` で
  ロケール非依存にする規約
- CI: `.github/workflows/docker-build.yml`(イメージビルド + installcheck)

論文(`paper/`。ビルド環境は別イメージ fbsql-paper = rocker/verse:4.4.2):

```bash
cd paper
make image   # fbsql-paper イメージのビルド(最初に1回)
make html    # 開発ビルド(html_document)
make vldb    # 投稿ビルド(Springer svjour3 2カラム + pdflatex)
make clean
```

`paper/tables/` は **FbSQL-experiments の script 51 から自動生成**(手編集
禁止)。図は `paper/figures/*.R` から SVG + PDF を生成(drawio ソース併置)。

## 実装済みコードのハマりどころ(必読)

- **PL/R 内で `pg.spi.exec` を tryCatch しない。** SPI エラーで abort した
  トランザクションの上から R 側でエラーを投げるとバックエンドがクラッシュ
  する。relation SQL の失敗は PostgreSQL ネイティブエラーをそのまま伝播
  させる(`sql/fbsql--0.1.0.sql` のコメントと `docs/mvp-design.md` §2 参照)
- **2カラム(svjour3)の制約**: markdown のパイプ表は longtable になり
  twocolumn では組めない(仕様表はチャンクで dual-format 化済み)。幅広の
  図表は `fig.env="figure*"` / ビルド時の `table*` 昇格で全幅にする
- **テンプレートとの手動同期**: title / abstract は paper.Rmd の YAML が
  単一情報源。authors / institutes / keywords は
  `paper/vldb/vldbj-template.tex` 側にあり、変更時は両方を更新すること。
  テンプレートのコメントに `$` 付き変数名を書かない(置換されて壊れる)
- 実装は `sql/fbsql--0.1.0.sql` に集約(fit_glm = PL/R、predict_glm =
  PL/pgSQL で R 不使用)。出力 relation は17列(metadata jsonb は
  meta_version 1)。詳細設計は `docs/mvp-design.md`

## 現状(2026年7月時点)

- **Extension 本体は MVP 完了**: `fbsql.fit_glm()`(gaussian / binomial、
  factor、Complete Case、Wald CI、metadata jsonb)+ `fbsql.predict_glm()`
  (PL/pgSQL、factor、`on_new_levels`)。pg_regress 11本 + CI グリーン、
  全数値 R 一致(4桁)。PGXN 用 `META.json` / `Changes` 整備済み(未投稿)
- **論文(`paper/paper.Rmd`)は本文初稿完成**: 全9章 + Abstract + 図4点 +
  表2点(experiments から生成)。構成整理レビュー済み
  (`docs/paper-review-2026-07-08.md` に残課題)
- **FbSQL-experiments 稼働中**: running example の R parity(13/13)、
  MADlib / PostgresML / Spark の実測比較、Hivemall / H2O の文献比較、
  related_work.csv → 論文表の生成パイプライン
- 進捗ログは `docs/dev-log.md`(最新が先頭)。未決事項は `TODO.md`
- 元の計画メモ(`FbSQLプロジェクトメモ.txt`)は本ファイルに吸収済みで削除

## Non-goals(本プロジェクトが目指さないこと)

今後のセッションで設計思想がぶれないよう、以下を明記する:

- **CRAN パッケージ化は目的ではない。** 公開先は PGXN であり、Rパッケージとしての
  配布は行わない。
- **R API を設計するプロジェクトではない。** R は内部実装(PL/R)にのみ登場し、
  ユーザーに R の関数やオブジェクトを露出することはない。
- **glm 自体を高速化する研究ではない。** 統計計算の性能改善は主張に含まれない。
- **「PostgreSQL から `glm()` を呼べること」自体は研究の主張ではない。** それは
  PL/R で従来から可能であり、本研究の新規性ではない。
- **本研究の主張は SQL DSL と言語設計である。** 閉包性をはじめとする SQL の設計原則を
  維持した統計モデリング言語仕様(FbSQL)の提案が核心であり、glm はその Proof of
  Concept にすぎない。
