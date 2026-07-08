# TODO

意図的に延期した機能と未決事項の backlog。MVP のスコープは `docs/mvp-design.md` を参照。

## MVP(2026-07-08 全タスク完了)

- [x] `docker/Dockerfile`: PostgreSQL + PL/R + R の開発環境(`CREATE EXTENSION plr` が通ること)
      — 2026-07-08 検証済み: PostgreSQL 16.14 + PL/R 8.4.8.6 + R 4.2.2(`docs/development.md`)
- [x] `fbsql.control` + `Makefile`(PGXS)+ `sql/fbsql--0.1.0.sql` の骨組み(`CREATE EXTENSION fbsql`)
      — 2026-07-08 完了: fbsql.version() ダミー関数 + pg_regress 1本 + CI組込み済み
- [x] `fit_glm()` gaussian 実装 + `t_gaussian` の pg_regress テスト + `scripts/parity_reference.R`
      — 2026-07-08 完了: R の stats::glm() と全16列一致(4桁丸め)を確認
- [x] `fit_glm()` binomial 対応 + `t_binomial` テスト
      — 2026-07-08 完了: logit リンク、z値・AIC 含め R と一致。boolean 応答も検証
- [x] NULL / Complete Case テスト(`t_nulls`: n_obs / n_used / n_dropped の検証)
      — 2026-07-08 完了: 15行中3行除外(n_obs=15, n_used=12, n_dropped=3)を回帰テスト化
- [x] factor テスト(`t_factor`: term 名・参照水準が R の既定と一致)
      — 2026-07-08 完了: genderM / genderOther、参照水準 F、R と全列一致
- [x] `.github/workflows/regress.yml`(Docker イメージ上で installcheck)
      — `docker-build.yml` が build + installcheck を実行する形で実現済み(別ファイル不要)

## MVP 後(実装順)

- [x] `fit_glm()` に `metadata jsonb` 列(17列目)を実装 + `fit_glm_metadata` テスト新設
      — 2026-07-08 完了: meta_version 1 の全フィールド、既存テストは expected 無変更で通過
- [x] `predict_glm()` MVP 第1段階(数値のみ・gaussian・PL/pgSQL 実装)
      — 2026-07-08 完了: SETOF record + 呼び出し側列定義。R の predict.glm() と一致
- [ ] `predict_glm()` 第2段階: binomial(逆リンク logit)対応
- [ ] `predict_glm()` 第3段階: factor 対応(xlevels / contrasts の消費、
      `on_new_levels => 'error'|'na'` 引数、novel level 検出)
- [ ] PL/R エラーの1行目(`R interpreter expression evaluation error`)を整形できるか調査
      (メッセージ本体は DETAIL に出ており実害は小さい。優先度低)
- [ ] family 追加(poisson → Gamma → その先は論文スコープと相談)
- [ ] 非 canonical link(`binomial(link=probit)` 等)の family 指定記法
- [ ] profile likelihood 信頼区間(MVP は Wald 固定)
- [ ] R スクリプトと pg_regress expected の自動 diff を CI に追加
- [ ] `META.json` + `Changes` の整備、PGXN 公開チェックリスト
- [ ] `FbSQL-experiments` リポジトリの作成(ベンチマーク・関連システム比較・論文用テーブル生成)
- [ ] `paper/` に JSS 原稿の骨組み(fbrglm の paper/ 構成を踏襲)
- [ ] Zenodo DOI アーカイブ(本体 + experiments、投稿時)

## 未決事項(実装前に決める)

- [x] **predict 用 metadata の格納形式**: 決定(2026-07-08) — `fit_glm()` 出力の
      17列目として `metadata jsonb` を追加(全行同値)。スキーマは meta_version 1:
      response / term_labels / intercept / data_classes / xlevels / contrasts /
      coef_terms(フラット列と重複する family 等は持たない)。`docs/mvp-design.md` §4
- [x] **novel factor level ポリシー**: 決定(2026-07-08) — metadata ではなく
      `predict_glm(on_new_levels => 'error'|'na')` の引数とする(既定 'error'、
      fbrglm の設計を踏襲)
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
