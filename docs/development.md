# 開発環境(PostgreSQL + PL/R + R)

FbSQL の開発・テストは Docker で固定した環境上で行う。ホストに PostgreSQL や R を
インストールする必要はない。

## 構成の選定理由

- ベースイメージは **`postgres:16-bookworm`**(PGDG 公式)。
- PL/R は **apt パッケージ `postgresql-16-plr`** を使う。PL/R のソースビルドは
  PostgreSQL / R のバージョン組み合わせに敏感なため、MVP 段階では安定性を優先して
  パッケージ版に固定する(ソースビルドへの切り替えは必要になってから検討)。
- R は `r-base-core`。`fit_glm()` が使うのは `stats::glm()`(base R)のみなので、
  追加の R パッケージは不要。
- `postgresql-server-dev-16` + `make` を同梱しており、将来この同じイメージ内で
  PGXS による `make install`(`CREATE EXTENSION fbsql`)と `pg_regress`
  (`make installcheck`)を実行できる。

検証済みの組み合わせ(2026-07-08、`scripts/check-plr.sh` にて確認):

| コンポーネント | バージョン |
|---|---|
| PostgreSQL | 16.14(PGDG, Debian bookworm) |
| PL/R | 8.4.8.6(`postgresql-16-plr` 1:8.4.8.6-1.pgdg12+1) |
| R | 4.2.2 Patched(Debian bookworm の `r-base-core`) |

R 4.2.2 は最新ではないが、MVP が使うのは base R の `stats::glm()` のみなので問題
ない。R のバージョンを上げたくなった場合(例: 論文の Computational details 用)は
ソースビルドか backports の検討が必要になる(TODO.md 参照)。

## 使い方

```bash
# 1. イメージをビルド(初回のみ。R が入るためイメージはやや大きい)
scripts/docker-build.sh

# 2. PL/R の動作確認(一時コンテナを起動し、確認後に破棄)
scripts/check-plr.sh
```

`check-plr.sh` は以下を検証する:

1. `pg_available_extensions` に `plr` が存在すること
2. `CREATE EXTENSION plr;` が通ること
3. PL/R 関数経由で R が実際に実行されること(`R.version.string` の取得)

開発用に DB を立ち上げたままにする場合:

```bash
scripts/docker-run.sh          # フォアグラウンドで起動(Ctrl-C で停止)
psql -h localhost -U postgres  # ホスト側から接続(trust 認証、開発専用)
```

初回起動時に `docker/initdb/10-plr.sql` が実行され、デフォルト DB に `plr` が
インストールされた状態になる。

## 注意点

- **PL/R は untrusted language** であり、`CREATE EXTENSION plr` および PL/R 関数の
  定義には superuser 権限が必要。このイメージでは `postgres` superuser で作業する。
- `POSTGRES_HOST_AUTH_METHOD=trust` は開発専用の設定。この構成のまま外部公開しないこと。
- CI(`.github/workflows/docker-build.yml`)は現段階ではイメージのビルドが通ることの
  確認のみ。pg_regress を CI で回すのは Extension の骨組みができてから
  (`TODO.md` 参照)。
