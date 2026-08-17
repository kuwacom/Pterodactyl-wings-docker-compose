# 🚀 Pterodactyl wings with Docker-Compose

Pterodactyl を Docker Compose + CFTunnelで簡単に構築

このリポジトリは、Pterodactyl wings を Docker Compose で簡単にセットアップするためのものです

> Pterodactyl panelはこちら -> [kuwacom/pterodactyl-panel-compose](https://github.com/kuwacom/pterodactyl-panel-compose)

---

## 📦 セットアップ手順

### 1. リポジトリをクローン
```bash
git clone https://github.com/kuwacom/pterodactyl-wings-compose.git
cd pterodactyl-wings-compose
```

### 2. `.env` ファイルを作成
```bash
cp example.env .env
```

以下の内容を .env ファイルとしてルートディレクトリに作成し、自分の環境に合わせて編集してください

- `TUNNEL_TOKEN`: Cloudflare Tunnel のトークン

### 3. `docker-compose.yaml`を確認
wingsはコンテナ内で動作していますが、wingsにより生成されるゲームサーバーコンテナはホスト側のDockerデーモンで起動されます（兄弟コンテナモデル）

そのため、ゲームサーバーのデータ本体である `data`（`/volumes/`）だけは、ホスト側とコンテナ側で同じ絶対パスにする必要があります
これはゲームサーバーコンテナにバインドマウントする際、ホスト側Dockerデーモンに対してホストパスを指定するためです

それ以外のディレクトリ（`root_directory` / `log_directory` / `archive_directory` / `backup_directory` / `tmp_directory`）はwingsコンテナ内のみで完結するため、ホスト側パスは自由に設定可能です
本構成では `./pterodactyl/` 配下にまとめています

```
./pterodactyl/
  ├── config.yml       # wings 設定ファイル
  ├── lib/             # root_directory（archives/backups/内部データ）
  └── log/             # log_directory（wings.log）
```

> **複数ディスクを使いたい場合**
> `data` は単一パスしか指定できないため、複数ディスクを扱いたい場合はmergerfs等で1つの仮想ボリュームに統合してから `/volumes/` にマウントしてください
> シンボリックリンクでの分散はwingsのパス検証と競合するため推奨されません

### 4. Pterodactyl panel で Node を追加
Pterodactyl panel にてNode追加を行い、wings用のconfigを取得しましょう

> **追加の際、`Configuration`の`Daemon Port`は必ず`443`へ変更をしてください**
Cloudflare Tunnelからwingsに接続をするため、httpsポートの443にする必要があります

> **`FQDN`はCloudflare Tunnelで設定した公開ドメインにしてください**

次に、取得したwings用configの以下の項目を書き換えます

```yaml
api:
  host: 0.0.0.0 # バインドしたいアドレス空間がある場合は制限してください
  port: 443 # config生成時に設定したポートになりますが、8080等でも問題ありません。その場合はCloudflare Tuennlでそのポートへの変更を忘れずに
  ssl:
    enabled: true
    cert: /etc/certs/fullchain.pem
    key: /etc/certs/privkey.pem
system:
  # config.yml / lib / log を ./pterodactyl/ にまとめるため、
  # root_directory と log_directory を /etc/pterodactyl/ 配下に変更する
  root_directory: /etc/pterodactyl/lib
  log_directory: /etc/pterodactyl/log
  data: /volumes
  archive_directory: /etc/pterodactyl/lib/archives
  backup_directory: /etc/pterodactyl/lib/backups
  tmp_directory: /tmp/pterodactyl

  # 通常プランのCloudflare Tunnelではsftpは転送できないため、別ルートでのアクセスを構成する場合はここを変更してください
  sftp:
    bind_address: 0.0.0.0
    bind_port: 2022
    read_only: false

remote: <Pterodactyl panel のURL httpsが好ましい>
allowed_origins:
- <Pterodactyl panel 及び、その他WEBUIのorigin URL>
- https://example.com
```

### 5. オレオレ証明書の作成
Pterodactyl wings では、apiの通信にTLSを利用することが推奨されています
そのため、Cloudflare Tunnelとの通信にオレオレ証明を利用してTLS通信をします

```bash
bash ./create-pem.sh
```

### 6. Cloudflare Tunnelで公開する

セットアップ後、Cloudflare Tunnelのダッシュボード側で、`https://localhost:80`へ公開設定をしておきましょう
**その他のアプリケーション設定-TLSのTLS検証なしの有効化を忘れずに行ってください**
wingsのオレオレ証明を利用するためです

### 7. Docker Composeで起動
```bash
docker-compose up -d
```
