# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
実装・設計判断の詳細は `docs/` 配下の該当文書(`mvp-design.md`, `development.md`)を
参照し、本ファイルは要約に留める。

---

## 2026-07-09: Docker 公開の仕上げ(multi-platform + README 動作確認手順)

### Summary

- **multi-platform build 対応**: publish 部を buildx ベースに書き換え
  (`docker/setup-qemu-action@v3` + `setup-buildx-action@v3` +
  `build-push-action@v6`、`platforms: linux/amd64,linux/arm64`)。
  背景: Apple Silicon Mac で amd64 イメージの platform mismatch 警告
  (エミュレーションでは動作確認済みとの報告)。タグ規則は現行維持
  (latest + short SHA、tag push 時に version。GHCR / Docker Hub の
  全タグを1つの buildx push で発行)。amd64 のネイティブビルド +
  installcheck + 焼き込みスモークは従来どおり publish 前のゲートとして
  維持
- **README の Docker 節を更新**: `linux/amd64` / `linux/arm64` 対応を
  明記し、**最小動作確認 SQL ブロックを追加**(CREATE EXTENSION IF NOT
  EXISTS plr / fbsql → pg_extension 照会 → `SELECT fbsql.version();`)。
  組み込み `version()` と紛らわしいため「常にスキーマ修飾で書く」注記
  付き。Docker Hub namespace は実 pull で確認済みの `koki` を維持
- **表記ゆれ調査**: `fbsql_version` の残存は pg_regress の**テスト名**
  (Makefile REGRESS / test ファイル名 / dev-log の履歴)のみで、SQL
  関数表記としての誤用は README・docs にゼロ。テスト名は SQL 実装の
  一部のため変更しない(禁止事項とも整合)。`SELECT version()` の
  紛らわしい記述もゼロ
- `docs/development.md` に Apple Silicon 節を追記(警告の背景と
  multi-platform 公開後は解消される旨)

### Changed Files

- `.github/workflows/docker-build.yml`: buildx multi-platform publish
- `README.md`: multi-arch 明記 + 動作確認 SQL
- `docs/development.md`: Apple Silicon 注記

### Validation

- workflow YAML 構文 OK(python yaml)、ローカル docker build OK
  (Dockerfile 無変更・キャッシュ命中)。既存テストへの影響なし
  (SQL・テストは無変更)
- push 後の Actions 実行と multi-arch manifest はレポートで報告
  (arm64 は QEMU ビルドのため時間がかかる)

### Next Step

- Actions 成功後: `docker manifest inspect` で amd64/arm64 の両立を確認、
  Apple Silicon 側での再 pull 確認は利用者へ依頼。その後 PGXN 投稿準備

Commit: `Improve Docker distribution docs`(本エントリを含むコミット)。

---

## 2026-07-08: 本文圧縮(Shortening Pass)— 32→30ページ

### Summary

- 論理・章構成・図表を維持したまま **788語削減**(12,658 → 11,870語、
  ソース全体比 ~6%、本文プローズ比 ~10%)。**32 → 30ページ**(目標達成)
- **Related Work(最優先)**: 5システム段落を各2〜3文へ圧縮(設計思想・
  API・モデル表現・本論文との差のみ。細部挙動は "as shown in the
  experimental evaluation" への委譲で統一)。MADlib ~60%減、PostgresML
  ~45%減、Spark ~50%減、Hivemall ~40%減、H2O ~50%減。taxonomy・
  cross-cutting・Positioning は維持
- **Design Principles**(内容は不変、LD 済み内容への橋渡し化):
  Closure の ¶2〜4(17列の列挙・denormalization 詳説・既存システムの
  spectrum)を LD / RW / Discussion への参照付き短縮版に統合(~55%減)。
  Declarative / Order independence / NULL semantics の既存システム対比を
  各1文に。「From glm to a family」を3文へ(MAR の完全な文は LD の
  blockquote に一本化 — レビュー M4 の解消)
- **Language Design**: named-argument 段落を短縮(**"argument- order" の
  改行ハイフン事故もこれで解消** — レビュー Minor 1)。SQL 例・仕様説明は
  現状維持
- **Discussion**: Future work のみ ~35%短縮。他は不変
- サニティ確認: Figure 1〜4 / Table 1〜2 / MAR(6箇所 — 出現頻度維持の
  指示どおり)/ Affiliation / 定型節すべて健在、未解決引用ゼロ、
  全12文献キー使用継続

### Changed Files

- `paper/paper.Rmd`: 圧縮のみ(新規内容なし)

### Validation

- `make clean && make html && make jss` → 成功、**30ページ**
- 未解決引用・参照なし

### Next Step

- 更新版 paper-jss.pdf(30ページ)で ChatGPT 最終査読

Commit: `Tighten manuscript`(本エントリを含むコミット)。

---

## 2026-07-08: JSS 投稿前 polish(+ Docker publish の CI 結果確定)

### Summary

**Docker publish の完了確認**(前エントリの続き):

- 初回 CI は Docker Hub ログインで失敗 — **Secret 名は `DOCKER_PASS` では
  なく `DOCKER_PASSWORD`**(gh secret list で確認、fbrglm と同じ)。修正
  コミット `5c6b4ba` で **CI 完全成功**
- 検証: `ghcr.io/dsc-chiba-u/fbsql:latest`(+ short SHA)と
  `koki/fbsql:latest` を**匿名 pull 成功(両方 public)**、pull した
  イメージで mount なし CREATE EXTENSION fbsql CASCADE → version() 成功。
  **Docker Hub namespace は `koki` で確定** → README の TODO 解消

**JSS polish**(本文・図表内容は無変更):

- **Affiliation 完成**: render.sh の JSS 用 YAML に affiliation2 / address
  (`` `%`{=latex} `` トリック)を追加し、末尾の Affiliation ブロックが
  fbrglm と同形(3著者 × 複数所属 + E-mail、筆頭 = corresponding)で
  出力されることを確認(それまでは**空**だった)
- **references 整理**: h2o の TODO note 解消(accessed 日付に変更)、
  fbrglm を CRAN 表示の **version 0.0.1 に固定**、bib 冒頭コメント更新。
  未使用・重複なしは再確認済み(全12キー使用)
- **URL 整理**: Software availability の裸 URL(Replication material と
  重複)を文章参照に置換。本文の裸 URL は Replication material の
  2リポジトリのみに
- **verbatim の Overfull 解消**: header-includes で verbatim を
  `\begingroup\small ... \endgroup` 化(最初 `\small` のみで後続段落へ
  漏れて悪化 — グループ化で修正)。Running Example の出力ブロック由来の
  34〜76pt Overfull が全て解消
- 目視確認: 表紙(タイトル・3著者2行所属・Abstract・Keywords・
  マストヘッド)、Figure 2 ページ(余白・caption・白黒可読)、
  References、Affiliation ページ。**32ページ**

### 残る Warning(最終)

- Overfull 37: うち 31(10.95pt×23 + 5.47pt×8)は jss.cls のランニング
  ヘッダ/ページ番号由来(クラス仕様、fbrglm ドラフトと同種)。残り6件は
  2〜13pt の軽微な行(本文整形が必要なため未修正)
- Underfull 55(ページ組の badness、外観問題なし)
- Missing citation / reference: **0**
- `table.2` duplicate destination ×2(counter 補正の副作用、cosmetic)

### Changed Files

- `paper/render.sh`: affiliation2/address 追加、verbatim \small 化
- `paper/references.bib`: h2o / fbrglm / 冒頭コメント
- `paper/paper.Rmd`: Software availability の URL 重複解消のみ
- `README.md`: Docker Hub namespace TODO 解消(別コミット)
- `.github/workflows/docker-build.yml`: Secret 名修正(コミット `5c6b4ba`)

### 投稿前に残る TODO

- Zenodo DOI(両リポジトリ)、Acknowledgments の資金源・機関・個人名、
  keywords 最終確定、PGXN 投稿(公開後 Software availability 更新)

### Next Step

- 更新版 paper-jss.pdf(32ページ)で ChatGPT 最終査読 → 指摘反映

Commit: `Polish JSS manuscript`(本エントリを含むコミット)。

---

## 2026-07-08: Docker image 公開準備(GHCR + Docker Hub)

### Summary

- **Docker image の公開体制を整備**(fbrglm の build_test_push.yml の型を
  踏襲しつつ、PR では publish しない・テストを publish のゲートにする形に
  改良)
- `docker/Dockerfile`: **extension をイメージに焼き込み**(COPY Makefile /
  fbsql.control / sql → `make -C /opt/fbsql install`)。公開イメージを
  pull しただけで `CREATE EXTENSION fbsql` が動く。開発フロー(checkout を
  mount して make install)は上書きになるだけで無影響
- `.github/workflows/docker-build.yml` を拡張: build → installcheck →
  **焼き込みスモーク(mount なしで CREATE EXTENSION fbsql CASCADE +
  fbsql.version())** → main / tag push 時のみ GHCR(GITHUB_TOKEN)と
  Docker Hub(secrets: DOCKER_USERNAME / DOCKER_PASS)へ push。
  タグは `latest` + short SHA、tag push 時は version タグも。
  `workflow_dispatch` で手動実行可
- README Installation の Recommended (Docker) を **pull ファースト**に更新:
  `docker pull ghcr.io/dsc-chiba-u/fbsql:latest` + Docker Hub 併記
  (namespace は fbrglm の `koki/fbrglm` から `koki` と仮置き、TODO
  コメントで初回 publish 後の確認を明記)。mount + make install の手順は
  不要になったため run + CREATE EXTENSION に簡素化し、ローカルビルドは
  fallback として維持。Development 節の「published image が dev 環境を
  兼ねる」文言も同期
- 検証: workflow YAML 構文(python yaml)、ローカル再ビルド、
  **焼き込みイメージのスモーク成功**、`docker-installcheck.sh` 全11テスト
  green。push 後に Actions の publish 実行と GHCR pull を確認(下記)

### Changed Files

- `docker/Dockerfile`: extension 焼き込み
- `.github/workflows/docker-build.yml`: publish 対応へ拡張
- `README.md`: Installation を pull ファーストに更新

### Validation

- ローカル: baked image で mount なし CREATE EXTENSION → version() 成功、
  installcheck 11/11
- CI / GHCR pull の結果はコミット後に確認し本エントリの下に追記しない
  (レポートで報告)

### Next Step

- 初回 publish 後: Docker Hub namespace の確定 → README の TODO 解消、
  GHCR パッケージの public 化確認。その後 PGXN 投稿準備

Commit: `Publish Docker images`(本エントリを含むコミット)。

---

## 2026-07-08: 査読用 paper-jss.pdf の正式生成(+ ビルド起因の3欠陥修正)

### Summary

- `make clean && make jss` で**査読用 PDF(31ページ、A4)を正式生成**。
  本文・図表は無変更。検証で見つかった**ビルド起因の欠陥3件のみ**修正:
  1. **生成コメントの本文化**: tables/*.tex 先頭の `% Generated by ...` を
     pandoc が raw LaTeX と認識せず `\%` エスケープして Table 1 / 2 の
     直上に可視テキストとして組版していた → tab1 / tab2 チャンクで
     `^%` 行をフィルタして解消
  2. **表紙の所属行の重なり**: render.sh の JSS 用 YAML の affiliation が
     1行文字列のため3著者分が横に衝突 → fbrglm と同じ raw LaTeX 改行
     (`` `\\`{=latex} ``)を挿入し2行積みに修正
  3. **JSS マストヘッドのフォント代替**: `T1/pzc`(Zapf Chancery)未導入で
     ロゴ行が代替フォント幅により2行に折返し → Dockerfile の tlmgr に
     `psnfss` + `zapfchan` を追加(fbrglm の PDF と同等の表紙になった)
- **最終警告一覧**(render.sh と同一入力で log を採取):
  Missing citation / reference = **0**。Overfull 42(内訳: 22×10.95pt +
  8×5.47pt = jss.cls のランニングヘッダ/ページ番号のクラス由来、
  5×34.5pt + 1×40.2pt = Running Example の出力 verbatim ブロック、
  残り6件は 2〜13pt の軽微)。Underfull 52(ページ組の badness、外観
  問題なし)。pdfTeX: 図 PDF のバージョン通知×4(無害)、
  `table.2` の duplicate destination×2(`\addtocounter` 補正の副作用。
  リンク先が仕様表に飛びうる — 既知の cosmetic として記録)
- 内容確認: タイトル / 3著者(所属2行積み)/ Abstract / Keywords /
  Figure 1〜4 / Table 1〜2 / References / Replication material /
  Computational details / Software availability / Acknowledgments
  すべて表示。表紙・Table ページは画像で目視確認

### Changed Files

- `paper/paper.Rmd`: tab1 / tab2 チャンクの `%` 行フィルタのみ
- `paper/render.sh`: JSS 用 YAML の affiliation に改行挿入
- `paper/Dockerfile`: psnfss / zapfchan 追加

### Validation

- `make clean && make html && make jss` → 成功(31ページ)。
  `% Generated` の可視出力ゼロ、所属重なり解消、マストヘッド1行を
  ページ画像で確認
- 成果物 `paper/paper-jss.pdf` / `paper/paper.html` は working tree に
  残置(gitignore 対象。査読用に配布する)

### Known Issues

- Running Example の出力 verbatim ブロック(34〜40pt Overfull)は本文
  整形が必要なため未修正(次回の文言修正で幅を詰める候補)
- `table.2` duplicate destination(counter 補正の副作用)

### Next Step

- ChatGPT 査読レビューの結果待ち → 指摘反映。verbatim 幅の調整も同時に

Commit: `Fix submission PDF build artifacts`(本エントリを含むコミット)。
push 後の `git status`: 生成 PDF/HTML と .DS_Store を除き clean。

---

## 2026-07-08: README Installation の Docker ファースト化

### Summary

- README の Installation を3段構成へ整理:
  **Recommended (Docker)** → **Alternative (Build from source)** →
  **Future (PGXN)**。本体コード・論文は無変更
- **Recommended (Docker)**: GHCR 公開は将来と明記し("Docker images will
  be published through GHCR. Until then, build ... locally")、実在する
  手順のみ記載 — `scripts/docker-build.sh` + `scripts/docker-installcheck.sh`
  (「テストスイートは running example を verbatim 実行するので、green =
  論文のワークフローを end-to-end 再現」と明記)。対話的サーバ用に
  mount + `make install` + `CREATE EXTENSION fbsql CASCADE` の docker
  コマンド列を掲載し、**実機で end-to-end 検証済み**(CREATE EXTENSION →
  fbsql.version() 成功)。trust 認証は開発専用の注意書き付き
- **Alternative (Build from source)**: 旧 Requirements 以降をほぼ現状維持で
  移設(PostgreSQL / PL/R / R、PGXS `make install`、`CREATE EXTENSION`、
  superuser 注意)
- **Future (PGXN)**: 「planned」と慎重に表現(META.json / Changes 同梱の
  事実のみ)+ 公開後の `pgxn install fbsql` を予告
- Development 節に1文補足: fbsql-dev イメージはインストール用と開発用を
  兼ねる(別のランタイムイメージはまだ無い)
- 論文との整合を確認: Software availability(「README の記載どおり
  source checkout から PGXS でインストール」)、Replication material
  (conformance suite が論文の数値を再現)と矛盾なし

### Changed Files

- `README.md`: Installation の再構成 + Development 節の補足のみ

### Validation

- README 記載の Docker 対話手順を実機検証(temporary container で
  make install → CREATE EXTENSION fbsql CASCADE → fbsql.version())
- `scripts/docker-installcheck.sh` は CI と同一経路のため再実行省略

### Next Step

- GHCR への Docker イメージ公開(CI からの push 設定)→ README の
  Recommended を pull コマンドに更新、その後 PGXN 投稿準備

Commit: `Improve installation guide`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: JSS 定型節の完成(+ CLAUDE.md 更新)

### Summary

- **JSS 定型節4本を追加**し、原稿末尾の TODO コメントを解消。形式は
  fbrglm JSS ドラフトを踏襲(Replication material は番号付き §10、
  Computational details / Software availability / Acknowledgments は
  `{.unnumbered}`)
- **Replication material**: 2リポジトリの役割分担を明文化(FbSQL =
  extension + conformance suite(running example verbatim)+ Docker +
  原稿 / FbSQL-experiments = 比較環境・再現スクリプト・R parity・
  文献比較の出典・related_work.csv → Table 1/2 の生成)。「表は手編集
  しない」「再実行で差分が diff として現れる」「開発者固有パスなし」を
  明記。Zenodo DOI は投稿時挿入の TODO コメント
- **Computational details**: 再現環境のみ(PostgreSQL 16.14 / PL/R
  8.4.8.6 / R 4.2.2 / Docker / GitHub Actions で毎コミット pg_regress /
  比較3システムの固定バージョン / 原稿は rocker/verse 4.4.2 で単一 Rmd
  からレンダリング)。実装詳細は書かない
- **Software availability**: GitHub(MIT)+ PGXS インストール +
  **PGXN は planned と慎重に表現**(META.json 同梱の事実のみ)
- **Acknowledgments**: fbrglm を参考に PostgreSQL / PL/R 開発者、比較
  対象 OSS コミュニティ、Data Science Core(千葉大)、RIKEN AGIS を記載。
  資金源・共著者側機関(順天堂・中央)・個人名は投稿前確認の TODO
  コメント
- **references.bib 整理**: `postgresql` を新規追加(Computational
  details から引用)、`rcore` のバージョンを R 4.2.2 / 2022 に固定
  (TODO 解消)。全12キーの使用を確認 — 未使用・重複・欠落なし。
  fbrglm のバージョン表記問題(CRAN 0.0.1 vs メモ 0.1.0)は未固定の
  まま維持(投稿前検証項目)
- 追記(2回目の /init): CLAUDE.md 本文中に残っていた**旧設計の API 例を
  実装に同期**(`predict_glm` の `model => 'logit_model'` 名前渡し →
  SQL 文字列渡し + 列定義リスト)。ほか experiments 節の「今後作成」表記、
  比較対象リスト、fbrglm バージョン不一致の注記、英語ガイダンス行を修正
  (コミット `Sync CLAUDE.md API example with implementation`)
- 併せて **CLAUDE.md を現状に同期**(別コミット `03902e7`): 陳腐化した
  「現状」節の書き換え(グリーンフィールド→MVP 完了・論文初稿完成)、
  開発コマンド節(docker-build / installcheck / 単一テスト / paper build)、
  実装済みコードのハマりどころ節(pg.spi.exec 非 tryCatch、見出し `_`
  禁止、longtable カウンタ、render.sh 手動同期)を追加

### Changed Files

- `paper/paper.Rmd`: 定型節4本の追加のみ(本文・図表は無変更)
- `paper/references.bib`: postgresql 追加、rcore 固定
- `CLAUDE.md`: 上記(コミット `03902e7`)

### Validation

- `make html` → 成功(未解決引用なし)
- `make jss` → 成功(4節が正しい順序でレンダリング、{.unnumbered} も
  jss.cls で問題なし)
- `make clean` → 成功
- references: 全12キー使用済みを機械確認

### 投稿前に残る TODO

- Zenodo DOI(両リポジトリ、投稿時)→ Replication material へ挿入
- Acknowledgments の資金源・機関・個人名の確定
- fbrglm / h2o のバージョン表記確定、PGXN 投稿(公開後に
  Software availability を更新)
- render.sh と paper.Rmd の YAML 最終同期確認、keywords の最終確定
- レビュー残 Minor(paper-review-2026-07-08.md)

### Next Step

- 残 Minor の文言修正、または投稿メタデータ(資金源等)の本人確認待ち

Commit: `Complete JSS front matter`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: 論文全体の構成整理(章順・重複削減・用語統一)

### Summary

- 事前に実施した一貫性レビュー(`docs/paper-review-2026-07-08.md`、
  Major 5件 / Minor 11件)のうち、指示された4点を修正。新規本文なし
- **章順変更**: Running Example を Implementation の前へ移動
  (新順序: Intro → RW → DP → LD → **RE → Impl** → Eval → Discussion →
  Conclusion)。これによりレビュー M1 の相互参照矛盾4箇所
  (Impl "running example of the previous section" / "as the next section
  describes" / RE Summary の前方橋渡し / Eval "suite of the previous
  section")が**無修正で正しくなる**ことを確認。Intro 末尾のロードマップを
  新順序に更新。Figure 1〜4・Table 1〜2 の番号は出現順維持で無変更
- **相対参照の総点検**(行またぎ考慮で全 previous/next/above/below を
  監査)し3箇所を修正: RW の "principles of the previous section"(M2)→
  "introduced above and developed in the next section"、Impl と
  Discussion の "previous subsection" 2箇所(1つずれ)→ "described
  above" / "sketched above"
- **RW の実測記述を Evaluation へ集約**(M3): c105 無言スコアの詳細、
  ordinal encoding の実測値(F=1...)、RFormula 再パラメータ化の実測、
  handleInvalid='skip' の具体挙動を RW から削除し、"as shown in the
  experimental evaluation" 型の参照1文に置換。RW は設計思想・API・
  モデル表現のレビューに純化
- **SQL コード重複削減**(M5): LD の fit / predict のフル SQL を
  シグネチャレベル(内側クエリを `...` 省略、列定義リストは維持)に短縮し
  "in full in the *Running Example* section" を明記。フル SQL は RE のみ
- **用語統一**: model relation(fitted-model / model-shaped /
  glm_fit-shaped を置換)、execution engine(computation engine を置換)、
  conformance suite(regression / verification / parity suite 等 12箇所を
  統一)、scoring relation(data relation / the data to be scored)、
  formula semantics(formula and fitting semantics 等)、
  relation-in / relation-out(スペース入り表記に統一、見出しも変更)。
  Minimum Atomic Relation は指示どおり出現頻度を維持(削減なし)

### Changed Files

- `paper/paper.Rmd`: 上記の構成整理のみ
- `docs/paper-review-2026-07-08.md`: レビューメモ(前回作成分をコミット)

### Validation

- 修正後に全文再点検: previous/next 参照の残誤りなし(結合テキストで
  監査)、JSS PDF の章番号順(1〜9)・Figure 1〜4・Table 1〜2 の番号を
  pdftotext で確認、"In our measured runs" の残存 0
- `make html` → 成功(未解決引用なし)
- `make jss` → 成功
- `make clean` → 成功

### Known Issues(レビューの残項目 — 今回のスコープ外)

- DP 内の各原則ごとのシステム対比段落は残存(M3 の完全解消には DP の
  縮約が必要だが、今回は RW のみ指示)
- MAR の多重出現(M4)は指示により維持
- Minor: "argument- order" の改行ハイフン、PL/R 非新規性3回、
  R なし predict の存在証明4回、Codd 1970 と正規化の典拠問題 など
  (paper-review-2026-07-08.md 参照)

### Next Step

- JSS 定型節(Computational details / Acknowledgments / Replication
  material)の執筆、または残 Minor の文言修正

Commit: `Refine manuscript structure`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: 論文 Table assets の生成(experiments 側からの自動生成)

### Summary

- **Table 1(related work)と Table 2(customer dataset)を
  FbSQL-experiments 側から自動生成する体制を確立**。論文側
  (`paper/tables/`)には生成結果のみを置き、手編集しない方針を README
  に明記(生成コメントを各ファイル先頭に付与)
- 生成パイプライン: `data/related_work.csv` / `data/customer.csv` →
  `FbSQL-experiments/scripts/51_generate_paper_tables.R`(両リポジトリを
  マウントし FBSQL_ROOT で出力先指定)→ `paper/tables/*.{tex,md}`
  (.tex = LaTeX/JSS 用、.md = HTML 開発ビルド用。paper.Rmd のチャンクが
  出力形式で自動選択)
- **Table 1 は紙面向けに縮約**: 17次元 × 6システム、セルは短い判定語
  (yes / no / partial / TBD 等)+ 略記。**情報は削らず**、完全なセル文は
  CSV に残る旨と実測/文献の証拠区分を表脚注に記載。縮約は script 内で
  キュレーションし、**ドリフト検知**(縮約セルの判定語が CSV の先頭語と
  不一致なら生成を停止)で CSV と結合 — 初回実行で PostgresML の
  reproducibility セルの不整合を実際に検出し修正
- Table 2 は customer 17行を train(2025)/ scoring(2026)で
  midrule 区切り、NULL を明示。**R parity 表は省略**(本文 Evaluation が
  13/13 を明記しており表は不要と判断。README にその旨記録)
- **番号ズレの発見と修正**: Language Design の17列仕様表(キャプション
  なしの longtable)が LaTeX の table カウンタを1つ進め、customer 表が
  Table 3 になっていた → 仕様表直後に LaTeX 出力専用の
  `\addtocounter{table}{-1}`(HTML では no-op)を挿入して Table 1 / 2 に
  整合。**教訓: pandoc の無キャプション longtable もカウンタを進める**
- paper.Rmd の変更は最小限: Table 1 / 2 の include チャンク、prose への
  番号参照2箇所("rendered from it as Table 1" / "customer table
  (Table 2)")、counter 補正のみ。render.sh に tables/ コピーを追加

### Changed Files

- `paper/tables/{related_work,customer_dataset}.{tex,md}`: 新規(生成物)
- `paper/paper.Rmd`: 表チャンク配線 + Table 番号参照 + counter 補正
- `paper/render.sh`: tables/ を jss ビルドへコピー
- `paper/README.md`: 表は experiments 側から生成される旨を明記、
  assets 表を更新
- (FbSQL-experiments 側)`scripts/51_generate_paper_tables.R` 新規、
  README に Paper tables 節 — 別コミット

### Validation

- `make html` → 成功(Table 1 / 2 が markdown 表で表示)
- `make pdf` → 成功(weasyprint、警告のみ)
- `make jss` → 成功。**Table 1(p.4)と Table 2(p.20)のページを画像
  レンダリングで目視確認 — 幅超過・崩れなし**、番号も Table 1 / 2 で整合
- `make clean` → 成功、生成 tex/md はコミット対象、ビルド出力は残らない

### Known Issues

- 無キャプション longtable のカウンタ問題は `\addtocounter` で局所補正
  している。今後キャプションなしの表を追加する場合は同じ補正が必要
  (または表にキャプションを付ける)

### Next Step

- JSS 定型節(Computational details / Acknowledgments / Replication
  material)の執筆 — これで投稿形が整う

Commit: `Generate paper tables`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: Figure 2〜4 の作成と全図の本文配線

### Summary

- **Figure 2(running example)/ Figure 3(implementation layers)/
  Figure 4(system taxonomy)を Figure 1 と同一スタイルで作成**
  (各図 .R 生成ソース + SVG + PDF + .drawio の4形式。配色・フォント・
  線幅・角丸を Figure 1 の定数から踏襲、白黒印刷でも判別可能)
- Figure 2: customer relation を頂点に 2025 rows → fit_glm() /
  2026 rows → predict_glm() の二分岐、中央に Model relation(橙・強調、
  "the only state fitting hands to prediction")、右下に Prediction
  relation(churn_flag_predicted)。formula 文字列を明記。c104 NULL /
  c105 novel level は左下の小さな破線ノートに
- Figure 3: 上から Language specification("the fixed part")→
  PostgreSQL extension(fit = PL/R → stats::glm() / predict = PL/pgSQL
  no R、その境界に Model relation = "the boundary artifact")→
  Verification 層(pg_regress · R parity · Docker · CI、"any replacement
  engine must pass the same suite")
- Figure 4: 3群の類型図(In-database = FbSQL・MADlib・PostgresML /
  SQL-on-engine = Spark・Hivemall / SQL-adjacent = H2O)。各カードに
  呼び出し面と「モデルの所在」を1行ずつ。脚注 "a typology, not a
  ranking"。FbSQL カードのみ枠を model relation 色で控えめに強調
- **全4図を paper.Rmd に配線**: TODO コメントを knitr チャンク
  (`include_graphics`、latex 出力なら PDF / それ以外は SVG)+
  fig.cap(2〜4文、図の意味を説明する caption)に置換。図の配置は
  初出参照位置(Fig1 = §Design goals、Fig2 = §Relation representation、
  Fig3 = §Separation、Fig4 = §Comparative evaluation)で、LaTeX の
  自動番号が本文の Figure 1〜4 表記と一致することを確認。
  Evaluation に Figure 4 への1文参照を追加(許可範囲の最小変更)。
  html_document に fig_caption: true を追加
- **render.sh の jss ビルドに figures/ のコピーを追加**(一時ビルド
  ディレクトリに図が無く include_graphics が失敗するため)
- README の planned-assets 表を更新(4図 done、tables は TODO のまま)

### Changed Files

- `paper/figures/figure{2,3,4}_*.{R,svg,pdf,drawio}`: 新規(12ファイル)
- `paper/paper.Rmd`: 図チャンク + caption 配線、fig_caption 有効化、
  Figure 4 参照1文(本文の議論は無変更)
- `paper/render.sh`: figures/ を jss ビルドへコピー
- `paper/figures/figure1_system_overview.R`: caption 置き場コメント整理
- `paper/README.md`: planned-assets 表の更新

### Validation

- 3図とも生成成功、PDF を目視確認(Figure 2 はコホートラベルと矢印の
  重なりを1回修正)。drawio 3本は XML well-formed を確認
- `make html` → 成功(4図 SVG 埋め込み + caption 表示)
- `make jss` → 成功(**30ページ、Figure 1〜4 が caption 付きで正順に
  挿入**されることを pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 残る図表アセットは Table 2(customer)と比較表・parity 表の紙面版
  (experiments 側生成 → tables/ 取込み)のみ
- 図の caption は fig.cap(チャンクヘッダ1行)管理のため長文編集は
  やや不便(必要になれば bookdown の text reference へ移行を検討)

### Next Step

- 比較表(related_work)と Table 2 の紙面版生成(experiments 側)→
  paper への取込み、その後 JSS 定型節(Computational details 等)

Commit: `Add remaining paper figures`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: Figure 1(System Overview)の作成

### Summary

- **Figure 1(system overview)を3形式で作成**: 生成ソースの R(grid)
  スクリプト + そこから出力した SVG / PDF(ベクター)+ 手編集用の
  .drawio ソース。本文は無変更
- 作図方針: SVG→PDF 変換ツールが環境に無い(rsvg / inkscape / cairosvg
  不在)ため、**R grid で作図し同一ソースから svg() と cairo_pdf() を
  両出力**する方式を採用(fbsql-paper イメージ内で再生成可能 =
  再現性方針と一致)。drawio は同レイアウトを手書き XML で用意し
  well-formedness を検証済み
- 図の内容: 上層 = **FbSQL — the language**("every arrow is a relation")
  に Training relation → fit_glm() → **Model relation**(中央・橙・最太枠。
  term 行のミニ表 + metadata 帯 + "queryable · joinable · auditable ·
  self-contained")→ predict_glm()(Scoring relation が上から合流)→
  Prediction relation。下層 = 破線の **Reference implementation —
  PostgreSQL extension**("replaceable engine: the SQL above never
  changes")に PL/R → stats::glm() と PL/pgSQL — no R、中央に
  "future engines: C · GPU · distributed"。層間は破線コネクタ +
  "language / engine boundary" 注記。**PL/R より Model relation が
  目立つ**構成(指示どおり)
- Caption(2〜4文)を執筆し、図を本文へ配線するまでの置き場として
  R スクリプト冒頭コメントに保存
- `paper/README.md` に Figures 節を追記(生成ソース方式、再生成
  コマンド、drawio の扱い、「実験由来の図は experiments 側」の分担)
- 生成 PDF を目視確認(レイアウト崩れなし)

### Changed Files

- `paper/figures/figure1_system_overview.R` / `.svg` / `.pdf` / `.drawio`: 新規
- `paper/README.md`: Figures 節を追記

### Validation

- R スクリプト実行 → SVG / PDF 生成成功、PDF を目視確認
- drawio XML の well-formedness を python minidom で確認
- 本文(paper.Rmd)無変更のためビルドへの影響なし

### Known Issues

- paper/ に macOS の .DS_Store / ._.DS_Store が untracked で存在
  (コミットには含めていない。必要なら .gitignore 追加を検討)
- Figure 1 はまだ本文に取り込んでいない(paper.Rmd の TODO コメントは
  そのまま。取込み時に caption をスクリプトコメントから移す)

### Next Step

- Figure 2(running example)の作成、以後 Figure 3・4 → Table 2 と
  比較表の取込み → 図の本文配線

Commit: `Add system overview figure`(本エントリを含むコミット)。
push 後の `git status`: .DS_Store 系を除き clean。

---

## 2026-07-08: Conclusion 章の初稿執筆 — 本文完成

### Summary

- `paper/paper.Rmd` の **Conclusion 章のみ**を本文化。これで **Introduction
  〜 Conclusion の全9章 + Abstract が揃い、本文初稿が完成**
- Abstract の繰り返しにせず、subsection なしの4段落構成:
  (1) What was proposed — 冒頭文 "This paper proposed a language, not a
  package."。extension と glm 2関数は仕様を具体化・検証可能にするための
  存在であり主張ではない、estimator は「平凡だから選んだ」と再確認、
  (2) What was learned — 4つの設計知見(言語設計はエンジンと独立に
  議論・*検証*できる / model representation は実装詳細ではなく言語問題の
  核心(評価で観察した挙動差はすべてモデルの所在と記述方法に遡った)/
  relation 表現は予測・解釈・監査を単一 artifact で支える / 原則同士は
  衝突するので設計は明示的トレードオフの集合 — 言語提案が負うのは選択の
  不在ではなく文書化)。性能への言及なし、
  (3) Broader implications — Minimum Atomic Relation の問いを「この論文を
  超えて旅してほしい問い」として再提示。GLM = 係数、RF / GB = node 粒度、
  将来のモデルクラスにも先立つ問い。「DB 内統計モデリングは systems
  問題だけでなく言語問題である」という一般論で締め、
  (4) Future work は1段落のみ(Discussion 済みの3方向を1文で)
- 文献追加なし(引用なしの章)

### Changed Files

- `paper/paper.Rmd`: Conclusion 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 成功(冒頭文の反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### 本文全体で残っている TODO(コメント)

- 図表アセット7件: Figure 1(system overview)/ Figure 2(running
  example、参照2箇所)/ Figure 3(implementation layers)/ Figure 4
  (comparison taxonomy)/ Table 2(customer テーブル)/ 比較表の取込み
  (tables/related_work.tex + Table 番号参照への差し替え)
- JSS 定型節: Computational details / Acknowledgments / Replication
  material(末尾コメント)
- references.bib: rcore の R バージョン固定、fbrglm のバージョン表記
  (CRAN 0.0.1 vs メモ 0.1.0)の投稿前検証
- render.sh と paper.Rmd の YAML 手動同期(title / author / abstract /
  keywords)は執筆完了後の最終確認項目

### Next Step

- 図表アセットの作成(Figure 1〜4 は paper 用に作図、Table 2 と比較表は
  FbSQL-experiments 側で生成して取込み)、その後 JSS 定型節

Commit: `Draft conclusion section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Abstract + keywords の執筆

### Summary

- `paper/paper.Rmd` の **Abstract のみ**を本文化(233語。指示の 200〜250語
  内)。Conclusion は未着手のまま
- 指示どおりの5要素を1段落に: Background(DB 内統計モデリングの需要増 +
  「SQL言語としてどう書くか」は未検討)→ Objective(FbSQL の提案。
  「PostgreSQL extension は reference implementation であり、貢献は
  **SQL DSL = 言語設計**」を明文)→ Methods(5原則を design constraints に /
  formula 指定 / relation-in relation-out / モデル自体が relation で
  self-contained、model object 非露出)→ Results(R glm()/predict.glm()
  との一致、SQL のみの running example、MADlib / PostgresML / Spark との
  再現可能な比較 — **性能への言及なし**)→ Conclusion(glm は PoC、
  Minimum Atomic Relation の問いが GLM を超えて木系へ延びる)
- implementation details / Discussion / limitations は Abstract に不記載
  (指示どおり contribution のみ)
- **keywords 確定**: SQL, PostgreSQL, statistical modeling, formula
  interface, generalized linear models, domain-specific language, closure
  (候補にあった Bioinformatics は本論文と無関係のため不採用)
- **render.sh の JSS 用 YAML に abstract 全文と keywords を同期**
  (JSS PDF の表紙に Abstract / Keywords が正しく出ることを確認。
  abstract 内の glm() は JSS 側では \code{} 表記)

### Changed Files

- `paper/paper.Rmd`: YAML の abstract 本文化 + keywords 記載(コメント)
- `paper/render.sh`: JSS 用 YAML の abstract / keywords 同期

### Validation

- `make html` → 成功(abstract 反映確認)
- `make jss` → 成功(PDF の Keywords 行と abstract を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認
- abstract 語数 233(200〜250 の範囲内)

### Known Issues

- abstract が paper.Rmd と render.sh の2箇所管理(既知の手動同期点。
  変更時は両方を更新すること)
- 残る本文は Conclusion のみ + JSS 定型節(Computational details /
  Acknowledgments / Replication material)

### Next Step

- Conclusion 章の初稿(本文完成)。その後、図表アセットと JSS 定型節

Commit: `Draft abstract`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Discussion 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Discussion 章のみ**を本文化。冒頭で「新結果は
  なく、Design Principles 章が約束した accounting(トレードオフの清算)」
  と位置付け。前章までに Discussion へ送った参照6箇所をすべて回収
- 構成は指示どおり6小節: (9.1) One relation versus normalized relations
  (2粒度混在は正規化の教科書的分解対象と認めた上で「正規化と閉包性が
  衝突するとき FbSQL は一貫して閉包性を選び、意図的に代償を払う」。
  行数=term 数で反復コストは小さいが "not a free lunch" と明記)、
  (9.2) Metadata as part of the language(実装の便宜ではなく言語仕様:
  xlevels / term_labels / coef_terms / data_classes は predict のためでなく
  **relation を self-describing にする**ため。意味が session 状態でなく
  relation とともに移動する。meta_version = 解釈契約の互換ハンドル)、
  (9.3) SQL standard versus practical SQL(named notation は ISO 標準に
  ないと認めつつ、多引数統計関数には自然。BigQuery ML の文法拡張路線を
  設計上の対照として再言及(Related Work の予告を回収)。「将来の標準化
  議論への one data point」と最大限慎重な表現。標準 SQL は否定しない)、
  (9.4) Beyond GLM(Minimum Atomic Relation を再提示し、RF / LightGBM /
  XGBoost では node 粒度(tree/node/split/threshold/leaf/missing方向)。
  解釈は GROUP BY、予測は traversal として relation だけから再構築可能。
  「実装計画ではなく設計論」と明記)、(9.5) Limitations(**2種を区別**:
  意図的除外 = offset/weights/追加 family/非 canonical link(仕様作業)
  vs 真のギャップ = interaction・custom contrasts・prediction interval・
  class prediction・列定義リスト・single-node 実装(non-goal でも実害は
  あると正直に))、(9.6) Future work(roadmap でなく研究方向: 代替
  エンジン(C/GPU/分散、MADlib への委譲も適合性は parity で testable)、
  family → 木系、標準化しうる呼び出し構文、出力型推論、PGXN + アーカイブ)
- 文体: "we are right" 系を避け、design trade-off の語彙で通した
- 文献追加なし(codd1970relational / bigqueryml / hellerstein2012madlib
  を再利用)

### Changed Files

- `paper/paper.Rmd`: Discussion 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 成功(見出し `_` なし規約遵守)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 本文9章のうち残るは Conclusion のみ。Abstract(YAML)と keywords も未執筆
- Computational details / Acknowledgments / Replication material 節
  (JSS 慣行)が末尾 TODO コメントのまま

### Next Step

- Conclusion 章 + Abstract + keywords の初稿(それで本文完成。その後は
  図表アセット(Figure 1〜4、Table 取込み)と Computational details 等の
  JSS 定型節)

Commit: `Draft discussion section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Experimental Evaluation 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Experimental Evaluation 章のみ**を本文化。冒頭で
  「性能ベンチマークは報告しない(計算性能は主張の外)」と宣言し、
  評価を3つの問い(仕様適合 / PoC の end-to-end 動作 / 同一タスクが
  各システムで何を要求するか)として構成。観察のみを書き、解釈は
  Discussion へ送る文体を全節で徹底
- 構成は指示どおり4小節: (8.1) Conformance to R(本体テストとは独立に
  companion repo で再実行した parity **13/13 一致**。「継続的に検証される
  性質であって表明された意図ではない」)、(8.2) Running example end to
  end(fit / metadata が実際に予測を駆動 / NULL 行保持 / novel level の
  error と 'na' まで MVP 全面が1ワークフローで動作)、(8.3) Comparative
  evaluation(章の中心。MADlib 1.21.0 / PostgresML 2.7.12 / Spark 3.5.1
  の固定環境での再現。**設計差のみ**を記述: MADlib = 数値はほぼ同一
  (std_error 1個が第4位で相違 = IRLS 許容誤差)で差は interface 側 —
  手動 one-hot・位置配列・c105 の無言参照水準スコア(実測)。
  PostgresML = 数値一致は期待されない別仕様 — task+algorithm、class
  label 出力、ordinal encoding、NULL hard error、catalog 内 binary。
  Spark = 予測は4桁一致・係数表は reference level 差で再パラメータ化の
  範囲(数値検証済み)、skip の行落ち(5行→3行)、DataFrame closure)、
  (8.4) Summary(R compatibility / SQL language design(差は能力でなく
  設計)/ relation representation(端で観察された挙動はモデルの所在と
  記述方法に遡る)の3観察 + Discussion への橋渡し)
- 表の数値は本文で繰り返さず、related_work 比較表・parity CSV・
  per-system design notes CSV への参照で済ませた。Figure 4(3類型図)を
  参照し内容は TODO コメント
- 文献追加なし(システム名の引用も Related Work 初出で済んでいるため
  本章では再引用せず)

### Changed Files

- `paper/paper.Rmd`: Experimental Evaluation 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 成功(13/13 の記述反映を確認。見出しに `_` を使わない
  規約も遵守)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 比較表(Related Work)と parity 表の紙面取込みは未着手(prose 参照 +
  TODO のまま)。experiments 側で tables/*.tex を生成してから差し込む
- Spark の c104/c105 が NULL になる経路(summary CSV 上は一致扱い)は
  本文で言及していない(手元で経路を確認していないため安全側に倒した)

### Next Step

- Discussion 章の初稿(非正規化・JSONB・列定義リストのトレードオフ、
  named arguments と標準 SQL、木系 Atomic Relation、C 実装展望、
  weights/offset の意図的除外)

Commit: `Draft experimental evaluation section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: PostgreSQL Extension Implementation 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Implementation 章のみ**を本文化(コード非掲載、
  「どう実装したか」でなく「なぜその実装を選んだか」に徹する。冒頭で
  「以下の決定はすべて replaceable であり、固定部は言語」と宣言)
- 構成は指示どおり5小節: (7.1) Reference implementation(PL/R 採用理由 =
  **conformance, not novelty**。仕様が R 参照で定義されているため R を
  内部エンジンにすれば by construction で適合。PL/R は新規性でなく
  「最速の誠実な経路」。untrusted language の superuser 要件も記録)、
  (7.2) **Separation of language and execution engine**(章の中心。
  仕様 = シグネチャ/formula 意味論/17列/metadata スキーマ/エラー方針、
  エンジン = それを満たす任意の機構。層間の界面が*データ*であることが
  分離を実質化する。C / GPU / MADlib バックエンド / 分散エンジンへの
  置換で SQL は不変、適合性は検証スイートで testable。Figure 3 参照 +
  TODO コメント)、(7.3) Fitting(「R を呼ぶ」でなく「R を oracle に
  relation を生成する」と読む。明示的 factor 変換・Wald CI の決定も
  仕様の一部として記録。R オブジェクトは関数終了で消滅)、
  (7.4) **Prediction without R**(PL/pgSQL のみ。R なし実装が R の予測を
  4桁一致で再現できること = model relation の自己完結性の existence
  proof、と強調。SPI-abort の教訓を1段落: relation SQL の失敗は R 側で
  ラップせずネイティブエラーを伝播 — 「埋め込みインタプリタはホストの
  トランザクション意味論に従うべき」)、(7.5) Verification strategy
  (pg_regress 11本 = 仕様の executable conformance tests / R parity =
  同一フィクスチャを SQL と R に literal 定義し4桁丸めで固定 / Docker
  固定環境 / GitHub Actions で毎コミット検証 / running example 自体が
  回帰テスト = 論文中の全数値が継続的に再検証される)
- **make jss の障害を1件解消**: jss.cls は見出しテキストを PDF bookmark
  のアンカー名にそのまま書き込む(`\pdfbookmark[2]{#1}{Subsection...#1}`)
  ため、見出し `## fit_glm()` の `\_` が `Missing \endcsname` で pdflatex
  を停止させる。見出しを「Fitting: generating the model relation」
  「Prediction without R」に変更して回避(本文中の関数名は無変更。
  Rmd に理由コメントを残置)。**教訓: JSS ビルドでは見出しに `_` を
  含めない**
- 文献は既存のみ(plr, rcore)。新規追加なし

### Changed Files

- `paper/paper.Rmd`: Implementation 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 見出し修正後に成功(existence proof 段落の反映を確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 見出しに `_` を含めると jss ビルドが壊れる(jss.cls の制約)。
  今後の章・改稿でも見出しへの関数名リテラルは避けること
- Computational details 節(R / PostgreSQL / PL/R のバージョン明記)は
  JSS 慣行として執筆時に追加予定(現在は本文でバージョン非固定)

### Next Step

- Experimental Evaluation 章の初稿(experiments の実測結果:
  parity 13/13、MADlib / PostgresML / Spark の再現と設計差の観察)

Commit: `Draft implementation section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Introduction 章の初稿執筆(+著者情報の反映を記録)

### Summary

- `paper/paper.Rmd` の **Introduction 章のみ**を本文化(見出しなしの
  流れる4段落構成。JSS 慣例に合わせ subsection は使わない)
- 指示どおりの流れ: (1) DB 内での統計解析の需要増(MADlib / PostgresML /
  Spark MLlib / Hivemall / H2O に軽く言及、BigQuery ML は需要の証左として
  触れるのみ。比較はしない)→ (2) 既存システムは computation に集中
  (scalability / algorithm coverage / deployment)— "legitimate and
  different design objectives" と明記し否定しない → (3) **中心の問題提起**:
  SQL は言語であり、formula での指定・fit が返すもの・モデルの所在・
  prediction の形という言語設計の問いは「SQL としてどう書くべきか」として
  正面から扱われてこなかった。FbSQL の提案を1文で予告(閉包性を hard
  constraint に。glm は PoC、PL/R で glm を呼べること自体は貢献でない)→
  (4) 貢献4項目(5原則の明文化とレビューレンズ / FbSQL の言語仕様と
  Minimum Atomic Relation / R-parity で固定した PostgreSQL extension
  reference implementation / running example + 5システム比較評価)+
  論文構成の道案内1文
- 禁止表現は不使用("make different trade-offs" / "emphasize" 等で統一)
- 文献は既存のみ(hellerstein2012madlib, postgresml, meng2016mllib,
  hivemall, h2o, bigqueryml, codd1970relational, chambers1992statistical,
  plr)。新規追加なし
- 記録: 直前のコミット `4e2ade1` で著者情報を fbrglm 形式の3著者
  (Tsuyuzaki / Sakamaki / Nishiuchi)に更新済み(指示により dev-log
  追記なしの単独コミットだったため、ここに記録を残す)

### Changed Files

- `paper/paper.Rmd`: Introduction 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 成功(貢献列挙段落の反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- Abstract は未執筆(YAML 内 TODO のまま)。keywords も未確定
- 末尾の道案内文は現在の章順(Implementation → Running Example →
  Evaluation)を前提にしている。章順を変える場合は要修正

### Next Step

- Implementation 章の初稿(PL/R fit、R なし PL/pgSQL predict、pg_regress +
  R parity の検証規律、SPI-abort の教訓)— これで残る本文は
  Implementation / Experimental Evaluation / Discussion / Conclusion +
  Abstract

Commit: `Draft introduction section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Running Example 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Running Example 章のみ**を本文化(利用者視点の
  ウォークスルー。Implementation の内容には立ち入らず、他章は TODO のまま)
- 冒頭で「この例は擬似コードではなく `test/sql/running_example.sql` として
  回帰テストに同梱され、全数値は R と4桁一致で検証済み」と宣言し、
  **掲載した数値・出力・エラーメッセージはすべて実測値**
  (係数表 = expected 出力、予測値 = parity CSV、novel level エラー文言 =
  expected 出力、xlevels = metadata テスト・エラー文言と整合)
- 構成は指示どおり5小節: (6.1) Dataset(customer の5列と 2025学習→2026予測
  シナリオ、c104 NULL age / c105 unseen level を「production scoring の現実」
  として導入。Table 2 は TODO コメントのみ)、(6.2) Model fitting(1文の SQL、
  relation / formula / family の3引数に集中、metadata は軽く言及)、
  (6.3) Prediction(モデルを**データとして**渡す点を強調、c104 = NULL 予測、
  c105 = 既定 error の実エラー文言 → 'na' で当該行のみ NULL。
  「unseen level の扱いは caller の決定」という設計思想を簡潔に)、
  (6.4) Inspecting the fitted model(FbSQLらしさ: DISTINCT で model 指標、
  metadata -> 'xlevels' で参照水準 F が見える、term での JOIN による
  モデル比較、「serialize も method call も system state もない」)、
  (6.5) Summary(4文の SQL で完結 / 実装に非依存 = 言語境界が機能している
  証拠、として Implementation 章への橋渡し)
- Figure 2 をこの章から参照(図の内容は TODO コメント。作図せず)。
  query 出力は Table 資産ではなく fenced block(psql 風)で掲載
- 文献追加なし

### Changed Files

- `paper/paper.Rmd`: Running Example 章の本文化のみ

### Validation

- `make html` → 成功。未解決引用なし
- `make jss` → 成功(c105 / Nonbinary の本文反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- AIC 等の実数値は parity CSV に含まれないため、6.4 では**数値を出さず**
  クエリのみ提示(未検証値は載せない方針)。必要になれば experiments 側で
  実測してから差し替える
- 6.4 の JOIN 例(logit_model_2026)は説明用のクエリパターンであり
  出力は掲載していない(実在しないテーブルのため)

### Next Step

- Implementation 章の初稿(PL/R fit、R なし PL/pgSQL predict、pg_regress +
  R parity の検証規律、SPI-abort の教訓)

Commit: `Draft running example section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: FbSQL Language Design 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **FbSQL Language Design 章のみ**を本文化(論文の中核章。
  他章は TODO のまま)。冒頭で「実装ではなく言語仕様の章」と宣言し、
  PL/R・Docker・CI 等は Implementation 章へ委譲
- 構成は指示どおり5小節: (4.1) Design goals(5原則→4目標+2関数のシグネチャ
  提示、Figure 1 参照)、(4.2) Formula-based model specification(relation /
  formula / family の分業、R formula 採用理由3点 + **セマンティクスを R の
  glm() への参照で固定することで仕様が testable になる**という主張、
  named argument を normative style として明記)、(4.3) Relation
  representation(章の中心。17列仕様表、relation で返す3つの帰結 =
  composition / inspectability / implementation independence、意図的
  非正規化、metadata jsonb は**回帰テストの実測出力をそのまま**掲載し
  meta_version・単一情報源・coef_terms の役割を明文化)、(4.4) Prediction
  interface(2 relation 入力 → 1 relation 出力、モデルは名前解決ではなく
  データとして渡す = 純関数、SETOF record の制約を明示、on_new_levels は
  「予測消費者の決定であり学習時の事実ではない」から metadata でなく引数、
  fbrglm からの設計継承を明記)、(4.5) Generalization beyond GLM
  (Minimum Atomic Relation の問いを引用ブロックで再提示、木系の
  node-grain relation を素描)
- Figure 1(system overview)/ Figure 2(running example)を本文から参照し、
  図の内容を TODO コメントで具体的に記述(図はまだ作らない)
- `references.bib` に **fbrglm を1件追加**(CRAN 掲載を WebFetch で確認。
  バージョンは CRAN 表示と手元メモが食い違うため note には記載せず)
- **make jss の障害を1件解消**: 本文初の表(17列仕様表)で pandoc が
  booktabs を要求し `booktabs.sty` 不足で LaTeX が停止 →
  `paper/Dockerfile` の明示インストール一覧へ booktabs / multirow を追加し
  イメージ再ビルドで解決(skeleton warm-up は表を含まないため検出できて
  いなかった)

### Changed Files

- `paper/paper.Rmd`: Language Design 章の本文化
- `paper/references.bib`: fbrglm エントリ追加
- `paper/Dockerfile`: booktabs / multirow を LaTeX 焼き込みに追加

### Validation

- `make html` → 成功。未解決引用(`[@key]` / `???`)なし
- `make jss` → 成功(booktabs 追加後。paper-jss.pdf 313KB、
  Minimum Atomic Relation / fbrglm の本文反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- metadata JSONB の例は運用例(churn)ではなくテストフィクスチャ
  (`y ~ x1 + gender`)の実測値。Running Example 章執筆時に churn モデルの
  実測 metadata に差し替えるか検討(未検証値は載せない方針を維持)
- fbrglm のバージョン表記が CRAN(0.0.1)と CLAUDE.md(0.1.0)で不一致 —
  投稿前の文献検証時に要確認

### Next Step

- Implementation 章の初稿(PL/R による fit、R なし PL/pgSQL の predict、
  pg_regress + R parity の検証規律、SPI-abort の教訓)

Commit: `Draft language design section`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: Related Work 章の初稿執筆

### Summary

- `paper/paper.Rmd` の **Related Work 章のみ**を本文化(他章は TODO のまま)。
  構成は指示どおり3部: (1) 類型(in-database SQL-ML = MADlib・PostgresML /
  SQL-on-engine ML = Spark MLlib・Hivemall / SQL-adjacent ML = H2O-3 +
  Sparkling Water、BigQuery ML は非OSSのため除外と簡潔に説明)、
  (2) Design trade-offs(章の中心。5原則を軸に各システムが何を重視し
  何を委譲・犠牲にしているかをレビュー)、(3) Positioning of FbSQL
  (優劣ではなく "differs in its design objective"。既存要素の
  conjunction を目指す点が新しいという位置付け。スコープの狭さを代償として明記)
- **実測と文献の区別を本文で明示**: MADlib(1.21.0/PG11)・PostgresML
  (2.7.12/PG15)・Spark(3.5.1)は "measured"(running example を
  FbSQL-experiments の固定 Docker 環境で再現)、Hivemall・H2O は
  "literature based"(公式ドキュメント由来、未実行、出典は companion repo に
  記録)と冒頭で宣言し、各段落でも再掲
- 比較表は本文で重複説明せず、FbSQL-experiments の `data/related_work.csv`
  (19次元)へ委譲。tables/related_work.tex の取込みと Table 相互参照は
  TODO コメントで明示
- 語彙は指示どおり(adopts / emphasizes / delegates / preserves /
  makes different trade-offs。violate / superior / flawed 不使用)
- `references.bib` に **bigqueryml を1件追加**(公式ドキュメント URL を
  WebFetch で実在確認済み。docs.cloud.google.com へのリダイレクトを反映)。
  重複なし

### Changed Files

- `paper/paper.Rmd`: Related Work 章の本文化
- `paper/references.bib`: bigqueryml エントリ追加

### Validation

- `make html` → 成功。未解決引用(`[@key]` / `???`)なし、BigQuery ML の
  本文 + References 反映を確認
- `make jss` → 成功(paper-jss.pdf、本文反映を pdftotext で確認)
- `make clean` → 成功、生成物が git に残らないことを確認

### Known Issues

- 比較表の紙面向け縮約版(tables/related_work.tex)は未作成 — 生成は
  experiments 側の担当。取込み後に本文の prose pointer を Table 番号参照へ
  差し替えること(Rmd 内 TODO コメント)
- Hivemall の interaction / offset / weight / NULL、PostgresML の
  interaction / offset / weight は表上 TBD のまま(本文では言及せず安全側に倒した)

### Next Step

- Language Design 章(fit/predict のシグネチャ、formula、named arguments、
  Minimum Atomic Relation、metadata jsonb スキーマ)の初稿

Commit: `Draft related work section`(本エントリを含むコミット)。
push 後の `git status`: clean。

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
