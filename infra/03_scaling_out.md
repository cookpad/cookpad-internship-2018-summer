# スケールアウト/アップ

ここでは、サーバのスケールアップ・スケールアウトの戦略について見ていきます。

サーバの CPU やメモリなどのリソースが足りなくなった場合、スケールアップもしくはスケールアウトを選択することになります。
ここでは、スケールアップとスケールアウトのメリット・デメリットについて確認し、どういった場面でどちらを選択するか考えてみます。

## スケールアウトと負荷分散の手法

スケールアウトは、前項で学んだ通り、同じ機能を提供するサーバを複数台用意しリクエストをバランシングする手法です。
複数台で同じサービスを提供するという前提になっているため、スケールアウトが向いているようなサーバは、
Web サーバなどの、基本的にステートレスになっているサーバが適しています。

スケールアウトでの負荷分散の構成としては、クライアントと Web サーバの間に、ロードバランサという負荷分散の機器を置くのが一般的です。

ロードバランサは、クライアントから受けたリクエストを、バックエンドにある Web サーバに適切に分配するのが主な機能ですが、
ヘルスチェックという、バックエンドのサーバに障害が起きているか確認し、障害が起きていたら切り離す機能などがあります。

AWS には、マネージドのロードバランサとして、ELB (Elastic Load Balancer) と ALB (Application Load Balancer) があります。
ALB の方が後に登場したサービスで、機能も多くなっています。ELB は Classic Load Balancer とも呼ばれているので、理由がなければ ALB を選択することになります。

また、スケールアウトのメリットとして、耐障害性の向上もあります。
例えば、スペックの高い 1 台のサーバでサービスを提供していた場合、その 1 台に障害などが発生した場合、その瞬間にサービスの継続が不可能になってしまいます。
また、スペックの高い 1 台を更にスケールアップしようとした場合、一般に再起動が必要になるため、サービスのダウンタイムが発生してしまいます。
一方で、ロードバランサ配下で複数の Web サーバでサービスを提供していた場合、1 台が落ちても大きく問題になることがありませんし、
サーバの追加や削除をサービスのダウンタイム無しで行うことが可能になっています。

耐障害性の議論としては、この場合、ロードバランサが SPoF (Single Point of Failure: 単一障害点) になってしまうので、
ロードバランサ自体も冗長化したりスケールアウトする必要があります。

多くのロードバランサでは、ロードバランサ自体もスケールアップ・スケールアウトする戦略を取っています。
ロードバランサの冗長化・負荷分散は、同じドメインに対して複数の IP アドレスを割り当てることで実現しています。

スケールアウトを選択しやすくなった理由として、サーバ仮想化の流れや、AWS のようなクラウドサービスの流行があります。
サーバ仮想化によって、サーバのイメージコピーなどが行えるようになったため、同一の機能のサーバを用意しやすくという点や、
AWS のように、API 経由でサーバを複製・起動・停止出来るようになったため、負荷に応じて自動でスケールアウト・スケールインが行えるようになりました。

実際に、クックパッドのアプリケーションサーバでは、負荷に応じて自動的にスケールアウト・スケールインを行っています。

## スケールアップと負荷分散の手法

スケールアップは、前項で学んだ通り、同一サーバの CPU やメモリなどのスペックを上げる確保する手法です。
データ更新が頻繁に発生するサーバや、データの一貫性が重要になっているようなサーバでは、スケールアウトが困難なため、スケールアップを選択するのが一般的です。

スケールアップを選択するサーバの種類としては、データベースサーバなどが挙げられます。

データベースサーバの提供としては、データの更新とデータの参照がありますが、
このうち、参照はステートレスな操作であるため、実はスケールアウト戦略を取ることが出来ます。

ただ単に同じデータベースサーバを並べるだけだと新しく更新されるデータが反映されないため、
MySQL のレプリケーションという機能を使い、データの同期を行います。

レプリケーションでは、Master/Slave という構成を取り、更新するクエリを Master に向け、
Master で更新が行われた SQL もしくは行のみを、Slave サーバに送ることでデータを同期します。

また、1 つの Master サーバに対して、Slave サーバは複数繋げることが可能になっているため、
参照系クエリの負荷分散は、Slave サーバのスケールアウト戦略を取ることが可能になっています。

そのため、本当にスケールアップが必要な箇所は、データベースサーバの更新処理に対する部分になります。
このように、本当にデータの更新などが必要な部分だけをスケールアップ戦略で解決するのが一般的です。

## ここまでのまとめ

基本的にはスケールアウト戦略を選択するのがおすすめ。
データの更新などの分離しにくい処理を行うサーバに関してはスケールアップを選択するのがおすすめ。

## MySQLとPumaのインスタンス分離、スケールアップ

まずMySQLとPumaのインスタンスを分けて、MySQLをスケールアップします。MySQLとPumaを別インスタンスに分離する理由は以下の 2 つです。

- MySQLとPumaでは負荷の特性（必要なリソース）が違うため、分かれているほうがキャパシティプランニングがしやすい
- アプリケーションサーバのスケールアウトはロードバランサを使えば比較的簡単に実現できるが、MySQLのスケールアウトはレプリケーションを行いマスタ、スレーブを考慮してアクセスする必要がある

今回は [Amazon RDS](https://aws.amazon.com/jp/rds/) を用います。
RDS は AWS が提供するデータベースサービスであり、これまで自分で行う必要のあったソフトウェアのインストールや設定を肩代わりしてくれます。
RDS では MySQL, PostgreSQL, MariaDB, MSSQL, Oracle など様々なデータベースが利用可能です。今回は MySQL を用います。

1. Services から RDS を選択
2. Launch DB Instance を選択
3. MySQL Community Edition を選択
4. Dev/Test を選択
5. 設定を選んでいく
  - DB Engine Version: MySQL 5.7.17
  - DB Instance Class: db.m4.large
  - Multi-AZ Deployment: No
  - Storage Type: General Purpose
  - Allocated Storage: 100GB
  - DB Instance Identifier: your-name-001
  - Master Username: slackpad_server
  - Master Password: ji2yodankai
  - DB parameter group: summer-intern-mysql57
6. ネットワークなどの設定をする
  - Subnet Group: internship2018
  - Publicly Accessible: No
  - Availability Zone: ap-northeast-1c
  - VPC Security Group(s): default
  - Database Name: slackpad_server
  - Disable encryption にチェックを入れる
  - Backup を 0 days に変更する
  - Disable Enhanced Monitoring にチェックを入れる
7. 作成された DB Instance を確認し、Endpoint をコピー
8. RDS Instances の一覧から自分のインスタンスをクリックして開いた詳細画面の Tags に、以下のようなタグを追加する。
  - Key: `ResourceType`, Value: `Internship`

### 接続先DBの変更

EC2 インスタンスに SSH します。

MySQL からデータをダンプし、RDS にコピーします。

```
(EC2) $ sudo mysqldump -u root slackpad_server > dump.sql
(EC2) $ mysql -u slackpad_server -pji2yodankai -h #{RDSのエンドポイント} slackpad_server < dump.sql
```

コピーが完了したら、MySQLは必要ないので Mac 上で`itamae/cookbooks/mysql/default.rb` を編集しstop/disableします。

```diff
diff --git a/itamae/cookbooks/mysql/default.rb b/itamae/cookbooks/mysql/default.rb
index ccc1bee..2d2a6ac 100644
--- a/itamae/cookbooks/mysql/default.rb
+++ b/itamae/cookbooks/mysql/default.rb
@@ -6,7 +6,7 @@
 end

 service 'mysql' do
-  action [:start, :enable]
+  action [:stop, :disable]
 end
```

更に、ローカルの MySQL のデータベース作成を行っていた箇所を削除します。

```diff
diff --git a/itamae/cookbooks/mysql/default.rb b/itamae/cookbooks/mysql/default.rb
index 2d2a6ac..81b7975 100644
--- a/itamae/cookbooks/mysql/default.rb
+++ b/itamae/cookbooks/mysql/default.rb
@@ -9,16 +9,6 @@ service 'mysql' do
   action [:stop, :disable]
 end

-execute %q{mysql -uroot -e "create database if not exists slackpad_server character set utf8mb4"} do
-  user 'root'
-  not_if %q{mysql -uroot -e "show databases" | grep slackpad_server}
-end
-
-execute %q{mysql -uroot -e 'grant all on `slackpad_server`.* to "slackpad_server"@"%" identified by "ji2yodankai"'} do
-  user 'root'
-  not_if %q{mysql -uroot -e "select user from mysql.user" | grep slackpad_server}
-end
-
 remote_file '/etc/mysql/mysql.conf.d/slow_query_log.cnf' do
   owner 'root'
   group 'root'
```

itamae apply します。

```
(Mac) $ bundle exec itamae ssh -h #{EC2 インスタンスの IP アドレス} -u ubuntu -i ~/.ssh/admin.pem functions.rb roles/app/default.rb
```

次に、Puma (Rails)から接続するDBを切り替えます。

```
(Mac) $ ${EDITOR} config/database.yml
```

下記の`HOSTNAME_OF_DB`はDBサーバの Endpoint を指定してください。

```yaml
production:
  adapter: mysql2
  host: #{RDS インスタンスの Endpoint}
  database: slackpad_server
  username: slackpad_server
  password: ji2yodankai
  encoding: utf8mb4
```

デプロイして設定を反映させます。

```
(Mac) $ bundle exec cap production deploy
```

## アプリケーションサーバのスケールアウト

アプリケーションサーバを1台増やしてスケールアウトします。

### インスタンスを起動する

最初に作成したインスタンスと同じように、新しく 2 つ目のインスタンスを起動します。

起動したら、最初に作成したインスタンスに行ったように、起動したインスタンスにも `itamae apply` を実行します。

```
(Mac) $ bundle exec itamae ssh -h #{2 つ目のインスタンスの IP アドレス} -u ubuntu -i ~/.ssh/admin.pem functions.rb initial.rb roles/app/default.rb
```

次に、capistrano を使って2台の App サーバに同時にデプロイできるように設定を変更します。

```
(Mac) $ ${EDITOR} config/deploy/production.rb
```

```
# 1台目
server 'ec2-xxx-xxx-xxx.ap-northeast-1.compute.amazonaws.com', user: 'ubuntu', roles: %w{app db web}
# 2台目
server 'ec2-yyy-yyy-yyy.ap-northeast-1.compute.amazonaws.com', user: 'ubuntu', roles: %w{app web}
```

デプロイがうまくいくか確認しましょう。

```
$ bundle exec cap production deploy
```

### Application Load Balancer (ALB)

この状態だと 2 つのインスタンスは独立して動作している状態なので、間にロードバランサを挟みます。ALBはAWSが提供するHTTP(S)ロードバランサです。

https://ap-northeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-northeast-1#LoadBalancers: からALBを作成します。

1. Application Load Balancer
2. Name: `your-name`, Scheme: internet-facing
3. Tags
  - Key: `ResourceType`, Value: `Internship`
3. VPC: vpc-4f77f328
5. Subnet: subnet-fbf4a8b2, subnet-f9f67ea2
7. Security Group: default
8. New target group
9. Name: `your-name`
10. Health check path: `/hello/health`
11. Register targets: `app-your-name-001`, `app-your-name-002`
    - 選択したあとにちゃんと "Add to registered" を押さないと登録されない

こうして作成したALBにアクセスすると、2 つのインスタンスにに均等にリクエストが振り分けられます。

ベンチマークの対象を変えるために、ベンチマーカーのページの Settings の HOST の部分を、ALB の FQDN に変えておきましょう。

### アプリケーションのスケールアウトの注意点

実はこの状態では、片方のサーバに Websocket 接続したユーザと、もう片方のサーバに Websocket 接続したユーザとで、チャットが出来ない状態になってしまっています。

そのため、ロードバランサの振り分け状況によっては、正しくチャットが行えない状態になっています。

Q. こういった状況下で、正しくチャットが行えるようにするにはどのようなアプリケーションの変更が考えられるでしょうか。考えてみましょう。
