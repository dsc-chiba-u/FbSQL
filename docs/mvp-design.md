# FbSQL MVP 設計書(v0.1.0 に向けて)

本書は `fit_glm()` の初回実装(MVP)に先立つ設計文書である。プロジェクト全体の
背景・設計原則は `CLAUDE.md` を参照。本書のスコープは以下の3点:

1. PostgreSQL Extension としてのリポジトリ構成の確定
2. `fit_glm()` の MVP 仕様と出力 relation の確定
3. 将来の `predict_glm()` を見据えた metadata 設計の論点整理

**本書の段階では実装は行わない。**

---

## 1. リポジトリ構成計画

### 現状

```
FbSQL/
├── CLAUDE.md     # 開発者向けコンテキスト
├── LICENSE       # MIT
└── README.md
```

Extension としての実体はまだ何もない。

### 目標構成(MVP 完了時)

```
FbSQL/
├── fbsql.control            # Extension 定義(requires = 'plr')
├── Makefile                 # PGXS ベースのビルド・テスト定義
├── sql/
│   └── fbsql--0.1.0.sql     # Extension インストールスクリプト(fit_glm 定義)
├── test/
│   ├── sql/                 # pg_regress 入力(fixture DDL + fit_glm 呼び出し)
│   │   ├── fit_glm_gaussian.sql
│   │   ├── fit_glm_binomial.sql
│   │   ├── fit_glm_nulls.sql
│   │   └── fit_glm_factor.sql
│   └── expected/            # pg_regress 期待出力(*.out)
├── scripts/
│   └── parity_reference.R   # 同一データで stats::glm() の参照値を出力するRスクリプト
├── docker/
│   └── Dockerfile           # 開発・CI用環境(PostgreSQL + PL/R + R)
├── docs/
│   └── mvp-design.md        # 本書
├── .github/workflows/
│   └── regress.yml          # build → install → installcheck(pg_regress)
├── META.json                # PGXN 公開用 metadata(公開直前に整備)
├── Changes                  # PGXN 慣習の変更履歴(fbrglm の NEWS.md 相当)
├── TODO.md                  # 延期した機能・未決事項の backlog
├── README.md / LICENSE / CLAUDE.md
```

### 各ファイルの必要性と優先度

| ファイル | 必要性 | 優先度 |
|---|---|---|
| `fbsql.control` | Extension の必須ファイル。`requires = 'plr'` で PL/R 依存を宣言 | **MVP必須** |
| `Makefile`(PGXS) | `make install` / `make installcheck` の標準経路。PGXN もこれを前提とする | **MVP必須** |
| `sql/fbsql--0.1.0.sql` | `CREATE EXTENSION fbsql` の実体。`fit_glm()` はここで定義 | **MVP必須** |
| `test/sql/` + `test/expected/` | pg_regress による回帰テスト。fbrglm の testthat に相当する層 | **MVP必須** |
| `scripts/parity_reference.R` | R の `stats::glm()` との一致確認(スモークレベル) | **MVP必須** |
| `docker/Dockerfile` | PL/R 入り PostgreSQL は標準イメージにないため、開発・CI の再現環境として必要 | **MVP必須** |
| `.github/workflows/regress.yml` | fbrglm の R-CMD-check に相当。Docker イメージ上で installcheck | MVP直後 |
| `META.json` / `Changes` | PGXN 公開(CRAN 投稿に相当)の必須要件。公開直前で十分 | PGXN公開前 |
| `paper/` | JSS 原稿。fbrglm の型に従い本体リポジトリに置くが、実装が安定してから | 後日 |

### 作らないもの(と、その理由)

- **`expected/` をリポジトリ直下に置かない**: Extension スクリプト用の `sql/` と
  pg_regress テスト用の `sql/` が衝突するため、テストは `test/` 配下に分離し
  Makefile の `REGRESS_OPTS = --inputdir=test` で解決する(PGXN でよく見る構成)。
- **ベンチマーク・比較実験**: `FbSQL-experiments`(別リポジトリ)の担当。本体には
  スモークレベルの R 一致確認のみ置く(fbrglm / fbrglm-experiments の分担と同じ)。
- **DESCRIPTION / roxygen2 / testthat 等の R パッケージ機構**: FbSQL は R パッケージ
  ではない(CLAUDE.md の Non-goals 参照)。
- **`predict_glm()` 関連ファイル**: MVP 対象外(§4 で設計論点のみ整理)。

### 運用上の制約(記録)

PL/R は untrusted language であり、`CREATE EXTENSION plr` および PL/R 関数の定義は
superuser 権限を要する。`fit_glm()` の実行権限は `GRANT EXECUTE` で一般ユーザーに
付与する運用を想定。README / 論文の Computational details に明記する。

---

## 2. MVP 仕様: `fit_glm()`

### スコープ

- 対象関数は **`fit_glm()` のみ**。`predict_glm()` は実装しない
  (formula・factor・contrast・link・NULL処理・metadata 保存が絡むため、
  `fit_glm()` の設計が固まってから着手する)。
- family は **`gaussian`(identity link)と `binomial`(logit link)** のみ。
  それ以外は明示的なエラーにする。
- weights / offset は実装しない(論文スコープ最小化のため。CLAUDE.md 参照)。

### 名前空間(2026-07-08 確定)

- 正式な API は **`fbsql.fit_glm()`**(`fbsql.version()` と同じく `fbsql` スキーマ配下)。
- **`public.fit_glm()` は作らない**(名前衝突の回避と、Extension の名前空間の明確化)。
- README・論文では、必要に応じて `SET search_path TO fbsql, public;` を示すことで
  `fit_glm()` と短く書けることを説明する。

### シグネチャ

```sql
CREATE FUNCTION fbsql.fit_glm(
    relation text,                       -- 学習データを定義する SQL 文字列($$...$$)
    formula  text,                       -- R の formula 記法('y ~ x1 + x2')
    family   text DEFAULT 'gaussian'     -- 'gaussian' | 'binomial'
) RETURNS SETOF fbsql.glm_fit            -- §3 の列を持つ複合型
LANGUAGE plr;
```

- PostgreSQL は関数引数名による Named Argument 呼び出し
  (`fit_glm(relation => ..., formula => ..., family => ...)`)を標準サポートする
  ため、追加の仕掛けは不要。
- 戻り値は `RETURNS TABLE`(= relation)。R のモデルオブジェクトは一切露出しない。

### 内部動作(PL/R)

1. `pg.spi.exec(relation)` で入力 SQL を実行し、結果を R の data.frame として受け取る
2. 文字列列は factor へ変換(R >= 4 の `stringsAsFactors=FALSE` 既定に注意)。
   boolean は logical のまま(binomial の応答変数として R 側でそのまま扱える)
3. `stats::glm(formula, data, family)` を実行。`na.action` は既定の `na.omit`
   (= Complete Case Analysis)
4. `summary()` / `confint.default()` / `AIC()` 等から §3 の relation を組み立てて返す

### 設計上の決定事項

| 論点 | 決定 | 理由 |
|---|---|---|
| relation の渡し方 | SQL 文字列(text) | メモ・CLAUDE.md の仕様通り。呼び出し側の権限で SPI 実行されるため新たな権限昇格は生じない。regclass やカーソル渡しは将来の検討事項として TODO へ |
| NULL 処理 | Complete Case Analysis(`na.omit`) | R の `glm()` 既定と一致し、SQL の NULL セマンティクスにも整合。除外行数は `n_dropped` として出力に含め、暗黙に隠さない |
| 応答変数(binomial) | boolean または 0/1 整数を受け付ける | Running Example の `churn_flag (BOOLEAN)` に対応 |
| 信頼区間 | **Wald 型(`confint.default()`、正規分位点)** | R 既定の `confint()` は profile likelihood で計算コストが高く数値再現も難しい。MVP は Wald に固定し、論文・ドキュメントに明記。profile は TODO |
| `statistic` 列 | gaussian は t 値、binomial は z 値(R の `summary.glm` と同じ) | R との一致検証を最優先。列は1本とし、意味は family で決まることをドキュメント化 |
| link | MVP は family の canonical link に固定(gaussian=identity, binomial=logit) | `family => 'binomial(link=probit)'` 等の拡張は TODO |
| エラー処理(2026-07-08 実装確定) | family 不正・formula parse 失敗・formula が参照する列の不存在・0行 relation・R の fitting エラーは、`fit_glm:` 接頭辞付きの `pg.throwerror` で送出。**`pg.spi.exec` だけは tryCatch しない**: SPI エラーでトランザクションが abort した状態の上から R ハンドラでエラーを投げるとバックエンドがクラッシュするため、壊れた relation SQL は PostgreSQL ネイティブのエラーをそのまま伝播させる | 黙って NULL や空 relation を返さない。R 由来のメッセージ(例: 'y values must be 0 <= y <= 1')は情報量が多いので接頭辞付きで保持 |
| factor 処理(2026-07-08 確定) | 文字列列は `fit_glm()` 内で**明示的に** `factor()` へ変換する。levels は `factor()` のソート順、第1水準が参照水準(treatment contrast、R の `glm()` 既定と同じ) | PL/R は text を character で渡し、R >= 4 は自動 factor 化しない。`model.frame` の暗黙変換に任せず明示変換することで、挙動を決定的にし、将来の `predict_glm()` metadata(xlevels)がこの規約に依存できるようにする |

---

## 3. `fit_glm()` の出力 relation 設計

### 設計原則との関係

CLAUDE.md の通り、`fit_xxx` の出力は **1つの relation のみ**(閉包性の維持)。
term 粒度の列とモデル全体で1値の列を同居させ、後者は**全行に同じ値を繰り返す**。
これは正規化(モデル粒度とterm粒度の混在は関数従属の観点で第3正規形に反する)との
明示的なトレードオフであり、以下の理由で採用する:

- `fit` → `predict` → 可視化というパイプラインで relation を1つ受け渡すだけで済む
- `SELECT DISTINCT aic FROM logit_model` のようにモデル指標は SQL 側で自然に取り出せる
- relation を2つに分けると、閉包性(1 relation in / 1 relation out)が壊れ、
  FbSQL の最大の特徴を自ら手放すことになる

このトレードオフは論文の Discussion で正面から議論する。

### 列仕様

粒度: **1行 = design matrix の1列**(R の `summary()` の係数表と同じ)。
`(Intercept)` を含み、factor は非参照水準ごとに1行(例: `genderM`)。

| 列名 | 型 | 粒度 | 内容 |
|---|---|---|---|
| `term` | text | term | design matrix 列名。R の係数表の行名と一致 |
| `estimate` | float8 | term | 回帰係数 |
| `std_error` | float8 | term | 標準誤差 |
| `statistic` | float8 | term | t 値(gaussian)/ z 値(binomial) |
| `p_value` | float8 | term | p 値 |
| `conf_low_95` | float8 | term | 95%信頼区間下限(Wald) |
| `conf_high_95` | float8 | term | 95%信頼区間上限(Wald) |
| `family` | text | モデル | 'gaussian' / 'binomial'(全行同値) |
| `link` | text | モデル | 'identity' / 'logit'(全行同値) |
| `formula` | text | モデル | 入力 formula の文字列(全行同値) |
| `n_obs` | bigint | モデル | 入力 relation の行数 |
| `n_used` | bigint | モデル | Complete Case 後に学習へ使われた行数 |
| `n_dropped` | bigint | モデル | 除外行数(= n_obs − n_used) |
| `aic` | float8 | モデル | AIC |
| `deviance` | float8 | モデル | residual deviance |
| `null_deviance` | float8 | モデル | null deviance |

補足:

- 列名は R の `broom::tidy()`(`term`, `estimate`, `std.error`, `statistic`,
  `p.value`)と `glance()`(`aic`, `deviance`, `null_deviance`)の語彙に揃えつつ、
  SQL 識別子として `.` を `_` に置換した形。R ユーザーにも SQL ユーザーにも説明が容易。
- `n_obs` / `n_used` / `n_dropped` は fbrglm の `nobs_info`(complete-case の明示的
  な記録)の思想を relation の列として継承したもの。
- `link` は §4 の metadata 問題への最小限の布石として MVP から含める
  (コストがほぼゼロで、predict の逆リンク計算に必須のため)。
- **2026-07-08 の設計確定により、次回実装で 17 列目として `metadata jsonb` を追加する**
  (スキーマは §4 参照)。

---

## 4. `predict_glm()` を見据えた metadata 設計レビュー(未実装・論点整理)

### factor 対応(2026-07-08)で再確認された前提

fit 側の factor 対応により、以下が実装上の規約として確定した:
文字列列は fit 時に明示的に `factor()` 変換され、levels はソート順・第1水準が参照・
treatment contrast。**この規約こそが predict 時に再現すべき情報そのもの**であり、
係数表の `term` 列(design matrix 列名)には参照水準が現れないため、xlevels
(全水準集合)・contrast・列の型情報を metadata として保存する必要性が実装からも
裏付けられた。novel level ポリシーと合わせ、下記の選択肢検討(案A: JSONB)は不変。

### 問題

§3 の係数表だけでは将来の `predict_glm()` に不十分である。GLM の予測は
「学習時と**同一の** design matrix を新データ上で再構築 → Xβ → 逆リンク」であり、
再構築には係数以外の情報が必要になる。fbrglm が R 側で解決した問題
(`terms` / `xlevels` / `contrasts` の凍結と再利用)の relation 版と言える。

### 必要情報の棚卸し

| 情報 | 何に使うか | §3 の relation でカバーされるか |
|---|---|---|
| link function | 逆リンク変換 | ✅ `link` 列で保持 |
| formula / terms | design matrix の再構築(交互作用・変換含む) | △ `formula` 文字列はあるが、展開済み terms ではない |
| factor 水準(xlevels) | 学習時の水準全集合。参照水準の特定、novel level の検出 | ❌ 係数表には非参照水準しか現れない |
| contrast | factor → ダミー列の対応規則。セッション設定差異による drift 防止 | ❌ |
| variable type | 数値/factor/boolean の判定(新データで同じ型解釈を再現) | ❌ |
| design matrix 列名 | 係数と新データの列の突き合わせ | ✅ `term` 列がそのもの |
| novel level ポリシー | 未知水準に error / NA のどちらで応答するか | ❌(predict 側の引数とする案が有力) |

### 選択肢

- **案A: metadata を JSONB 列として同じ relation に追加**
  (例: `model_meta jsonb` に xlevels / contrasts / terms / 型情報を格納、全行同値)
  - 長所: relation は1つのまま(閉包性維持)。PostgreSQL ネイティブ型で可搬。
    `predict_glm` は係数表 relation だけ受け取れば完結する
  - 短所: フラットな関係モデルからの逸脱と見なされうる。論文でトレードオフの
    議論が1つ増える
- **案B: metadata 用の第2 relation を返す/別テーブルに保存**
  - 長所: 正規化としては素直
  - 短所: **1 relation in / 1 relation out の閉包性を破る**。FbSQL の核心と矛盾
    するため採用しない
- **案C: metadata をすべてフラット列に展開**(水準ごとの行を追加する等)
  - 長所: JSONB を使わない純粋な関係表現
  - 短所: 係数表と粒度の異なる行が混在し(term 行 + 水準行)、relation の意味論が
    濁る。交互作用・変換を含む terms の表現が事実上不可能

### 確定した設計(2026-07-08)

**案A を正式採用**: `fit_glm()` の出力に `metadata jsonb` 列を追加し、**17列**にする。

決定事項:

1. **列名は `metadata`**。`fbsql.glm_fit` 型の中では意味が自明で、出力リレーションは
   FbSQL が定義するため衝突リスクもない。
2. **全行に同一の JSONB を繰り返す**。AIC 等のモデル粒度スカラー列と同じ方針であり、
   「閉包性のための意図的な非正規化」として一貫する。
3. **スキーマはバージョン管理する**(`meta_version` フィールド)。JSONB 内部スキーマは
   事実上 API の一部になるため、互換性判定の手段を最初から埋め込む。
4. **フラット列と重複する情報は入れない**(単一情報源の原則)。`family` / `link` /
   `formula` / `n_obs` / `n_used` / `n_dropped` はフラット列から読む。唯一の例外は
   `coef_terms`(下記の通り整合性チェックという独自の役割を持つ)。
5. **novel factor level ポリシーは metadata に入れない**。これは学習時の事実ではなく
   予測時の選択なので、`predict_glm(on_new_levels => 'error' | 'na')`(既定 `'error'`、
   fbrglm の設計を踏襲)という**引数**として設計する。

#### JSONB スキーマ案(meta_version 1)

```json
{
  "meta_version": 1,
  "response": "y",
  "term_labels": ["x1", "gender"],
  "intercept": true,
  "data_classes": {"y": "numeric", "x1": "numeric", "gender": "factor"},
  "xlevels":   {"gender": ["F", "M", "Other"]},
  "contrasts": {"gender": "contr.treatment"},
  "coef_terms": ["(Intercept)", "x1", "genderM", "genderOther"]
}
```

| フィールド | R での由来 | `predict_glm()` が再現するもの |
|---|---|---|
| `meta_version` | —(FbSQL が付与) | スキーマ互換性の判定 |
| `response` | `terms(fit)` の応答変数 | 予測対象列名(出力列名 `<response>_predicted` の元にもなる) |
| `term_labels` | `attr(terms(fit), "term.labels")` | design matrix の再構築。formula 文字列の再パースに依存しないため、将来の SQL / C 実装でも解釈可能 |
| `intercept` | `attr(terms(fit), "intercept")` | Intercept 列の有無 |
| `data_classes` | `attr(terms(fit), "dataClasses")` | 新データ列の型解釈(character → factor 変換等を学習時と同一規約で再現) |
| `xlevels` | `fit$xlevels` | 水準全集合。参照水準の特定・novel level 検出・ダミー列の整合(係数表には参照水準が現れないため必須) |
| `contrasts` | `fit$contrasts` | factor → ダミー列の対応規則(現状 treatment 固定だが明示保存し、セッション設定差異による drift を排除) |
| `coef_terms` | `names(coef(fit))` | 係数の正準順序と完全性チェック。**行順序は保証されない**(順序独立性)ため、predict は `term` 列を名前で照合し、`coef_terms` と突き合わせて欠落・重複を検出する |

- gaussian・数値説明変数のみ: `xlevels` / `contrasts` は空オブジェクト `{}`
- binomial: 同一スキーマ(family / link はフラット列にあるため metadata には持たない)
- factor あり: `xlevels` / `contrasts` が埋まる

`predict_glm()` MVP(数値のみ)が必須とするフィールド: `coef_terms`, `intercept`,
`data_classes`。factor 対応時に `term_labels`, `xlevels`, `contrasts` を使う。

#### 既存テストへの影響

既存の pg_regress テストはすべて**明示的な列リスト**で SELECT しているため、17列目の
追加で expected は変わらない(`fit_glm_errors` の `SELECT *` は行を出力する前にエラーに
なるケースのみ)。metadata 専用テストを新設する(`jsonb_pretty(metadata)` で全体、
`metadata -> 'xlevels'` 等で個別フィールド。jsonb はキーが正規化されるため expected は
決定的)。

#### トレードオフの明文化(論文 Discussion 用)

- **別 relation(案B)**: 正規化としては綺麗だが「1 relation in / 1 relation out」の
  閉包性を破る — 不採用。
- **JSONB の行反復(案A)**: 非正規化だが、モデル粒度スカラー列と同じ「閉包性のための
  意図的トレードオフ」として一貫した説明ができる — 採用。
- **SQL からの参照・監査可能性**: `metadata -> 'xlevels'` のように標準の jsonb 演算子で
  モデルの学習時条件を検査できる。R/Python のモデルオブジェクトのブラックボックス性に
  対する FbSQL の回答であり、論文で積極的に主張できる点。
- **スキーマ安定性**: JSONB 内部スキーマは API の一部になる。`meta_version` で管理し、
  論文にもスキーマを明記する。

#### 次回実装(1回分の作業)

`fbsql.glm_fit` に `metadata` 列を追加(17列)し、`fit_glm()` で全フィールドを一括実装
(すべて fit オブジェクトから安価に取得できるため分割する理由がない)。
`fit_glm_metadata` テストを新設。extension は未リリースのため
`sql/fbsql--0.1.0.sql` を直接更新する(バージョンファイル分割は不要)。

---

## 5. テストデータ設計

### 方針

- **すべて手書きの決定的データ**(乱数不使用)。10〜20行の小テーブルとし、
  pg_regress の expected 出力の diff が人間に読めるサイズに保つ。
- 同一データを `test/sql/`(PostgreSQL 側)と `scripts/parity_reference.R`(R 側)
  の**両方に literal に定義**し、両者の出力を突き合わせる。
- 浮動小数点のプラットフォーム差を吸収するため、テストクエリでは
  `round(estimate::numeric, 4)` のように **4桁丸め**で比較する
  (ビット一致検証やベンチマークは FbSQL-experiments の担当)。

### テーブル案(fixture は各テストファイル冒頭の DDL で作成)

1. **`t_gaussian`** — gaussian 用(数値のみ)
   - 列: `y float8, x1 float8, x2 float8`、12行
   - 既知の線形関係 + 手書きの小さい残差(例: y ≈ 2 + 1.5·x1 − 0.5·x2)
   - 検証: 係数・SE・t値・CI・AIC が R と丸め一致
2. **`t_binomial`** — binomial 用
   - 列: `churn_flag boolean, age int`、16行(TRUE/FALSE が分離超平面を持たない
     よう混在させ、収束警告や完全分離を避ける)
   - 検証: logit の係数・z値が R と丸め一致。boolean 応答の受理
3. **`t_nulls`** — NULL / Complete Case 検証用
   - `t_gaussian` と同じ列構成で 15行、うち `x1` に NULL 2行・`y` に NULL 1行
   - 検証: `n_obs = 15, n_used = 12, n_dropped = 3` が正確に出ること、
     係数が「NULL 行を除いた12行での R の glm()」と一致すること
4. **`t_factor`** — factor 変数検証用
   - 列: `y float8, gender varchar`(3水準: 'F', 'M', 'X')、15行
   - 検証: term 名(`genderM`, `genderX`)と参照水準の扱いが R の既定
     (treatment contrast、アルファベット順の第1水準が参照)と一致すること

Running Example(`customer` テーブル)は論文・README のデモ用であり、
回帰テストの fixture とは分ける(テストは最小、デモは物語性を優先)。

### R との一致確認の仕組み

- `scripts/parity_reference.R`: 上記4テーブルと同一のデータを R 内で定義し、
  `stats::glm()` → §3 と同じ列名・同じ丸めのテーブルを標準出力に印字する
- 開発時はこの出力を目視で pg_regress の expected と突き合わせ、expected を確定する
- CI では pg_regress(installcheck)を必須とし、R スクリプトとの自動 diff は
  第2段階(TODO)とする

---

## 6. MVP で実装しないこと(再確認)

- `predict_glm()`(§4 の設計論点を確定してから)
- gaussian / binomial 以外の family、非 canonical link
- weights / offset(論文スコープ最小化のため意図的に除外)
- metadata(xlevels / contrasts / terms)の relation への格納
- C 実装・性能最適化(Non-goals: glm の高速化は主張ではない)
- META.json / PGXN 公開作業(実装とテストが安定してから)

---

## 次の実装ステップ(最小)

1. `docker/Dockerfile`: PostgreSQL + PL/R + R の開発環境を立ち上げ、
   `CREATE EXTENSION plr` が通ることを確認する(**すべての前提**)
2. `fbsql.control` + `Makefile` + 空に近い `sql/fbsql--0.1.0.sql` で
   `CREATE EXTENSION fbsql` が通る骨組みを作る
3. `fit_glm()` を gaussian のみで実装し、`t_gaussian` の pg_regress テスト1本と
   `parity_reference.R` で R と丸め一致することを確認する
4. binomial → NULL → factor の順にテストを増やす
