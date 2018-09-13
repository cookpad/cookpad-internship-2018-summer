# RDBMS

アプリケーションのデータを保存するデータストアとして、
よく用いられるのが Relational DataBase Management System (RDBMS) です。

本稿では、RDBMS の基本的な知識について紹介していきます。

## RDBMS とは

RDBMS では、データを複数の行と複数の列をもつテーブルのような形で取り扱うことができます。
データの更新や参照には、一般に SQL という言語を使用します。

例えば、`id` と `comment` のような列の値を、`topics` テーブルから 10 行取得するような SQL は次のように書けます。

```
SELECT id, comment FROM topics LIMIT 10;
```

他にも RDBMS には、値の間に制約を掛けることでデータの整合性を保つ機能や、
複数の SQL 文による更新を 1 つの処理としてデータベースに反映させることで一貫性・整合性を担保する機能などがあります。

オープンソースの RDBMS として、SQLite や MySQL や PostgreSQL などがあります。
クックパッドでは、MySQL が比較的多く使われています。

## MySQL の仕組み

MySQL の処理の順番として、大きく分けると次のようなプロセスがあります。

1. パーサ
2. オプティマイザ
3. ストレージエンジン

MySQL はクライアントから SQL を受け取った時に、まずその SQL をパースし、どのような処理なのかを解釈するのがパーサです。
例えば、受け取った SQL が参照なのか更新なのかや、どういう条件式が付いているかなどです。
この処理が、パーサによって行われます。

次に、解釈した内容から、どのようにデータを処理するかを決定するのがオプティマイザです。
例えば、`JOIN` 句などが使用された場合はどのように結合すると効率が良いか、
また、後述するインデックスなどを利用する方法もこの段階で決定されます。

次に、実データへのアクセスが行われます。
ここで、実データがファイル上にどのような形式で保存されているかという情報を管理するのがストレージエンジンです。
例えば、1 つのファイルに複数のテーブルの情報を格納するストレージエンジンや、
逆に、テーブル単位でファイルを分離するようなストレージエンジンなどがあります。

MySQL では、ストレージエンジンを自由に変更することができ、
デフォルトのストレージエンジンである InnoDB 以外にも、MyISAM や BlackHole などのストレージエンジンが存在します。

## SQLite3 -> MySQL

では、実際に使用するデータベースを MySQL に切り替えてみましょう。

MySQL 用のライブラリをインストールします。

```
(Mac) $ mkdir -p itamae/cookbooks/mysql
(Mac) $ ${EDITOR} itamae/cookbooks/mysql/default.rb
```

`itamae/cookbooks/mysql/default.rb` の中身は次のようにします。

```
%w(
  mysql-server
  libmysqlclient-dev
).each do |package|
  package package
end

service 'mysql' do
  action [:start, :enable]
end

execute %q{mysql -uroot -e "create database if not exists slackpad_server character set utf8mb4"} do
  user 'root'
  not_if %q{mysql -uroot -e "show databases" | grep slackpad_server}
end

execute %q{mysql -uroot -e 'grant all on `slackpad_server`.* to "slackpad_server"@"%" identified by "ji2yodankai"'} do
  user 'root'
  not_if %q{mysql -uroot -e "select user from mysql.user" | grep slackpad_server}
end
```

`app` ロールで今作った mysql cookbook を使うため、`itamae/roles/app/default.rb` を編集します。

```diff
diff --git a/itamae/roles/app/default.rb b/itamae/roles/app/default.rb
index d295057..1143e16 100644
--- a/itamae/roles/app/default.rb
+++ b/itamae/roles/app/default.rb
@@ -1,6 +1,7 @@
 include_cookbook 'ruby'
 include_cookbook 'nginx'
 include_cookbook 'slackpad-server'
+include_cookbook 'mysql'
```

その後、itamae を dry run で確認します。

```
(Mac) $ bundle exec itamae ssh --dry-run --key ~/.ssh/#{key_name}.pem --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb roles/app/default.rb
```

その後、itamae を apply します。

```
(Mac) $ bundle exec itamae ssh --key ~/.ssh/#{key_name}.pem --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb roles/app/default.rb
```

MySQL 用の gem をインストールします。
この作業は Mac 上で行います。

```
(Mac) $ ${EDITOR} Gemfile
(Mac) $ bundle install -j4 --without test production
```

```diff
diff --git a/Gemfile b/Gemfile
index 5ad6e30..eb028f3 100644
--- a/Gemfile
+++ b/Gemfile
@@ -8,6 +8,8 @@ gem 'kaminari'
 gem 'puma', '~> 3.11'
 gem 'sqlite3'

+gem 'mysql2'
+
 gem 'bootsnap', '>= 1.1.0', require: false
```

```
(Mac) $ bundle install -j4 --without test production
```

アプリケーションの設定を sqlite から MySQL へと切り替えます。

```
(Mac) $ ${EDITOR} config/database.yml
```

```diff
diff --git a/config/database.yml b/config/database.yml
index 1c1a37c..96c9a85 100644
--- a/config/database.yml
+++ b/config/database.yml
@@ -21,5 +21,8 @@ test:
   database: db/test.sqlite3

 production:
-  <<: *default
-  database: db/production.sqlite3
+  adapter: mysql2
+  database: slackpad_server
+  username: slackpad_server
+  password: ji2yodankai
+  encoding: utf8mb4
```

commit して push した上で、DB のマイグレートを行います。

```
(Mac) $ bundle exec cap production deploy
```

MySQL にログインし、初期データを読み込みます。

```
(EC2) $ cd /home/ubuntu
(EC2) $ aws s3 cp s3://cookpad-infra-summer-internship-2018/sample-data.tar.gz .
(EC2) $ tar zxvf sample-data.tar.gz
(EC2) $ sudo mysql -uroot

(EC2) mysql> use slackpad_server;
(EC2) mysql> ALTER TABLE images CHANGE COLUMN data data longblob; /* MySQL の text 型は sqlite と違い制限が厳しく画像が入らないため画像を入れる用の longblob に事前に変換する */
(EC2) mysql> load data local infile '/home/ubuntu/sample-data/channels.csv' into table channels FIELDS TERMINATED BY ',' (id, name, updated_at, created_at);
(EC2) mysql> load data local infile '/home/ubuntu/sample-data/messages.csv' into table messages FIELDS TERMINATED BY ',' (id, channel_id, nickname, message, updated_at, created_at);
(EC2) mysql> load data local infile '/home/ubuntu/sample-data/images.csv' into table images FIELDS TERMINATED BY ',' (id, filename, data, updated_at, created_at);
(EC2) mysql> load data local infile '/home/ubuntu/sample-data/reactions.csv' into table reactions FIELDS TERMINATED BY ',' (id, message_id, nickname, emoji, updated_at, created_at);
```

## 遅いクエリとクエリの高速化

クエリの速度はサービスにパフォーマンスに大きく寄与します。
ここからは、よくある遅いクエリのパターンと、どのようにしてクエリをチューニングしていくかについて見ていきます。

### スロークエリ

まず、実際に実行されている遅いクエリがどういったクエリなのか知ることが必要になります。
MySQL では、実行に特定の時間以上掛かったクエリ(スロークエリ)をロギングする機能があります。

MySQL にスロークエリのログを出力する設定を追加してみましょう。

```
(Mac) $ mkdir -p itamae/cookbooks/mysql/files/etc/mysql/mysql.conf.d
(Mac) $ ${EDITOR} itamae/cookbooks/mysql/files/etc/mysql/mysql.conf.d/slow_query_log.cnf
```

MySQL の設定ファイルで、スロークエリのログを有効にし、スロークエリと判定する秒数を設定します。

```
[mysqld]
slow_query_log
long_query_time = 0.05
slow_query_log_file = /var/lib/mysql/slow.log
```

Itamae で当該ファイルをサーバに置き、mysqld を再起動する設定を追加します。

```
(Mac) $ ${EDITOR} itamae/cookbooks/mysql/default.rb
```

```diff
diff --git a/itamae/cookbooks/mysql/default.rb b/itamae/cookbooks/mysql/default.rb
index fc1331c..ccc1bee 100644
--- a/itamae/cookbooks/mysql/default.rb
+++ b/itamae/cookbooks/mysql/default.rb
@@ -18,3 +18,13 @@ execute %q{mysql -uroot -e 'grant all on `slackpad_server`.* to "slackpad_server
   user 'root'
   not_if %q{mysql -uroot -e "select user from mysql.user" | grep slackpad_server}
 end
+
+remote_file '/etc/mysql/mysql.conf.d/slow_query_log.cnf' do
+  owner 'root'
+  group 'root'
+  mode '644'
+end
+
+service 'mysql' do
+  subscribes :restart, 'remote_file[/etc/mysql/mysql.conf.d/slow_query_log.cnf]'
+end
```

その後、itamae を apply します。

```
(Mac) $ bundle exec itamae ssh --dry-run --key ~/.ssh/#{key_name}.pem --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb roles/app/default.rb
```

実際にアプリケーションにアクセスしてみると、スロークエリがログに出力されていることを確認できます。

```
(EC2) $ sudo tail -f /var/lib/mysql/slow.log
# Time: 2018-08-30T13:37:49.981180Z
# User@Host: slackpad_server[slackpad_server] @ localhost []  Id:     7
# Query_time: 5.813795  Lock_time: 0.000154 Rows_sent: 142  Rows_examined: 4544569
SET timestamp=1535636269;
SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` IN (2539415, 2539365, 2539219, 2539205, 2539172, 2539082, 2539042, 2538971, 2538896, 2538738, 2538583, 2538468, 2538357, 2538353, 2538346, 2538221, 2538174, 2538130, 2537975, 2537844, 2537811, 2537769, 2537644, 2537208, 2537183, 2537139, 2537124, 2537103, 2536985, 2536843, 2536831, 2536741, 2536470, 2536445, 2536410, 2536383, 2536202, 2536123, 2535966, 2535867, 2535845, 2535720, 2535719, 2535643, 2535620, 2535417, 2535254, 2535170, 2535168, 2535093, 2535032, 2535004, 2534900, 2534877, 2534761, 2534754, 2534668, 2534614, 2534587, 2534585, 2534536, 2534533, 2534478, 2534446, 2534434, 2534425, 2534250, 2534210, 2534136, 2533721, 2533608, 2533525, 2533480, 2533356, 2533200, 2533090, 2532863, 2532698, 2532683, 2532585, 2532563, 2532374, 2532256, 2532206, 2532136, 2531892, 2531727, 2531584, 2531460, 2531438, 2531381, 2531369, 2531331, 2531297, 2531178, 2530892, 2530687, 2530634, 2530626, 2530620);
```

### EXPLAIN 句

クエリのチューニングでは、基本的に `EXPLAIN` 句を使い、クエリがどのように実行されるかを確認し、
その結果に応じて、高速化の手法を考えていきます。

```
mysql> use slackpad_server;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> EXPLAIN SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` IN (2539415, 2539365, 2539219, 2539205, 2539172, 2539082, 2539042, 2538971, 2538896, 2538738, 2538583, 2538468, 2538357, 2538353, 2538346, 2538221, 2538174, 2538130, 2537975, 2537844, 2537811, 2537769, 2537644, 2537208, 2537183, 2537139, 2537124, 2537103, 2536985, 2536843, 2536831, 2536741, 2536470, 2536445, 2536410, 2536383, 2536202, 2536123, 2535966, 2535867, 2535845, 2535720, 2535719, 2535643, 2535620, 2535417, 2535254, 2535170, 2535168, 2535093, 2535032, 2535004, 2534900, 2534877, 2534761, 2534754, 2534668, 2534614, 2534587, 2534585, 2534536, 2534533, 2534478, 2534446, 2534434, 2534425, 2534250, 2534210, 2534136, 2533721, 2533608, 2533525, 2533480, 2533356, 2533200, 2533090, 2532863, 2532698, 2532683, 2532585, 2532563, 2532374, 2532256, 2532206, 2532136, 2531892, 2531727, 2531584, 2531460, 2531438, 2531381, 2531369, 2531331, 2531297, 2531178, 2530892, 2530687, 2530634, 2530626, 2530620);
+----+-------------+-----------+------------+------+---------------+------+---------+------+---------+----------+-------------+
| id | select_type | table     | partitions | type | possible_keys | key  | key_len | ref  | rows    | filtered | Extra       |
+----+-------------+-----------+------------+------+---------------+------+---------+------+---------+----------+-------------+
|  1 | SIMPLE      | reactions | NULL       | ALL  | NULL          | NULL | NULL    | NULL | 4424171 |    50.00 | Using where |
+----+-------------+-----------+------------+------+---------------+------+---------+------+---------+----------+-------------+
1 row in set, 1 warning (0.01 sec)
```

EXPLAIN 句は上記のような出力になります。

それぞれのカラムには当然意味がありますが、今回は `rows` に着目してください。
これは、どのくらいの行を取得する予定かを表した値です。

`reactions` テーブルにはたくさん値が入っているので、
条件に合致するようなカラムを探すために、全てのカラムを取得して、その後必要な値を選別する、
といった処理をしていると、行数の増加に応じて処理数が増えていってしまいます。

### インデックス

RDBMS では、インデックスという索引を付けることで、より効率的に必要なデータのみを取得できる機能があります。
MySQL の InnoDB におけるインデックスは、B+ Tree というデータ構造で実装されています。

B+ Tree とは、次のような特徴を持った木構造です。

- 次数を d としたとき 各内部ノードは最大 d-1 個のキーと d 個までの子ノードを持つ
- 内部ノードは値を持たない
- 葉ノードの各キーは値(もしくは値へのポインタ)を持つ
- `O(log d n)` で検索できる

InnoDB のインデックスでは、次数が 3 の B+ Tree が使用されています。
B+ Tree のデータ構造は次のページで可視化されています。

https://www.cs.usfca.edu/~galles/visualization/BPlusTree.html

また、MySQL の InnoDB におけるインデックスには、クラスタインデックスとセカンダリインデックスの 2 つの種類があります。　

クラスタインデックスとは、テーブルで主キーやユニークキーが定義された時に自動的に追加される、主キーもしくはユニークキーによるによるインデックスです。
クラスタインデックスでは、葉ノードの値として当該のキーの行のすべてのデータを格納しています。そのため、主キーによる検索は非常に高速に行うことが可能になっています。

それ以外のインデックスはセカンダリインデックスと呼ばれます。InnoDB では 0〜複数個のインデックスをテーブルに対して定義することが出来ます。
セカンダリインデックスでは、使用されているカラムの値と主キーの値のペアが葉ノードの値として格納されています。

セカンダリインデックスにおける検索では、葉ノードに到達した段階でも、主キーとカラムのペアしか取得することが出来ないため、
主キーとインデックスに使用しているカラム以外の値を取得しようとした場合、再度クラスタインデックスによる検索を掛ける必要があります。
これはクラスタインデックスのみの検索より、おおよそ倍程度の工程がかかってしまいます。

逆に、セカンダリインデックスとして使用されているカラム(と主キー)のみを取得する場合は 1 回の探索で済むため、
主キーによる検索と同程度の速度で完了させることが出来ます。
このように問い合わせた全てのカラムをインデックスがカバーしているようなインデックスは、カバリングインデックスとも呼ばれます。

例えば、`reactions` テーブルの `message_id` カラムに対してセカンダリインデックスが作られている場合、
次のようなクエリは高速に動作します (`message_id` のインデックスは次のクエリのカバリングインデックスであると言えます) 。

```
SELECT `reactions`.message_id FROM `reactions` WHERE `reactions`.`message_id` IN (2539415, 2539365, 2539219, 2539205, 2539172);
```

また、セカンダリインデックスは複数のカラムの組を指定することが出来ます。
このようなインデックスを、複合インデックスと呼びます。

セカンダリインデックスの作成は、`CREATE INDEX` 句 (もしくは `ALTER TABLE ADD INDEX` 句) で行えます。
例えば、`reactions` テーブルに、`message_id` と `created_at` カラムの複合インデックスを貼りたい場合は、次のようにします。

```
ALTER TABLE messages ADD INDEX index_reactions_on_message_id_and_created_at(message_id, created_at);
```

複合インデックスのカラムの順序には意味があり、1 番目以外の値のみで検索するときにはインデックスが使用されません。
例えば、上記のインデックスを設定した状態でも、次のクエリではインデックスが使用されません。

```
SELECT * FROM reactions WHERE created_at > '2018-07-24 16:25:00' LIMIT 10;
```

上記のクエリでインデックスが使用されるようにするには、
`created_at` のみのインデックスを作成するか、最初のカラムとして `created_at` を指定した複合インデックスを作成する必要があります。

### どういったカラムにインデックスを作成するか

前項では、インデックスの有用性について説明しましたが、全てのカラムに対してインデックスを貼れば良いというわけではありません。
インデックスを作成した場合には、インデックス分のデータ容量の増大や、更新・削除のオーバヘッドが発生してしまいます。

そのため、インデックスを作成するカラムは正しく見極めなければなりません。
その要素の一つとして、カラムの選択性というものがあります。

例えば、ある事柄が有効になっているかどうかを判別する `flag` という、0 と 1 のみ偏りなく格納される予定のカラムがあったとします。
このような `flag` では、インデックスを貼っても大きな効果は得られません。
このようなフラグの取りうる値のバリエーションをカーディナリティと呼んだりします。
基本的には、カーディナリティの高く頻繁に使用されるようなカラムに対してのみ、インデックスを貼ることを推奨します。

### セカンダリインデックスの作成

Rails では、マイグレーションファイルを作成してインデックスを作成することが出来ます。

まず `rails g migration` コマンドで、ファイルを作成します。

```
$ bin/rails g migration AddIndexToReactions
      invoke  active_record
      create    db/migrate/20180830134615_add_index_to_reactions.rb
```

作成したマイグレーションファイルを次のように編集します。

```
$ vim db/migrate/#{上記のコマンドで作られたマイグレーションファイルのファイル名}
```

```
class AddIndexToReactions < ActiveRecord::Migration[5.2]
  def change
    add_index :reactions, [:message_id]
  end
end
```

commit して push した上で、デプロイを行いマイグレーションを反映させます。

```
(Mac) $ bundle exec cap production deploy
... (snip) ...
00:10 deploy:migrating
      [deploy:migrate] Run `rake db:migrate`
00:10 deploy:migrating
      01 bundle exec rake db:migrate
      01 == 20180830134615 AddIndexToReactions: migrating ==============================
      01 -- add_index(:reactions, [:message_id])
      01    -> 21.2247s
      01 == 20180830134615 AddIndexToReactions: migrated (21.2248s) ====================
      01
... (snip) ...
```

実際にページにアクセスしてみます。

```
(Mac) $ curl http://#{EC2 インスタンスの IP アドレス}/channels/1/messages
```

再度 EXPLAIN 句を用いて、実行計画がどのように変わったかを確認してみましょう。

```
mysql> EXPLAIN SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` IN (2539415, 2539365, 2539219, 2539205, 2539172, 2539082, 2539042, 2538971, 2538896, 2538738, 2538583, 2538468, 2538357, 2538353, 2538346, 2538221, 2538174, 2538130, 2537975, 2537844, 2537811, 2537769, 2537644, 2537208, 2537183, 2537139, 2537124, 2537103, 2536985, 2536843, 2536831, 2536741, 2536470, 2536445, 2536410, 2536383, 2536202, 2536123, 2535966, 2535867, 2535845, 2535720, 2535719, 2535643, 2535620, 2535417, 2535254, 2535170, 2535168, 2535093, 2535032, 2535004, 2534900, 2534877, 2534761, 2534754, 2534668, 2534614, 2534587, 2534585, 2534536, 2534533, 2534478, 2534446, 2534434, 2534425, 2534250, 2534210, 2534136, 2533721, 2533608, 2533525, 2533480, 2533356, 2533200, 2533090, 2532863, 2532698, 2532683, 2532585, 2532563, 2532374, 2532256, 2532206, 2532136, 2531892, 2531727, 2531584, 2531460, 2531438, 2531381, 2531369, 2531331, 2531297, 2531178, 2530892, 2530687, 2530634, 2530626, 2530620);
+----+-------------+-----------+------------+-------+-------------------------------+-------------------------------+---------+------+------+----------+----------------------------------+
| id | select_type | table     | partitions | type  | possible_keys                 | key                           | key_len | ref  | rows | filtered | Extra                            |
+----+-------------+-----------+------------+-------+-------------------------------+-------------------------------+---------+------+------+----------+----------------------------------+
|  1 | SIMPLE      | reactions | NULL       | range | index_reactions_on_message_id | index_reactions_on_message_id | 4       | NULL |  172 |   100.00 | Using index condition; Using MRR |
+----+-------------+-----------+------------+-------+-------------------------------+-------------------------------+---------+------+------+----------+----------------------------------+
```

### N+1 クエリ

`/channels/:channel_id/messages` のエンドポイントにアクセスすると、次のようなログが出力されます。

```
(EC2) $ tail -28 /home/ubuntu/slackpad-server/shared/log/production.log
D, [2018-08-31T00:18:23.907481 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Channel Load (0.2ms)  SELECT  `channels`.* FROM `channels` WHERE `channels`.`id` = 1 LIMIT 1
D, [2018-08-31T00:18:25.051204 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Message Load (1139.1ms)  SELECT  `messages`.* FROM `messages` WHERE `messages`.`channel_id` = 1 ORDER BY `messages`.`id` DESC, `messages`.`created_at` DESC LIMIT 25 OFFSET 0
D, [2018-08-31T00:18:25.058217 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.3ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029502
D, [2018-08-31T00:18:25.062690 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029450
D, [2018-08-31T00:18:25.063426 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029401
D, [2018-08-31T00:18:25.064258 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029393
D, [2018-08-31T00:18:25.065183 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029371
D, [2018-08-31T00:18:25.066019 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029196
D, [2018-08-31T00:18:25.066831 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029192
D, [2018-08-31T00:18:25.067528 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3029132
D, [2018-08-31T00:18:25.068145 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028796
D, [2018-08-31T00:18:25.068858 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028748
D, [2018-08-31T00:18:25.069593 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028731
D, [2018-08-31T00:18:25.070452 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028573
D, [2018-08-31T00:18:25.071345 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028547
D, [2018-08-31T00:18:25.072051 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028512
D, [2018-08-31T00:18:25.072919 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028452
D, [2018-08-31T00:18:25.073636 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028351
D, [2018-08-31T00:18:25.074382 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028235
D, [2018-08-31T00:18:25.075271 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028219
D, [2018-08-31T00:18:25.075963 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028207
D, [2018-08-31T00:18:25.076835 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3028205
D, [2018-08-31T00:18:25.077720 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3027871
D, [2018-08-31T00:18:25.078355 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3027775
D, [2018-08-31T00:18:25.079110 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3027750
D, [2018-08-31T00:18:25.080008 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3027725
D, [2018-08-31T00:18:25.080699 #6084] DEBUG -- : [7d2c686d-9cd5-41dc-8cc5-f0b54e3122fc]   Reaction Load (0.2ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` = 3027693
```

これは、取得してきた `messages` の 25 件それぞれに対して、`reactions` をそれぞれ取得してくるために発生しています。

アプリケーションサーバとデータベースサーバのやりとりが複数発生してしまうため遅くなってしまうというデメリットや、
例えば、`messages` を一気に 100 件取ってきたい場合などには似たような SQL が 100 回発行されてしまう、という問題があります。
このような問題を、N+1 問題と表現したりします(クエリが合計で取得するデータの数 + 1 件発行されるため)。

これを解消するには、Rails では、`joins` や `preload` や `include` や `eager_load` のような機能を使用します。
これらは、基本的には SQL の JOIN というテーブル結合の機能や、Rails 内のキャッシュを使用して実現しています。

このような N+1 問題を検出するために、[bullet](https://github.com/flyerhzm/bullet) などの Gem があります。

実際に、`preload` を使ってこの N+1 クエリが発行されないようにアプリケーションを直してみましょう。

```
diff --git a/app/controllers/messages_controller.rb b/app/controllers/messages_controller.rb
index a0bc477..a8961a6 100644
--- a/app/controllers/messages_controller.rb
+++ b/app/controllers/messages_controller.rb
@@ -1,6 +1,6 @@
 class MessagesController < ApplicationController
   def index
-    messages = Channel.find(params[:channel_id]).messages.order(id: :desc, created_at: :desc).page(params[:page]).per(params[:per_page])
+    messages = Channel.find(params[:channel_id]).messages.includes(:reactions).order(id: :desc, created_at: :desc).page(params[:page]).per(params[:per_page])
     render json: JSON.dump(messages.map { |message| message.serializable_hash(include: :reactions) })
   end
```

この変更を commit して push した後、デプロイしてみてログがどのように変化したか見てみましょう。

```
$ tail -3 /home/ubuntu/slackpad-server/shared/log/production.log
D, [2018-08-31T00:28:53.901374 #6354] DEBUG -- : [4bb4b62a-1d2c-4e2d-8154-1e2dbf694468]   Message Load (1133.5ms)  SELECT  `messages`.* FROM `messages` WHERE `messages`.`channel_id` = 1 ORDER BY `messages`.`id` DESC, `messages`.`created_at` DESC LIMIT 25 OFFSET 0
D, [2018-08-31T00:28:53.908953 #6354] DEBUG -- : [4bb4b62a-1d2c-4e2d-8154-1e2dbf694468]   Reaction Load (0.7ms)  SELECT `reactions`.* FROM `reactions` WHERE `reactions`.`message_id` IN (3029502, 3029450, 3029401, 3029393, 3029371, 3029196, 3029192, 3029132, 3028796, 3028748, 3028731, 3028573, 3028547, 3028512, 3028452, 3028351, 3028235, 3028219, 3028207, 3028205, 3027871, 3027775, 3027750, 3027725, 3027693)
I, [2018-08-31T00:28:53.919203 #6354]  INFO -- : [4bb4b62a-1d2c-4e2d-8154-1e2dbf694468] Completed 200 OK in 1163ms (Views: 0.1ms | ActiveRecord: 1136.7ms)
```

`reactions` の取得クエリが `IN` 句を使って 1 クエリにまとまっていることが確認できます。アプリケーションやデータの条件によっては、`eager_load` や `joins` の方が高速に動作するケースもあるので、よく考えて選択してみましょう。

## 参考文献

- http://techlife.cookpad.com/entry/2017/04/18/092524
- https://www.cs.usfca.edu/~galles/visualization/BPlusTree.html
- http://qiita.com/kiyodori/items/f66a545a47dc59dd8839
- http://qiita.com/k0kubun/items/80c5a5494f53bb88dc58
