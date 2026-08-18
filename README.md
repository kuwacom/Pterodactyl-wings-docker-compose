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

そのため、ゲームサーバーのデータ本体である `data`（`VOLUME_PATH`）だけは、ホスト側とコンテナ側で同じ絶対パスにする必要があります
これはゲームサーバーコンテナにバインドマウントする際、ホスト側 Docker デーモンに対してホストパスを指定するためです

それ以外のディレクトリ（`root_directory` / `log_directory` / `archive_directory` / `backup_directory` / `tmp_directory`）は Wings コンテナ内のみで完結するため、ホスト側パスは自由に設定可能です
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
> **追加の際、`Configuration` の `Daemon Port` は必ず `443` に変更してください**
> Cloudflare Tunnel から Wings に接続するため、HTTPS ポートの 443 にする必要があります

> [!IMPORTANT]
> **`FQDN` は Cloudflare Tunnel で設定した公開ドメインにしてください**

次に、取得した Wings 用 config の以下の項目を書き換え、`./pterodactyl/config.yml` として保存してください

```yaml
api:
  host: 0.0.0.0  # バインドしたいアドレス空間がある場合は制限してください
  port: 443      # config生成時に設定したポートになりますが、8080等でも問題ありません
                 # その場合はCloudflare Tunnelの公開先ポートも合わせて変更してください
  ssl:
    enabled: true
    cert: /etc/certs/fullchain.pem
    key: /etc/certs/privkey.pem

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

remote: <Pterodactyl Panel のURL httpsが好ましい>
allowed_origins:
  - <Pterodactyl Panel 及び、その他WEBUIのorigin URL>
  - https://example.com
```

### 5. オレオレ証明書の作成

Pterodactyl Wings では、API の通信に TLS を利用することが推奨されています
Cloudflare Tunnel との通信にオレオレ証明書を利用して TLS 通信を行います

```bash
bash ./create-pem.sh
```

`./certs/` 配下に `fullchain.pem` と `privkey.pem` が生成されます

### 6. Cloudflare Tunnel で公開する

Cloudflare Tunnel のダッシュボードで、Wings API を公開する Public Hostname を追加します

1. トンネルの **Public Hostname** タブを開く
2. **Add a public hostname** をクリック
3. 以下を入力:

   | 項目 | 設定値 |
   |------|--------|
   | **Subdomain** | 任意（例: `wings`） |
   | **Domain** | Cloudflare で管理済みのドメインを選択 |
   | **Path** | 空 |
   | **Service Type** | `HTTPS` |
   | **URL** | `localhost:443`（`config.yml` の `api.port` に合わせる） |

4. **Additional application settings** -> **TLS** を展開し、**No TLS Verify** を有効化
   - Wings はオレオレ証明書を利用するため、TLS 検証を無効化する必要があります
5. **Save hostname** をクリック

> [!NOTE]
> cloudflared コンテナは Wings コンテナのネットワークに所属しているため、`localhost:443` で Wings API にアクセスできます

### 7. Docker Compose で起動

```bash
docker compose up -d
```

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
├── create-pem.sh
├── certs/                   # TLS証明書（create-pem.shで生成）
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

- Cloudflare Tunnel の **No TLS Verify** が有効になっているか確認
- `config.yml` の `api.port` と Cloudflare Tunnel の公開先ポートが一致しているか確認
- `api.ssl.enabled` が `true` になっているか確認

### SFTP に接続できない

- `.env` の `SFTP_PORT` と `config.yml` の `system.sftp.bind_port` が同じ値か確認
- ファイアウォールで `SFTP_PORT` が開放されているか確認