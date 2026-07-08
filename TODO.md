# TODO

意図的に延期した機能と未決事項の backlog。MVP のスコープは `docs/mvp-design.md` を参照。

## MVP(次に着手する順)

- [x] `docker/Dockerfile`: PostgreSQL + PL/R + R の開発環境(`CREATE EXTENSION plr` が通ること)
      — 2026-07-08 検証済み: PostgreSQL 16.14 + PL/R 8.4.8.6 + R 4.2.2(`docs/development.md`)
- [x] `fbsql.control` + `Makefile`(PGXS)+ `sql/fbsql--0.1.0.sql` の骨組み(`CREATE EXTENSION fbsql`)
      — 2026-07-08 完了: fbsql.version() ダミー関数 + pg_regress 1本 + CI組込み済み
- [x] `fit_glm()` gaussian 実装 + `t_gaussian` の pg_regress テスト + `scripts/parity_reference.R`
      — 2026-07-08 完了: R の stats::glm() と全16列一致(4桁丸め)を確認
- [ ] `fit_glm()` binomial 対応 + `t_binomial` テスト
- [ ] NULL / Complete Case テスト(`t_nulls`: n_obs / n_used / n_dropped の検証)
- [ ] factor テスト(`t_factor`: term 名・参照水準が R の既定と一致)
- [ ] `.github/workflows/regress.yml`(Docker イメージ上で installcheck)

## MVP 後(実装順未定)

- [ ] `predict_glm()` — metadata 格納形式(JSONB 案A)の確定が先行条件(下記「未決事項」)
- [ ] family 追加(poisson → Gamma → その先は論文スコープと相談)
- [ ] 非 canonical link(`binomial(link=probit)` 等)の family 指定記法
- [ ] profile likelihood 信頼区間(MVP は Wald 固定)
- [ ] R スクリプトと pg_regress expected の自動 diff を CI に追加
- [ ] `META.json` + `Changes` の整備、PGXN 公開チェックリスト
- [ ] `FbSQL-experiments` リポジトリの作成(ベンチマーク・関連システム比較・論文用テーブル生成)
- [ ] `paper/` に JSS 原稿の骨組み(fbrglm の paper/ 構成を踏襲)
- [ ] Zenodo DOI アーカイブ(本体 + experiments、投稿時)

## 未決事項(実装前に決める)

- [ ] **predict 用 metadata の格納形式**: JSONB 列(案A)を第一候補とするが、
      xlevels / contrasts / terms の具体的なスキーマは `predict_glm()` 着手時に確定
      (`docs/mvp-design.md` §4)
- [ ] **novel factor level ポリシー**: `predict_glm(on_new_levels => 'error'|'na')` 案
      (fbrglm の設計を踏襲)で良いか
- [x] **関数の名前空間**: 解決(2026-07-08) — 正式APIは `fbsql.fit_glm()`。
      `public.fit_glm()` は作らない。README・論文では `SET search_path TO fbsql, public;`
      で短く書けることを示す(`docs/mvp-design.md` §2)
- [ ] **relation 引数の受け渡し形式の拡張**: SQL 文字列(MVP)に加えて regclass
      (テーブル名直接指定)を許すか
- [ ] **CI のベースイメージ**: PL/R 入り PostgreSQL の公式イメージは存在しないため、
      自前ビルド(docker/Dockerfile)を GHCR に push して CI から使う構成にするか
- [ ] **サポートする PostgreSQL バージョン範囲**(PL/R のビルド可否に依存)
- [ ] **R のバージョン方針**: 開発イメージの R は 4.2.2(Debian bookworm)。MVP には
      十分だが、論文の Computational details でどのバージョンを報告するか、上げる
      場合の手段(ソースビルド / backports)を実装安定後に検討

## 論文の Discussion に書くこと(実装しない)

- モデル全体で1値の指標を全行に繰り返すトレードオフ(閉包性 vs 正規化)
- Named Argument(`=>`)は標準 SQL ではないことと、標準への示唆
- C 実装の展望
- 木系アンサンブル(`fit_rf` / `fit_lgbm` / `fit_xgb`)の Atomic Relation 設計例
- weights / offset を初回論文から意図的に除外した理由
