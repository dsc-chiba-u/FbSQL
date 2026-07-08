# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
実装・設計判断の詳細は `docs/` 配下の該当文書(`mvp-design.md`, `development.md`)を
参照し、本ファイルは要約に留める。

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
