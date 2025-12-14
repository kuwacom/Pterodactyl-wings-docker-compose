# 🚀 Pterodactyl wings with Docker-Compose

Pterodactyl を Docker Compose + CFTunnelで簡単に構築

このリポジトリは、Pterodactyl wings を Docker Compose で簡単にセットアップするためのものです

---

## 📦 セットアップ手順

### 1. リポジトリをクローン
```bash
git clone https://github.com/kuwacom/Pterodactyl-wings-docker-compose.git
cd Pterodactyl-wings-docker-compose
```

### 2. `.env` ファイルを作成
```bash
cp example.env .env
```

以下の内容を .env ファイルとしてルートディレクトリに作成し、自分の環境に合わせて編集してください

- `TUNNEL_TOKEN`: Cloudflare Tunnel のトークン

### 3. `docker-compose.yaml`を確認
`docker-compose.yaml`ファイル内のwingsサービス内のコメントにあるように、ボリューム及びtmpディレクトリは、ホスト及びコンテナ内から同じ絶対パスでアクセスができる必要があります

これは、wingsはコンテナ内で動作しているが、wingsにより生成されるサーバーコンテナはホスト側docekrを利用して起動されるため、tempフォルダや起動するコンテナにマウントするディレクトリはホスト側とwingsが動作しているコンテナ内と同じでないといけないためです

ただし、これらのフォルダのパスについては、`pterodactyl/config.yml`にて変更が可能です  
この時点でボリュームやtmp、その他ディレクトリの保存場所を決めておいて、この後のconfigの取得をして書き込むステップにて、ここで設定したパスになるように書き換える必要があります

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
  # 基本データの保存先はセットアップセクション3を参考にしてください
  root_directory: /var/lib/pterodactyl
  log_directory: /var/log/pterodactyl
  data: /volumes
  archive_directory: /var/lib/pterodactyl/archives
  backup_directory: /var/lib/pterodactyl/backups
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