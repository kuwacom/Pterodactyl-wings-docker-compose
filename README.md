# 🚀 Pterodactyl Wings with Docker Compose

[Pterodactyl Wings](https://pterodactyl.io/) を Docker Compose + Cloudflare Tunnel で簡単に構築するためのリポジトリです

> [!NOTE]
> Pterodactyl Panel（管理画面）はこちら -> [kuwacom/pterodactyl-panel-compose](https://github.com/kuwacom/pterodactyl-panel-compose)

## 📋 前提条件

| 項目 | 要件 |
|------|------|
| **OS** | Docker が動作する環境（Linux 推奨） |
| **Docker** | Docker Engine + Docker Compose（v2 推奨） |
| **Cloudflare** | Cloudflare アカウント + 管理済みドメイン |
| **Panel** | [pterodactyl-panel-compose](https://github.com/kuwacom/pterodactyl-panel-compose) で Panel が構築済みであること |

## 📦 セットアップ手順

### 1. リポジトリをクローン

```bash
git clone https://github.com/kuwacom/pterodactyl-wings-compose.git
cd pterodactyl-wings-compose
```

### 2. `.env` ファイルを作成

```bash
cp .env.example .env
```

`.env` をエディタで開き、以下の変数を自分の環境に合わせて編集してください

#### Cloudflare Tunnel 設定

| 変数 | 説明 |
|------|------|
| `TUNNEL_TOKEN` | Cloudflare Tunnel のトークン（後述の手順で取得） |
| `TUNNEL_TRANSPORT_PROTOCOL` | 通信プロトコル（`http2` を推奨） |

#### Wings 設定

| 変数 | 説明 |
|------|------|
| `SFTP_PORT` | SFTP 用ポート（`config.yml` の `system.sftp.bind_port` と同じ値にすること） |
| `VOLUME_PATH` | ゲームサーバーデータの保存先（`config.yml` の `system.data` と同じ値にすること） |

### 3. `docker-compose.yaml` の構成を確認

Wings はコンテナ内で動作しますが、Wings により生成されるゲームサーバーコンテナはホスト側の Docker デーモンで起動されます（兄弟コンテナモデル）

そのため、ゲームサーバーのデータ本体である `data`（`VOLUME_PATH`）と、インストールプロセス等で使用される `tmp_directory` は、ホスト側とコンテナ側で同じ絶対パスにする必要があります
これはゲームサーバーコンテナにバインドマウントする際、ホスト側 Docker デーモンに対してホストパスを指定するためです

それ以外のディレクトリ（`root_directory` / `log_directory` / `archive_directory` / `backup_directory`）は Wings コンテナ内のみで完結するため、ホスト側パスは自由に設定可能です
本構成では `./pterodactyl/` 配下にまとめています

> [!WARNING]
> **ディスク構成について**
> `data`（`VOLUME_PATH`）はゲームサーバーのデータ・バックアップ・アーカイブが格納されるため、容量を大きく消費します
> 本番運用では `VOLUME_PATH` を OS ディスクとは別のディスク（別マウントポイント）に配置することを強く推奨します
> ディスク枯渇で OS 自体が停止するのを防ぎ、I/O の分離にもなります

> [!NOTE]
> **複数ディスクを使いたい場合**
> `data` は単一パスしか指定できないため、複数ディスクを扱いたい場合は mergerfs 等で1つの仮想ボリュームに統合してから `VOLUME_PATH` にマウントしてください
> シンボリックリンクでの分散は Wings のパス検証と競合するため推奨されません

### 4. Pterodactyl Panel で Node を追加

Pterodactyl Panel にて Node 追加を行い、Wings 用の config を取得しましょう

> [!IMPORTANT]
> **追加の際、以下の設定を行ってください**
> - **`Behind Proxy`**: `Behind Proxy` を選択（Cloudflare Tunnel 経由で接続するため）
> - **`Daemon Port`**: `443` のまま（Panel が Wings にアクセスする際のポート）
>
> `Behind Proxy` を有効にすると、Panel が生成する config.yml で `api.ssl.enabled` が `false` になります
> これにより Wings 側で TLS 証明書が不要になり、`create-pem.sh` の実行も不要になります
> Wings は 443 ポートで HTTP をリッスンし、Cloudflare Tunnel が TLS を終端します

> [!IMPORTANT]
> **`FQDN` は Cloudflare Tunnel で設定した公開ドメインにしてください**

次に、取得した Wings 用 config の以下の項目を書き換え、`./pterodactyl/config.yml` として保存してください

> [!NOTE]
> Panel から取得できる config には `docker.network` セクションが含まれていません
> このセクションは Wings 側で独自に設定する項目のため、手動で追記してください

```yaml
api:
  host: 0.0.0.0  # バインドしたいアドレス空間がある場合は制限してください
  port: 443      # Panel の Daemon Port と同じ値。Behind Proxy 有効時は HTTP でリッスンします
  ssl:
    enabled: false  # Behind Proxy 有効時は false になります

system:
  # config.yml / lib / log を ./pterodactyl/ にまとめるため、
  # root_directory と log_directory を /etc/pterodactyl/ 配下に変更する
  root_directory: /etc/pterodactyl/lib
  log_directory: /etc/pterodactyl/log

  # data は .env の VOLUME_PATH と同じ値にすること
  data: /volumes

  archive_directory: /etc/pterodactyl/lib/archives
  backup_directory: /etc/pterodactyl/lib/backups
  tmp_directory: /tmp/pterodactyl

  # 通常プランのCloudflare TunnelではSFTPは転送できないため、
  # 別ルートでのアクセスを構成する場合はここを変更してください
  sftp:
    bind_address: 0.0.0.0
    bind_port: 2022  # .env の SFTP_PORT と同じ値にすること
    read_only: false

  # machine_id はゲームサーバーコンテナに /etc/machine-id をマウントする機能です
  # Hytale がトークン暗号化に machine-id を必要とするため追加された機能で、
  # デフォルトは有効です。Hytale を実行しない場合は無効化を推奨します
  # 有効にする場合は、directory を VOLUME_PATH 配下などホストと共有されるパスに
  # 変更してください（ゲームサーバーコンテナにバインドマウントされるため）
  machine_id:
    enabled: false
    directory: /run/wings/machine-id

# Wings は起動時に Docker API を経由してゲームサーバー隔離用ネットワーク
# `pterodactyl_nw`（bridge名: pterodactyl0）を作成します
# デフォルトのサブネット 172.18.0.0/16 がインスタンス自体の所属ネットワーク等と
# 重複する場合は、重複しないサブネットに変更してください
docker:
  network:
    interface: 10.0.0.1
    name: pterodactyl_nw
    network_mode: pterodactyl_nw
    driver: bridge
    is_internal: false
    enable_icc: true
    network_mtu: 1500
    interfaces:
      v4:
        subnet: 10.0.0.0/16
        gateway: 10.0.0.1

remote: <Pterodactyl Panel のURL httpsが好ましい>
allowed_origins:
  - <Pterodactyl Panel 及び、その他WEBUIのorigin URL>
  - https://example.com
```

### 5. Cloudflare Tunnel で公開する

Cloudflare Tunnel のダッシュボードで、Wings API を公開する Public Hostname を追加します

1. トンネルの **Public Hostname** タブを開く
2. **Add a public hostname** をクリック
3. 以下を入力:

   | 項目 | 設定値 |
   |------|--------|
   | **Subdomain** | 任意（例: `wings`） |
   | **Domain** | Cloudflare で管理済みのドメインを選択 |
   | **Path** | 空 |
   | **Service Type** | `HTTP` |
   | **URL** | `localhost:443`（`config.yml` の `api.port` に合わせる） |

4. **Save hostname** をクリック

> [!NOTE]
> cloudflared コンテナは Wings コンテナのネットワークに所属しているため、`localhost:443` で Wings API にアクセスできます
> Cloudflare↔cloudflared 間は TLS で暗号化されるため、Wings 側で TLS 証明書は不要です

### 6. Docker Compose で起動

```bash
docker compose up -d
```

## 🔧 オプション: TLS を Wings で終端する

本構成では Cloudflare Tunnel が TLS を終端するため、Wings 側で TLS 証明書は不要です
しかし、Cloudflare Tunnel を経由せず直接 Wings に HTTPS で接続したい場合は、以下の手順で Wings 側で TLS を終端できます

### 1. Panel の `Behind Proxy` を無効にする

Panel の Node 設定で `Behind Proxy` を `Not Behind Proxy` に変更します
これにより、Panel が生成する config.yml で `api.ssl.enabled` が `true` になります

### 2. オレオレ証明書を作成する

```bash
bash ./create-pem.sh
```

`./certs/` 配下に `fullchain.pem` と `privkey.pem` が生成されます

### 3. config.yml の SSL 設定を有効にする

```yaml
api:
  host: 0.0.0.0
  port: 443
  ssl:
    enabled: true
    cert: /etc/certs/fullchain.pem
    key: /etc/certs/privkey.pem
```

### 4. Cloudflare Tunnel の Service Type を `HTTPS` にする

Cloudflare Tunnel の Public Hostname 設定で以下を変更します

| 項目 | 設定値 |
|------|--------|
| **Service Type** | `HTTPS` |
| **URL** | `localhost:443` |

**Additional application settings** -> **TLS** を展開し、**No TLS Verify** を有効化します
Wings はオレオレ証明書を利用するため、TLS 検証を無効化する必要があります

## 🌐 アクセス先

| サービス | URL |
|----------|-----|
| **Wings API** | Cloudflare Tunnel で設定した公開ドメイン（例: `https://wings.your-domain.com`） |
| **SFTP** | `sftp://<サーバーIP>:<SFTP_PORT>`（マシンのポートを直接公開） |

> [!NOTE]
> 通常プランの Cloudflare Tunnel では SFTP を転送できないため、SFTP はマシンのポートを直接公開しています

## 🗂️ ディレクトリ構成

```
.
├── docker-compose.yaml
├── .env.example / .env
├── create-pem.sh           # オレオレ証明書生成スクリプト（TLS終端をWingsで行う場合のみ使用）
├── certs/                   # TLS証明書（create-pem.shで生成。Behind Proxy有効時は不要）
├── pterodactyl/             # Wings設定・ログ・内部データ（config.yml / lib / log）
└── <VOLUME_PATH>/           # ゲームサーバーデータ（VOLUME_PATHで指定）
```

## 🐳 サービス構成

| サービス | イメージ | 役割 |
|----------|----------|------|
| **wings** | `ghcr.io/pterodactyl/wings:latest` | Pterodactyl Wings（ゲームサーバー実行デーモン） |
| **cloudflared** | `cloudflare/cloudflared` | Cloudflare Tunnel（安全な公開） |

> [!NOTE]
> `cloudflared` は `network_mode: service:wings` で Wings のネットワークを共有しています

## 🛠️ トラブルシューティング

### Wings が Panel に接続できない

`config.yml` の以下の項目を確認してください:

- `remote`: Panel の URL（`https://` を推奨）
- `allowed_origins`: Panel の origin URL が含まれているか

### Cloudflare Tunnel 経由で接続できない

- `config.yml` の `api.port` と Cloudflare Tunnel の公開先ポートが一致しているか確認
- Cloudflare Tunnel の **Service Type** が `HTTP` になっているか確認
- `api.ssl.enabled` が `false` になっているか確認（`Behind Proxy` 有効時）

### SFTP に接続できない

- `.env` の `SFTP_PORT` と `config.yml` の `system.sftp.bind_port` が同じ値か確認
- ファイアウォールで `SFTP_PORT` が開放されているか確認

### Wings 起動時に `Pool overlaps with other one on this address space` が出る

Wings が起動時に Docker API 経由で作成するゲームサーバー隔離用ネットワーク `pterodactyl_nw`（bridge名: `pterodactyl0`）のデフォルトサブネット `172.18.0.0/16` が、インスタンス自体の所属ネットワーク等と重複しているのが原因です

これは Wings が Docker API 経由で独自に作成するネットワークであり、`docker-compose.yaml` の `networks:` セクションとは無関係です。`config.yml` の `docker.network` セクションで重複しないサブネットに変更してください

```yaml
docker:
  network:
    interface: 10.0.0.1
    name: pterodactyl_nw
    network_mode: pterodactyl_nw
    driver: bridge
    is_internal: false
    enable_icc: true
    network_mtu: 1500
    interfaces:
      v4:
        subnet: 10.0.0.0/16
        gateway: 10.0.0.1
```

> [!NOTE]
> 既に Wings が古いサブネットで `pterodactyl_nw` ネットワークを作成済みの場合は、`docker network rm pterodactyl_nw` で削除してから再起動してください

### `machine_id` について

Wings はデフォルトで `machine_id` 機能が有効です。これは各サーバーの UUID（ハイフン除去）を `/etc/machine-id` として生成し、ゲームサーバーコンテナにマウントする機能です

この機能は **Hytale** がトークン暗号化に machine-id を必要とするために追加されました（Wings v1.12.1）。Hytale を実行しない場合は無効化を推奨します

```yaml
system:
  machine_id:
    enabled: false
```

> [!WARNING]
> Wings を Docker で動かす場合、`machine_id` を有効にする場合は `directory` の変更が必要です
> デフォルトの `/run/wings/machine-id` は Wings コンテナ内の一時パスですが、ゲームサーバーコンテナ（兄弟コンテナ）にバインドマウントされるため、ホスト側とコンテナ側で同じ絶対パスにする必要があります
> `VOLUME_PATH` 配下など、ホストと共有されるパスに変更してください
>
> ```yaml
> system:
>   machine_id:
>     enabled: true
>     directory: /volumes/.machine-id  # VOLUME_PATH 配下等、ホストと共有されるパス
> ```