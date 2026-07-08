# CLAUDE.md — FbSQL プロジェクトコンテキスト

このファイルは本リポジトリの背景・目的・方針の唯一の情報源である。今後の Claude Code
セッションは、このファイルだけ読めばプロジェクト全体を理解できることを目指す。

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

既存のSQL向け機械学習システム(MADlib、Spark MLlib、HiveMall、BigQuery ML)は、
機械学習機能は提供しているものの、モデルオブジェクトや手続き的インターフェースの
導入などにより、SQL本来の設計原則(特に Relation-in / Relation-out)を少なからず
崩している。FbSQL は「統計解析もSQLらしく書くにはどうあるべきか」を提案する。

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
   SELECT *
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2026
  $$,
  model => 'logit_model')
;
```

### Running Example(論文全体を通して使用)

`customer` テーブル:
`customer_id (VARCHAR)`, `created_at (TIMESTAMP)`, `age (INTEGER)`,
`gender (VARCHAR)`, `churn_flag (BOOLEAN)`。
`created_at` が2025年のデータで churn モデルを学習し、2026年のデータに予測を当てはめる。

## 実装戦略

- **`fit_glm()`**: **PL/R** で実装し、内部で R の `glm()` を呼んで上記の Atomic
  Relation を返す。
- **`predict_glm()`**: **R を介さず**実装する — 可能なら純粋な SQL、無理なら PL/pgSQL。
  モデルリレーション + 予測対象リレーションから予測を計算する。
- **初回論文のスコープは意図的に最小限にする**: `weights` や `offset` は実装コストが
  低いが、査読者の認知コストを下げるため初回論文には*入れない*。
- Discussion で将来展望を書く: C 実装、および木系アンサンブル(`fit_rf`, `fit_lgbm`,
  `fit_xgb`)の Atomic Relation 設計例を挙げ、この設計が GLM を超えて一般化することを示す。

## fbrglm との関係

**fbrglm**(`../fbrglm`、github.com/dsc-chiba-u/fbrglm)は同じ作者の先行プロジェクト:
Rパッケージ("Safe Formula-Based Regularized GLM"、glmnet の formula ベースラッパー)で、
CRAN 公開済み(v0.1.0)、`paper/` に JSS 原稿を同梱し、companion リポジトリ
`../fbrglm-experiments`(Zenodo アーカイブ済みの JSS replication material)を持つ。

FbSQL は **fbrglm で確立したプロジェクト運営の型を引き継ぐ**が、成果物の種類は
根本的に異なる。

### fbrglm から引き継ぐもの(踏襲すべき型)

- **2リポジトリ分離**: 本体リポジトリ + ベンチマーク・再現実験・論文用テーブル/図を
  分離した `-experiments` リポジトリ
- **formula 記法**をモデル指定インターフェースとすること
- **JSS を第一候補**とするソフトウェア論文(Running Example、Related Work 比較表、
  Replication material 節を持つ構成)
- **MIT ライセンス**、GitHub org `dsc-chiba-u`(Data Science Core, Chiba University)
- リリース時に両リポジトリを **Zenodo で DOI アーカイブ**
- **コミットスタイル**: 英語・命令形・大文字始まりの1行サマリ
  ("Add ...", "Fix ...", "Split ...")。Conventional Commits 形式の接頭辞は不使用、本文なし
- 本体リポジトリに **GitHub Actions の CI** + Docker イメージ公開(GHCR/DockerHub)。
  experiments 側は CI なしで、代わりに conda 等で環境を固定
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
  `paper/` 配下の JSS 原稿。
- **`FbSQL-experiments`**(兄弟リポジトリとして今後作成): ベンチマーク、関連システム
  (MADlib、Spark MLlib、HiveMall、可能なら BigQuery ML)との比較、再現可能な実験
  スクリプト、論文用テーブル・図の生成。環境固定(例: PostgreSQL + PL/R + R の
  Docker Compose)もこちらに置く。投稿時に JSS replication material として Zenodo に
  アーカイブする。

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
4. **JSS**(Journal of Statistical Software)を第一候補としてソフトウェア論文を投稿。
   構成は fbrglm の JSS ドラフトに倣う: 動機 → 5つの設計原則によるRelated Work レビュー
   → 言語・リレーション設計 → PoC 実装 → Running Example → ベンチマーク
   (FbSQL-experiments から)→ 一般化(木系アンサンブル、C実装)とトレードオフの Discussion

## 現状(2026年7月)

グリーンフィールド: 本リポジトリには README、LICENSE(MIT, Data Science Core)、
本ファイルのみが存在する。Extension のコードはまだない。元の計画メモ
(`FbSQLプロジェクトメモ.txt`)は本ファイルに完全に吸収済みで、削除された。
