# Docker を用いたコンテナ時代のアプリケーションデプロイ (後半)

## ECS (Fargate) と Hako を使って slackpad をデプロイしてみよう

ハンズオンでは、全体として以下のような流れで ECS (Fargate) に slackpad をデプロイします。

1. ローカルで Docker と docker-compose を使って slackpad を起動してみる
2. 作成した Docker イメージを ECR に push する
3. Hako の定義を書く
4. 書いた Hako の定義を使って ECS (Fargate) にデプロイする

## Docker for Mac のインストール (インストールされていなければ)

[Docker Community Edition for Mac - Docker Store](https://store.docker.com/editions/community/docker-ce-desktop-mac) を開き、Get Docker CE for Mac (Stable) というボタンをクリックして dmg ファイルを落とし、インストーラに従ってインストールしてください。

Docker は Linux カーネルの機能に依存しているため直接 macOS 上では動きませんが、HyperKit とよばれる macOS 用の軽量な仮想化ツールの上で docker daemon の動く Linux 上で Docker 環境を実現しています。また、Docker for Mac をインストールすれば、後述する docker-compose もワンストップでインストールされます。

## envchain を導入する (インストールされていなければ)

以下のチュートリアルで ECR に Docker イメージを push し、hako を使ってデプロイすることになりますが、ターミナル上で AWS の認証情報などの秘匿情報を比較的安全に扱うためのツールとして [envchain](https://github.com/sorah/envchain) を利用します。

以下の例にしたがって、先ほど共有された IAM ユーザの `AWS_ACCESS_KEY_ID` と `AWS_SECRET_ACCESS_KEY` をセットしてみましょう。

```
(Mac) $ envchain --set aws-cookpad-summer-intern AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
```

以上のコマンドラインを実行すると、それぞれの環境変数を設定するプロンプトが出現するので入力してください。

ここでセットした環境変数は、envchain コマンド経由で呼び出したときのみ、macOS のキーチェーンから呼び出され、環境変数にセットされます。

```
(Mac) $ envchain aws-cookpad-summer-intern env | grep AWS_
```

のコマンドラインを実行すると、先ほど設定した環境変数が現れていることがわかります。(ただの `env | grep AWS\_` コマンドだと無いこともわかる)

## Dockerfile を書いてシンプルに Puma を起動する

### リポジトリに変更を加える

では、ローカルで Docker を使って起動するように、slackpad にいくつか変更を加えていきましょう。まず、development 環境で SQLite を使って Puma を起動することを目標にします。

GHE 上の summer-intern-slackpad-server リポジトリの master ブランチと docekrized ブランチとの差分とここから先の説明を読んで理解しながら、手元のリポジトリに手を加えて Fargate を使ってデプロイするところまで進めてください。

### イメージのビルド

それでは、slackpad の Docker イメージを作り、コンテナの中で slackpad を起動してみましょう。差分を参考に手元のリポジトリに以下のファイルを用意します。もし config/database.yml で MySQL を使うようになっている場合は、`database: db/development.sqlite3` のように指定して SQLite を使うようにしてください。

- Dockerfile
- .dockerignore

Docker イメージの定義は Dockerfile に書かれているので眺めてみましょう。各コマンドの役割については、サンプルの Dockerfile に書かれているコメントや公式ドキュメント https://docs.docker.com/develop/develop-images/dockerfile_best-practices/ が参考になります。

.dockerignore に Docker イメージに含めたくないファイルを書いておくと、指定したファイルは `COPY` コマンドなどで Docker イメージの中にコピーされなくなります。ここでは、SQLite のデータベースファイルを無視するように設定しています。

Docker の各機能は `docker` コマンドのサブコマンドとして実装されています。Docker イメージを作成する場合は `docker build` サブコマンドを使います。以下に例を示します。

```
(Mac) $ docker build -t #{your-name}/slackpad .
```

`#{your-name}` の部分はあなたの名前で置き換えてください。たとえばわたしの場合だと `mozamimy/slackpad` となります。

`-t` オプションは作成する Docker イメージ名を指定します。`#{組織名や人名}/#{アプリケーション名}` とするのが慣例です。また、イメージ名に続けて `mozamimy/slackpad:revision1` のようにするとタグをつけることができます。省略した場合は `latest` というイメージが最新であることを示すタグが自動的につけられます。

引数の `.` はビルドコンテキストを指定するもので、普通、ソースコードが置かれているディレクトリを指定します。`-f` オプションでビルドする Dockerfile を指定できますが、省略した場合はビルドコンテキストに存在する Dockerfile を自動的に指定したことになります。

イメージのビルドには少し時間がかかります。`docker build` コマンドをたたくと、以下のようなログが流れて、うまくいけば bundle install のログが流れてイメージの作成が完了します。もし失敗する場合は、「ビルドしたイメージを使ってコンテナを起動する」を参考に、Dockerfile で失敗する行以降をコメントアウトしてビルドし、bash でコンテナ内を探検することでデバッグを行うとよいでしょう。

```
Step 1/9 : FROM ruby:2.5
 ---> 1624ebb80e3e
Step 2/9 : LABEL maintainer "mozamimy <yuma-asada@cookpad.com>"
 ---> Using cache
 ---> 60233bdc70a5
Step 3/9 : RUN env DEBIAN_FRONTEND=noninteractive apt-get update &&     env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential default-libmysqlclient-dev libxml2-dev zlib1g-dev nodejs qt5-default libqt5webkit5-dev
 ---> Using cache
 ---> 8381f21ea112

 :
 : 以下続く
 :
```

生成されたイメージは `docker images` サブコマンドで確認できます。

```
(Mac) $ docker images | grep mozamimy/slackpad
mozamimy/slackpad                                                     latest              dae8f025be86        4 minutes ago       1.66GB
```

### ビルドしたイメージを使ってコンテナを起動する

では、ビルドしたイメージを使ってコンテナを起動してみましょう。まず、コンテナ内で bash を起動してみます。

```
(Mac) $ docker run --rm -t -i #{your-name}/slackpad /bin/bash
```

`--rm` オプションは、コンテナ内で実行されるプログラムが終了したときにコンテナも一緒に削除するためのオプションです。このオプションをつけないと使わなくなったコンテナがディスクにたまっていくので、開発環境では `--rm` オプションをつけてコンテナを使い捨てにすることをおすすめします。

`-t` オプションはコンテナに仮想端末を割り当て、`-i` オプションは標準入力を開いたままにします。これらのオプションを使うことで、bash をコンテナ内で起動し、キーボードを使ってインタラクティブに操作することができます。

オプションの後の第一引数にはイメージ名を、第二引数にはコンテナ内で起動する実行ファイルを指定します。うまくいくと、以下のようにコンテナ内でシェルを操作できるようになります。ディレクトリを移動したりいくつかコマンドをたたいてみて、コンテナ内を自由に探検してみてください。

```
root@eae215c835b4:/app# ls
Capfile     Gemfile       README.md  app  config     db      docker-compose.yml  hako_sample.jsonnet  lib  mozamimy-slackpad.jsonnet  public  tmp     yarn.lock
Dockerfile  Gemfile.lock  Rakefile   bin  config.ru  docker  docs                itamae               log  package.json               spec    vendor
root@eae215c835b4:/app# ls /gems
ruby
root@eae215c835b4:/app# cat /etc/debian_version
9.4
```

また、別の端末から `docker ps` コマンドをたたくと、コンテナ内を起動しているプロセスの一覧を得ることができます。bash が起動していることがわかりますね。

```
(Mac) $ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
eae215c835b4        mozamimy/slackpad   "/bin/bash"         2 minutes ago       Up 2 minutes                            elastic_leavitt
```

一通り遊んだら `exit` コマンドで bash を終了し、今度はコンテナ内で Puma を起動してみましょう。

```
(Mac) $ docker run --rm --name slackpad-app -e RAILS_ENV=development -t -p 8080:3000 #{your-name}/slackpad bundle exec puma -C config/puma.rb config.ru
I, [2018-04-17T12:44:42.622544 #1]  INFO -- : Refreshing Gem list
I, [2018-04-17T12:44:43.692509 #1]  INFO -- : listening on addr=0.0.0.0:8080 fd=12
I, [2018-04-17T12:44:43.800174 #12]  INFO -- : worker=0 ready
I, [2018-04-17T12:44:43.804731 #15]  INFO -- : worker=1 ready
I, [2018-04-17T12:44:43.807638 #18]  INFO -- : worker=2 ready
I, [2018-04-17T12:44:43.810189 #21]  INFO -- : worker=3 ready
I, [2018-04-17T12:44:43.812477 #24]  INFO -- : worker=4 ready
I, [2018-04-17T12:44:43.813288 #26]  INFO -- : worker=5 ready
I, [2018-04-17T12:44:43.817517 #30]  INFO -- : worker=6 ready
I, [2018-04-17T12:44:43.818066 #1]  INFO -- : master process ready
I, [2018-04-17T12:44:43.819509 #33]  INFO -- : worker=7 ready
```

ここで新出のオプションは、以下のような意味を持ちます。

- `--name`: コンテナ名を指定する。
- `-e`: 環境変数を指定する。
- `-p`: ポートマッピングを指定する。`8080:3000` のように指定すると、コンテナの port 8080 がホストの port 3000 にマッピングされます。

bash を起動したときのように、別の端末から `docker ps` コマンドを実行すると、Puma がコンテナ内で起動していることが確認できます。

```
(Mac) $ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
c115538a75ac        mozamimy/slackpad   "bundle exec puma -C…"   33 seconds ago      Up 32 seconds       0.0.0.0:8080->3000/tcp   slackpad-app
```

起動中のコンテナ内でコマンドを実行したい場合は `docker exec` サブコマンドを使います。引数にはコンテナ ID かコンテナ名を指定します。今の状態でたとえば http://127.0.0.1:8080/hello/health にアクセスしても pending migration のエラーが出る状態になっているはずなので、以下のようにして `docker exec` を使って `rails db:migrate` と `rails db:seed` を流してみましょう。

```
(Mac) $ docker exec -it slackpad-app bundle exec /bin/sh -c 'rails db:migrate && rails db:seed'
```

この状態でブラウザを開き、`(Mac) $ curl http://127.0.0.1:8080/hello/health` のようにして、200 が返ってくれば成功です。次節から、SQLite ではなく MySQL を使うように変更を加え、docker-compose を利用して複数コンテナを立ち上げ、連携させる方法を学びます。

## docker-compose を使ってコンテナ間で連携する

メインのコンテナと一緒に別のコンテナを立ち上げるような構成を sidecar といいます。ここでは slackpad の Puma をが動くコンテナを主として、sidecar として NGINX と MySQL を起動してみます。ただし、ハンズオンの後半で解説している本番環境へのデプロイでは RDS を使うので MySQL コンテナを一緒に立ち上げることはありません。

### docker-compose とは

docker-compose はオーケストレーションツールの一種で、コンテナ群をいい感じに定義してシュッと立ち上げたり落としたりできるツールです。ECS や Kubernetes は主に production 環境で使うことを想定していますが、軽量な docker-compose は手元でコンテナ群を起動するために使われることがほとんどです。docker-compose を使うことで、`docker` コマンドに渡す引数やオプションを YAML ファイルとして定義でき、コンテナ群で連携させるための閉じたネットワークを作るといったことが簡単にできるようになります。

### リポジトリに変更を加える

ここからは、development 環境でコンテナで動く MySQL を使って Puma を起動することを目標とします。MySQL を使うようにするため、GHE 上の差分を見ながら、config/database.yml を編集して MySQL を使うように設定してください。

次に、同じく GHE 上の差分を参考に、docker-compose.yml をリポジトリ上に作成してください。

### docker-compose を使ってイメージをビルドする

では、`docker-compose` コマンドを使って Docker イメージをビルドしてみましょう。

```
(Mac) $ docker-compose build
```

docker-compose も `docker` コマンドと同じく、サブコマンドを用いて様々な操作を行います。上の例のように単に `docker-compose build` とすると YAML ファイル内に定義されている全てのサービスについてビルドが行われます。`docker-compose build slackpad_app` のようにすると、特定のサービスのイメージだけビルドすることも可能です。

### docker-compose を使ってコンテナ群を起動する

それでは、同様に `docker-compose` コマンドを使ってさきほどビルドしたイメージでコンテナを起動してみましょう。


```
(Mac) $ docker-compose up
```

本当にこれだけです！プリミティブな `docker` コマンドに与える引数やオプションに必要な情報が docker-compose.yml に含まれているため、全てのコンポーネントがコマンド一発で起動します。`docker ps` サブコマンドで確認してみましょう。ちゃんと 3 つのコンテナが起動していることがわかりますね。

```
(Mac) $ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS                  NAMES
78ed820e5aae        mozamimy/slackpad   "/bin/sh -c 'sleep 2…"   59 seconds ago       Up 58 seconds                              slackpad-app
a08e1d2c86d1        mozamimy/nginx      "nginx -g 'daemon of…"   About a minute ago   Up 59 seconds       0.0.0.0:8080->80/tcp   slackpad-nginx
9fcb4b5efa82        mysql:5.7           "docker-entrypoint.s…"   About a minute ago   Up 59 seconds       3306/tcp               slackpad-mysql
```

初回起動時には DB マイグレーションが必要になるので、以下のようにして起動中の slackpad-app コンテナで `db:migrate` と `db:seed` を走らせましょう。

```
(Mac) $ docker exec -t slackpad-app /bin/sh -c 'bundle exec rails db:migrate && bundle exec rails db:seed'
```

手元で `curl http://127.0.0.1:8080/hello/health` などとして、200 が返ってくれば成功です。

このように docker-compose は動く README として非常に便利なので、これからの業務でも Dockerfile を書くときには docker-compose.yml を添えることを強くおすすめします。

コンテナ群を終了するときは、以下のようにしてください。

```
(Mac) $ docker-compose down
```

## 作成した Docker イメージを ECR に push する

では、あらためて slackpad の Docker イメージをビルドして ECR に push してみましょう。https://ap-northeast-1.console.aws.amazon.com/ecs/home?region=ap-northeast-1#/repositories を開き、Create repository ボタンを押して `#{your-name}/slackpad` という名前でリポジトリを作りましょう。

次に、以下のコマンド例にしたがって、Docker イメージを ECR に push します。

```
(Mac) $ envchain aws-cookpad-summer-intern aws ecr get-login --no-include-email --region ap-northeast-1
(Mac) $ [docker login から始まる ^ のコマンドの出力をコピーアンドペーストしてそのまま実行。`Login Succeeded` と出れば成功]
(Mac) $ docker build -t #{your-name}/slackpad .
(Mac) $ docker tag #{your-name}/slackpad:latest xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/#{your-name}/slackpad:latest
(Mac) $ envchain aws-cookpad-summer-intern docker push xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/#{your-name}/slackpad:latest
```

ECR の自分のリポジトリをクリックして、`latest` と書かれたタグが出現していれば成功です。イメージをビルドしてデプロイする場合、その都度 `docker push` が必要なので注意してください。ここではハンズオンということでプリミティブに手元からイメージを push していますが、現場では Jenkins などの CI ツールを使ってイメージをビルドし、push することが一般的です。

## デプロイまでのおおまかな流れ

それでは、いよいよ hako の設定をしてデプロイです。以下の手順で設定を行っていきます。

1. GHE の差分にある hako\_sample.jsonnet を参考に #{your-name}-slackpad.jsonnet ファイルを作成する
  - ファイル名がそのままアプリケーション名になります (たとえばわたしの場合 mozamimy-slackpad)
2. s3://cookpad-infra-summer-internship-2018/front_config/#{your-name}/default.conf に NGINX の設定をアップロードする
3. hako コマンドを使ってデプロイする

### hako の設定を書いてデプロイしてみよう

では、hako の設定を用意しましょう。

GHE の差分にある hako\_sample.jsonnet を参考に #{your-name}-slackpad.jsonnet ファイルを作成し、設定の内容を確認しながら必要な値を埋めてください。設定値の各項目の意味はコメントに書かれていますし、さらに詳細なドキュメントは GHE に書かれているので参考にしてください。

hako の設定は [Jsonnet](http://jsonnet.org/) で書きます。実は YAML でも書けますが、現在は非推奨です。

Jsonnet は JSON を生成するためのテンプレート言語です。今回は Jsonnet の高度な機能は使わないですが、詳細を知りたい場合は[公式サイトのドキュメント](http://jsonnet.org/)を見てください。また、[Jsonnetの薦め - Qiita](https://qiita.com/yugui/items/f4a5e0e9dbd8ddffa48e) も参考になるでしょう。

Jsonnet として valid かどうかを調べるには `brew install jsonnet` でコマンドラインツールをインストールし、`$ jsonnet fmt nanika.jsonnet` とすればよいでしょう。

Vim を使っている人は、[google/vim-jsonnet](https://github.com/google/vim-jsonnetl) を導入すると便利です。シンタックスハイライトはもちろん、ファイル保存時に自動で `jsonnet fmt` を実行して整形してくれるようになります。他のエディタにもプラグインがあると思うので適宜導入してください。

### S3 に NGINX の設定をアップロードする

今回は、Puma の前段に置く NGINX の Docker イメージとして、ryotarai/hako-nginx を使います。

- https://github.com/ryotarai/hako-nginx
- https://hub.docker.com/r/ryotarai/hako-nginx/

[Dockerfile](https://github.com/ryotarai/hako-nginx/blob/master/Dockerfile) や [run-nginx.sh](https://github.com/ryotarai/hako-nginx/blob/master/run-nginx.sh) をみるとわかるように、S3 バケットから設定をダウンロードしてから NGINX プロセスを起動するシンプルなものです。デプロイする前に NGINX の default.conf を S3 にアップロードしましょう。

まず、ローカルの適当なディレクトリに default.conf という名前で以下のようなファイルを作成します。別のコンテナで起動している Puma にリクエストを `proxy_pass` するだけのシンプルな設定です。

```nginx
server {
  listen 80;

  location / {
    try_files $uri @app;
  }

  location @app {
    # Fargate でひとつのタスクで複数のコンテナを起動している場合、
    # コンテナ内のローカルホストでポートを listen しているように見える
    proxy_pass http://localhost:3000;
    proxy_set_header Host "$http_host";
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

このファイルを `s3://cookpad-infra-summer-internship-2018/front_config/yoru-name/default.conf` にアップロードします。

```
(Mac) $ envchain aws-cookpad-summer-intern aws s3 cp default.conf s3://cookpad-infra-summer-internship-2018/front_config/#{yoru-name}/default.conf
```

[S3 のコンソール](https://s3.console.aws.amazon.com/s3/buckets/cookpad-infra-summer-internship-2018/?region=ap-northeast-1&tab=overview) を開いて、ファイルが正常にアップロードされたか確認しておくとよいでしょう。

### hako コマンドを使ってデプロイする

#### ロググループを作成する

まず、[CloudWatch Logs のコンソール](https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#logs:) を開き、ロググループを作成する必要があります。すでに `/ecs/mozamimy-slackpad` が存在していると思うので、それにならって `/ecs/#{your-name}-slackpad` という名前でロググループを作成しましょう。

ログはロググループの中にログストリームという形でどんどん追加されていきます。ログを確認したい場合は CloudWatch Logs のコンソールから見るのもよいですし、ECS コンソールのタスクの詳細画面の Logs タブから確認することもできます。ECS コンソールから見るほうがログストリームを探す手間が省けるため、おすすめです。

#### RDS や Redis に適切にセキュリティグループをつける

今回立ち上げる Fargate のタスクには、Jsonnet の設定の中に書かれているように、`hako-task` というセキュリティグループをつけます。

Fargate で動くアプリから RDS および Redis に 接続できるように、RDS には `rds (sg-93f7cbeb)` を、Redis には `redis (sg-053ea5a9ba7a3e25d)` という名前のセキュリティグループをつけてからデプロイしましょう。

#### hako コマンドを使う

それではいよいよデプロイです! まず、hako の設定として正しいか、実際にどのような `docker` コマンドが発行されるのかを確かめるために、`hako dry-run` してみましょう。

```
(Mac) $ envchain aws-cookpad-summer-intern bundle exec hako deploy --dry-run #{your-name}-slackpad.jsonnet
docker run --name app --cpu-shares 1920 --memory 4032M \
   --env DATABASE_URL=mysql2://slackpad:dankai@mozamimy.cc7xfhp2kekk.ap-northeast-1.rds.amazonaws.com:3306/slackpad?encoding=utf8mb4&reconnect=true \
   --env RAILS_ENV=production \
   --env RAILS_LOG_TO_STDOUT=1 \
   --env RAILS_SERVE_STATIC_FILES=1 \
   --env UNICORN_LOG_TO_STDOUT=1 \
   xxxxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/mozamimy/slackpad:latest \
   bundle exec puma -C config/puma.rb config.ru
docker run --name front --cpu-shares 128 --memory 64M --publish 0:80 \
   --env S3_CONFIG_BUCKET=cookpad-infra-summer-internship-2018 \
   --env S3_CONFIG_KEY=front_config/mozamimy/default.conf \
   ryotarai/hako-nginx:latest
I, [2018-07-23T10:29:33.227761 #14311]  INFO -- : elb_client.modify_load_balancer_attributes(load_balancer_arn: unknown, attributes: [{:key=>"idle_timeout.timeout_seconds", :value=>"20"}]) (dry-run)
I, [2018-07-23T10:29:33.309836 #14311]  INFO -- : elb_client.modify_target_group_attributes(target_group_arn: unknown, attributes: [{:key=>"deregistration_delay.timeout_seconds", :value=>"5"}]) (dry-run)
```

よさそうなら、以下のようにして `hako deploy` コマンドを叩きましょう。

```
(Mac) $ envchain aws-cookpad-summer-intern bundle exec hako deploy #{your-name}-slackpad.jsonnet
I, [2018-07-23T12:48:25.362762 #17230]  INFO -- : Registered task definition: arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:task-definition/mozamimy-slackpad:19
I, [2018-07-23T12:48:25.870702 #17230]  INFO -- : Updated service: arn:aws:ecs:ap-northeast-1:xxxxxxxxxxxx:service/mozamimy-slackpad
I, [2018-07-23T12:48:25.997334 #17230]  INFO -- : Updating ELBv2 attributes to [{:key=>"idle_timeout.timeout_seconds", :value=>"20"}]
I, [2018-07-23T12:48:26.120034 #17230]  INFO -- : Updating target group attributes to [{:key=>"deregistration_delay.timeout_seconds", :value=>"5"}]
I, [2018-07-23T12:48:45.736365 #17230]  INFO -- : 2018-07-23 12:48:43 +0900: (service mozamimy-slackpad) has started 2 tasks: (task 611cfa9c-3c35-46f6-8162-7f35b74e57c5) (task 348178f1-489b-422d-897a-bed77639dadd).
I, [2018-07-23T12:50:11.032976 #17230]  INFO -- : 2018-07-23 12:50:09 +0900: (service mozamimy-slackpad) registered 2 targets in (target-group arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/hako-mozamimy-slackpad/7ea6ecc8006bfb2c)
I, [2018-07-23T12:50:53.259472 #17230]  INFO -- : 2018-07-23 12:50:51 +0900: (service mozamimy-slackpad) has begun draining connections on 2 tasks.
I, [2018-07-23T12:50:53.259617 #17230]  INFO -- : 2018-07-23 12:50:51 +0900: (service mozamimy-slackpad) deregistered 2 targets in (target-group arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxx:targetgroup/hako-mozamimy-slackpad/7ea6ecc8006bfb2c)
I, [2018-07-23T12:51:03.572257 #17230]  INFO -- : 2018-07-23 12:51:02 +0900: (service mozamimy-slackpad) has stopped 2 running tasks: (task a3ddcba6-ace5-4e5e-a8bd-06c8d18fa456) (task 52e9f39d-ecdd-4f3b-bdc7-64c63d72ce4d).
I, [2018-07-23T12:51:12.868508 #17230]  INFO -- : Deployment completed
```

最後に Deployment completed と出ていたらデプロイ完了です。初回のデプロイだと、まず ALB (ELBv2 と表記されている) とそれに紐づく target group が作成され、2 コのタスクが起動していることがわかります。

[ECS コンソールの summer-intern クラスタ](https://ap-northeast-1.console.aws.amazon.com/ecs/home?region=ap-northeast-1#/clusters/summer-intern/tasks) を開き、自分のサービスや起動しているタスクの様子を確認してみてください。

ECS で動くアプリにアクセスするためには、hako-your-name という名前で作成されている ALB を探し、その FQDN でアクセスすることができます。たとえば以下のような感じです。

```
(Mac) $ curl http://hako-mozamimy-slackpad-1336398391.ap-northeast-1.elb.amazonaws.com/hello/health
{"status":"healthy"}
```

### (参考) hako コマンドを使って DB のマイグレーションを行う

今回はすでに DB にテストデータが投入されていたため DB のマイグレーションが不要でしたが、実際には deploy 前などにマイグレーションを行いたくなると思います。そのような場合は、`hako oneshot` サブコマンドを使います。

```
(Mac) $ envchain aws-cookpad-summer-intern bundle exec hako oneshot #{your-name}-slackpad.jsonnet bundle exec rails db:migrate
```

たとえば上記のコマンドを実行すると、slackpad の Docker イメージを利用して `bundle exec rails db:migrate` が Fargate 上で実行されます。

## 参考文献

- http://www.brendangregg.com/blog/2017-11-29/aws-ec2-virtualization-2017.html
- https://www.school.ctc-g.co.jp/columns/nakai/nakai41.html
- https://www.docker.com
- https://github.com/eagletmt/hako
- https://kubernetes.io
- https://aws.amazon.com/ecs/
- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/#usage)
- [Compose file version 3 reference](https://docs.docker.com/compose/compose-file/)
