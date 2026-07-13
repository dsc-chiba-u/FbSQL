# VLDB Journal 転針プラン(2026-07-13)

> **状況(2026-07-13 実施済み)**: ユーザー決定 — JSS は放棄(ビルドも
> 削除)、マイクロベンチ実施。**Phase 0〜6 をすべて実施完了**
> (詳細は docs/dev-log.md の同日エントリ)。残りは Phase 7
> (全体一貫性レビュー → 共著者レビュー)と投稿前 TODO
> (Declarations の確定、ORCID、Zenodo DOI)。

共著者フィードバック(西内さん 2026-07 Slack)への対応計画。
関連: 根津さんの助言 — VLDB 系は旧来 DB 世界観の査読者が多く、新規性は
「なぜそれが必要か」を背景から丁寧に説明する必要がある(参考:
https://www.vldb.org/pvldb/vol13/p3531-tanabe.pdf)。

## 受け取ったフィードバック(要約)

1. 投稿先を JSS → **The VLDB Journal**(Springer, ISSN 1066-8888)へ
2. **Minimum Atomic Relation(MAR)は新規性の核** — Abstract でも押す
3. **Figure 1 の内容(言語/エンジン分離、model relation 中心)も Abstract で触れる**
4. Intro / Design Principles / Discussion で **Codd・Date・Darwen** を引用し
   SQL/DB 界隈に刺さる形へ
5. (根津さん)新規性の必要性を DB 側の前提から丁寧に動機付けること

## 判断が必要な点(着手前にユーザー確認)

- **JSS 版を捨てるか併走するか**: 推奨は「main は VLDB 版へ転針、JSS 用
  ビルド(render.sh jss)は当面残す」(ビルドは2系統方式なので共存可能)
- **性能実験の追加可否**: VLDB 査読者は実験を期待しがち。主張は言語設計で
  性能は Non-goal(CLAUDE.md)だが、「fit/predict のオーバーヘッド測定
  (PL/R 呼び出しコスト vs 素の R、predict の SQL 実行計画)」程度の
  マイクロベンチを FbSQL-experiments に足して防御するかは要判断
- 投稿区分: The VLDB Journal は regular paper / special issue がある。
  regular を想定

## 段取り(各フェーズ = 1セッション、毎回 dev-log + push)

### Phase 0: 体裁・要件調査(小)
- The VLDB Journal の投稿要件を確認(Springer LaTeX テンプレート
  svjour3 と思われる — 要確認、ページ規範、double-blind か否か、
  reproducibility/availability の慣行)
- `make vldb` ターゲットの設計(render.sh に第3パイプライン。
  rticles::jss_article と同様に一時コピー + テンプレート差し替え方式。
  jss ターゲットは削除せず残す)
- 出口: paper/README.md にビルド3系統を記載、空テンプレートで
  `make vldb` が通る状態

### Phase 1: 文献の増強(小〜中)
- 追加候補(**すべて原典を検証してから** references.bib へ):
  - Codd 1971/1972(正規化の原典)— Discussion 9.1 の「正規化の典拠に
    Codd 1970 を使っている」既知の不正確さもこれで解消
  - Date & Darwen, *The Third Manifesto*(D への回帰、SQL 批判の代表)—
    Design Principles の「原則への忠実さ」議論と Discussion の
    SQL standard 節に接続
  - Date の NULL / 三値論理批判(*Database in Depth* または
    *An Introduction to Database Systems*)— NULL semantics 節で
    「NULL には DB 理論側からの根本批判があるが、FbSQL は SQL の現実の
    意味論に準拠する立場」と明示すると DB 読者に誠実
  - (要検討)Stonebraker 系の in-DB analytics 論文、MADlib の前身
    "MAD Skills"(Cohen et al., PVLDB 2009)
- 出口: bib 追加 + 引用箇所のマーキング(本文改稿は Phase 3-4)

### Phase 2: Abstract 改訂(小)
- MAR を新規性の核として明示(問いの文を Abstract に入れる — 現在も
  入っているが「novelty の核」としての位置づけを強く)
- Figure 1 の内容 = 「言語仕様と実行エンジンの分離、境界を渡るのは
  model relation という*データ*だけ」を1文追加
- 200〜250語を維持。render.sh の JSS 用 YAML と(新設する)VLDB 用
  YAML の同期を忘れない

### Phase 3: Introduction の DB 読者向け再動機付け(中)
- 根津助言の反映が主目的。現在の「言語の問い」フレーミングは維持しつつ、
  DB 側の前提から積み上げる:
  1. リレーショナルモデルの価値(closure/composability)は DB 界の共有財
     (Codd; Date & Darwen)
  2. in-DB ML は実在の需要で各社が実装済み(現行段落)
  3. しかしそれらは「モデル」を relation の外に置いた —
     composability の喪失という *DB 的コスト* の明示
  4. 問い = MAR。「なんでそんなものが必要なの?」への直接回答を
     Introduction 段階で1段落用意(監査・再現・パイプライン合成の
     具体ペイン)
- Contributions に MAR を第一項目として繰り上げることを検討

### Phase 4: Design Principles / Discussion の理論接続(中)
- 各原則に Codd/Date/Darwen の議論を1〜2文で接続(長文化させない。
  圧縮パスの成果を維持)
- Discussion「SQL standard versus practical SQL」に Third Manifesto を
  対置(「D 派は SQL 自体を捨てる。FbSQL は SQL の中で原則を守る道を
  選んだ」という位置取り — DB 読者に最も刺さる差別化)
- NULL semantics に Date の批判への言及を追加

### Phase 5: 体裁の VLDB 化(中)
- 定型節の付け替え: JSS 流(Computational details / Replication
  material)→ VLDB Journal の慣行に合わせ再配置(Reproducibility 節等。
  内容はほぼ流用可)
- 図表・running example は不変。jss.cls 固有の注意(見出し `_` 禁止等)が
  svjour3 で不要になるかを確認
- `make vldb` で全文が通る状態に

### Phase 6(要判断): オーバーヘッド・マイクロベンチ(中、experiments 側)
- 実施する場合: fit_glm vs 素の R glm() の実行時間、predict_glm の
  行数スケーリングを FbSQL-experiments に追加(シード・環境固定の規律)
- 「性能を主張しない」立場は維持し、「言語層のオーバーヘッドが実用範囲で
  あること」の防御材料としてのみ提示

### Phase 7: 全体一貫性レビュー → 投稿版生成
- 転針後の全読(paper-review の再実施)、VLDB 用 PDF の正式生成、
  共著者レビューへ

## 変わらないもの

- 本体 Extension・実験・比較表・図(内容)・Running Example
- 「主張は言語設計、glm は PoC」の核(むしろ MAR を前面に出すことで強化)
- 2リポジトリ体制、再現性の規律、dev-log 運用
- PGXN リリース準備(保留中。論文転針と独立に再開可能)

## リスク・留意

- VLDB Journal は査読が長い(1年超もある)— JSS 併走オプションを
  残す理由
- 「実験がない」指摘への防御線: 設計比較の再現性 + (Phase 6 実施なら)
  オーバーヘッド測定 + R parity。それでも regular paper としては
  評価文化と相性の議論が残る — 共著者と投稿区分を相談
- 引用追加はすべて原典検証後(未確認文献を入れない従来方針)
