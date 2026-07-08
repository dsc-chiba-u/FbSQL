# 論文一貫性レビュー(2026-07-08、JSS査読者視点)

`paper/paper.Rmd` 全体(Intro〜Conclusion + Abstract、初稿完成時点
= commit `2478de6`)の通読レビュー。**本文は未修正**。修正方針の決定用。

---

## Major issues(必ず直す)

### M1. 章順と相互参照の矛盾(最重要)

物理的な章順は「… → Implementation(§5)→ Running Example(§6)→
Evaluation(§7)」だが、本文の相互参照は **Running Example →
Implementation → Evaluation の順を前提**に書かれている。矛盾4箇所:

1. Implementation §Verification:
   "the running example **of the previous section** is itself one of the
   regression tests" — 実際は*次*の章
2. 同節末尾: 比較システムでの再現を "as **the next section** describes"
   — 実際の次章は Running Example、該当内容は2章先の Evaluation
3. Running Example §Summary: Implementation 章へ**前方**への橋渡しとして
   書かれている("The *PostgreSQL Extension Implementation* section
   describes ...")— 実際は既読の章
4. Evaluation §Conformance: "the `pg_regress` suite **of the previous
   section**" — 実際の前章は Running Example

**Running Example と Implementation を入れ替えれば4箇所すべて同時に
正しくなる**(利用者視点→内部という流れとしても自然。当初のタスク指示の
章番号 6.x=RE / 7.x=Impl とも一致)。入れ替えない場合は4箇所書き換え。
入れ替える場合は Introduction 末尾のロードマップ文(章列挙の順)も要修正。
図表番号への影響なし(Fig 1→2→3→4 の出現順・Table 1→2 とも維持される)。

### M2. Related Work の「previous section」誤り

RW 冒頭 "through the lens of the five design principles **of the previous
section**" — Design Principles は RW の*後*(§3)。文言修正
("developed in the next section" 等)か、章構成改善案②(DP 前置)で解消。

### M3. 実測知見の三重記述

同じ実測観察が **Related Work・Design Principles・Evaluation の3箇所**で
ほぼ同じ詳細度で登場:

- c105 の無言参照水準スコア(RW / Eval でほぼ逐語重複)
- PostgresML の ordinal encoding(F=1, M=2, Other=3 の数値まで2回)
- PostgresML の NULL hard error
- RFormula の頻度基準参照水準
- handleInvalid='skip' の行落ち

所有権を決める。推奨: RW は文献的・設計記述+前方参照のみとし、
"In our measured runs..." の段落群は Evaluation に一本化。DP 各原則内の
システム言及は1文のポインタに縮約。

### M4. Minimum Atomic Relation の問いが実質6回

完全な文として4回(DP §From glm / LD §Generalization の blockquote /
Discussion §Beyond GLM / Conclusion ¶3)+ Abstract + Introduction。
**LD の blockquote を正典**とし、他は短い後方参照へ。特に
DP「From glm to a family of modeling functions」と
LD「Generalization beyond GLM」は節として内容がほぼ同一 — 統合候補。

### M5. SQL コードブロックの逐語重複

- fit の `CREATE TEMPORARY TABLE logit_model AS ... fit_glm(...)` が
  LD §Formula-based と RE §Model fitting に一字一句同じ形で2回
- predict の SQL も近似重複(LD 版と RE 版の差は c105 除外と round のみ)

LD 側はシグネチャ+短縮形にし、フル SQL は RE へ一本化するのが自然。

---

## Minor issues(できれば直す)

1. **改行ハイフン事故**: LD §Formula-based 末尾
   "the argument- order half"(ソースの行またぎ `argument-` + `order`)
2. **「PL/R は新しくない」を3回宣言**(Intro / DP 冒頭 / Impl)。
   期間表現も不統一("has long been possible" / "for many years" /
   "for two decades")。Implementation の1回に集約推奨
3. **「predict は R なし = 存在証明」を4回**(DP §Closure / Impl /
   RE §Summary / Conclusion)。Impl を正典に、他は軽く
4. **検証スイートの呼称が5種**: "pg_regress regression suite" /
   "conformance suite" / "verification suite" / "parity suite" /
   "the suite"
5. **Codd 1970 を正規化の典拠に使用**(Discussion 9.1)— 正規形の定式化は
   1971 以降。投稿前の文献検証で要確認
6. **Figure 2(running example の図)が §4 LD に物理配置** —
   データセット説明(§Dataset・Table 2)より大幅に前。M1 の章入れ替え時に
   Fig 2 を RE へ移す案も検討(その場合 Fig 2/3 の番号入れ替えが必要)
7. Intro "evaluates it against **five** open-source systems" — 実測は3、
   2つは文献ベース。"three by experiment, two from documentation" 等の
   限定が誠実
8. Discussion 9.1 と 9.2 の末尾が近似文(代替案棄却の理由を2回)
9. "three decades"(formula の実績)が Intro と LD で反復
10. Evaluation 冒頭で「解釈は Discussion へ」と宣言しつつ §Summary で
    軽く解釈("confirming that the differences at issue are design
    choices")— 許容範囲だが要自覚
11. DP 冒頭の節構成宣言("the different trade-offs made by existing
    systems" を各原則で扱う)は、M3 の縮約を行うなら合わせて修正

---

## 用語統一候補

| 統一候補(推奨形) | 現在の別表現(出現箇所例) |
|---|---|
| **model relation** | "fitted-model relation"(DP §Order indep.)/ "model-shaped relation"(RE)/ "`glm_fit`-shaped relation"(LD)/ "term-grain coefficient relation"(Discussion・Conclusion — 意図的なら可) |
| **execution engine** | "computation engine"(Conclusion)/ "estimation engine" / "internal engine" / "fitting engine"(Impl・図) |
| **conformance suite**(検証スイート) | 上記 Minor 4 の5種 |
| **scoring relation** | "data relation"(LD §Closure)/ "the data to be scored"(DP) |
| **formula semantics (fixed to R's `glm()`)** | "R semantics" / "formula and fitting semantics" / "R's formula semantics" |
| **relation-in/relation-out** | 見出しのみ "relation in, relation out"(表記だけ揃える) |
| statistical modeling DSL | "SQL DSL" は本文でほぼ未使用(Abstract は "domain-specific language for SQL")— どちらかに寄せる |
| Minimum Atomic Relation | ✅ 全箇所一貫 |
| reference implementation | ✅ ほぼ一貫 |
| metadata (column) | ✅ 一貫("metadata contract" は Discussion のみ、許容) |

---

## 重複している節(まとめ)

1. DP「From glm to a family…」≈ LD「Generalization beyond GLM」≈
   Discussion「Beyond GLM」≈ Conclusion ¶3(MAR と木系一般化)
2. DP「Closure」後半(非正規化+metadata)≈ LD「Relation
   representation」後半 ≈ Discussion 9.1 / 9.2
3. RW「Design trade-offs」の実測段落群 ≈ Evaluation「Comparative
   evaluation」(+ DP 各原則の対比段落)
4. fit / predict の SQL コードブロック(LD と RE)
5. PL/R 非新規性の宣言(Intro / DP / Impl)
6. R なし predict の存在証明(DP / Impl / RE / Conclusion)

---

## 章構成としての改善案

**推奨**:

- **① Running Example ↔ Implementation の入れ替え**(小手術)—
  M1 の4矛盾を一挙解消。ユーザー視点→内部→評価の流れも良化
- **② Design Principles を Related Work の前へ移動**(①と合わせて中手術)—
  M2 が自然に解消し「レンズを定義してからレビューする」構成になる。
  DP からシステム個別記述を抜いて RW に集約する M3 の整理とも噛み合う
  (CLAUDE.md の構成案「5つの設計原則による Related Work レビュー」とも
  整合)

いずれの場合も、変更後に全「previous/next section」参照・Intro
ロードマップ・図表番号の再監査が必要。

---

修正範囲の選択肢: (a) ①のみ+文言修正、(b) ①+②+重複整理(M3〜M5)、
(c) 文言修正のみ。
