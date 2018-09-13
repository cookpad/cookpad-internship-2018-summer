# パフォーマンスモニタリング

> Don't guess! Measure!

パフォーマンスモニタリングのためのツールには、大きく分けて以下のように分けられます。

- 何らかのイベントが発生するたびにインクリメントされる**カウンタ**の情報を集めて表示する
  - top, dstat など
- 実際の処理に割り込んで情報を集めて表示する**トレーシング**する
  - perf, strace, SystemTap, DTrace など
  - たとえば `read` システムコールをトラップして、読み込んだバイト数のヒストグラムを作成する、などといったことができる

ここでは、システム全体のモニタリングを行うためのカウンタ型のツール群の紹介と、Linux 用のプロファイリングツールである perf と Rack アプリケーション用のプロファイリングツールである rack-lineprof を紹介します。

## システム全体のモニタリング

### カウンタの情報を使うツール

```
# みんな大好き。プロセスごとの CPU 専有時間、ロードアベレージ、メモリの使用量をリアルタイムに観測できる
(EC2) $ top

# top のリッチ版。CPU 利用率の棒グラフが出てているなど、おしゃれ
(EC2) $ htop

# システム全体の CPU 利用率や IO の利用状況などを 1 行ごとに出力する
(EC2) $ vmstat 1

# vmstat のリッチ版。オプション次第でいろいろな情報を表示できる
(EC2) $ dstat -tampl

# プロセッサのコアごとの様子を観測できる
(EC2) $ mpstat -P ALL 1

# top の IO 版
(EC2) $ iotop
```

以上のツールは、`/proc` 以下の情報を読み取って人間にとってわかりやすい形で表示するようなものとなっています。`/proc` 以下のディレクトリやファイルは実際にディスクに存在するわけではありませんが、読み書きすることでシステムやプロセスの状態を取得したり変更したりすることができます。

ここでは深く立ち入りませんが、`man proc` を読んで手を動かしてみると Linux に対する理解がより深まるでしょう。また、興味があれば「ぼくのかんがえたさいきょうのモニタリングツール」を自作することも可能です。

### AWS CloudWatch

AWS のマネジメントコンソールからインスタンスを選択し、Monitoringを開くことで、メトリックが閲覧できます。

## プロファイラを使ってみよう

ここでは、perf と rack-lineprof というプロファイラについて学びます。

perf は Linux 用のパフォーマンス解析ツールで、C 言語レベルでどの関数の実行に時間がかかっているのかなどの解析を手軽に行うことができます。また、rack-lineprof は Rack アプリケーションに特化したツールで、Ruby レベルで処理に時間をかかっているメソッドの抽出などを行うことができます。

### perf

では、perf を使って C 言語レベルでのプロファイリングを体験してみましょう。ローカルの itamae/roles/app/default.rb に以下のように追記し、前の章のように `itamae apply` を実行し、必要なパッケージをインストールします。

```ruby
package 'linux-tools-aws' do
  action :install
end

package 'linux-tools-4.4.0-1061-aws' do
  action :install
end
```

```
(Mac) $ bundle exec itamae ssh --dry-run --key ~/.ssh/#{key_name}.pem --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb roles/app/default.rb
```

システム全体の関数ごとの CPU 使用率を top 風に表示するためには `top` サブコマンドを利用できます。

```
(EC2) $ sudo perf top
```

また、プロセスごとの解析も可能です。以下の例は `/dev/zero` からデータを読み込んでは `/dev/null` に捨てるだけのコマンドを perf で解析した結果です。

```
(EC2) $ sudo perf record -g dd if=/dev/zero of=/dev/null
(EC2) $ sudo perf report
```

glibc から `read()` や `write()` が呼ばれ、さらにカーネル空間で実行される `sys_read()` や `sys_write()` が処理時間の大半であることがわかります。

では、`/dev/zero` ではなく `/dev/urandom` から読むようにコマンドを変更して解析してみましょう。

```
(EC2) $ sudo perf record -g dd if=/dev/urandom of=/dev/null
(EC2) $ sudo perf report
```

今度は `read()` システムコールに処理時間が偏っていることがわかります。コールスタックを深掘りすると、カーネルで実行される `urandom_read()` の処理が重いことがわかります。単純に 0 を読み込むのに比べて乱数を生成するためにはより多くの計算が必要なことは想像でき、これらのプロファイリング結果はそれを説明するものといえるでしょう。

### rack-lineprof

ここからは、Rack アプリケーションのプロファイリングのためのツールである rack-lineprof について説明します。

https://github.com/kainosnoema/rack-lineprof

rack-lineprof は Rack ミドルウェアとして動作し、プロファイル対象のファイルのコードのメソッド呼び出しにどのくらいの時間がかかっているのかを可視化するツールです。では、実際に rack-lineprof を組み込んでみましょう。Gemfile と config/environments/production.rb を以下のように変更し、Capistrano で EC2 にデプロイしてください。

```diff
diff --git a/Gemfile b/Gemfile
index 80a5c7d..99f3e75 100644
--- a/Gemfile
+++ b/Gemfile
@@ -10,6 +10,8 @@ gem 'sqlite3'

 gem 'bootsnap', '>= 1.1.0', require: false

+gem 'rack-lineprof'
+
 group :development, :test do
   gem 'byebug'
   gem 'pry-byebug'
```

```diff
diff --git a/config/environments/production.rb b/config/environments/production.rb
index af59a73..fa16c0c 100644
--- a/config/environments/production.rb
+++ b/config/environments/production.rb
@@ -82,4 +82,6 @@ Rails.application.configure do

   # Do not dump schema after migrations.
   config.active_record.dump_schema_after_migration = false
+
+  config.middleware.use Rack::Lineprof
```

変更後に、手元のマシンで `bundle install` を行い、`git commit` の後に `git push` し、`bundle exec cap production deploy` をすることでデプロイします。

rack-lineprof のログは以下のコマンドを実行しておくと閲覧できます。

```
(EC2) $ journalctl -f -u slackpad-server
```

以下のコマンドは `/channels` の API を呼び出したときに app/controllers 以下の Ruby ファイルを対象にプロファイリングを行う例です。

```
(Mac) $ curl 'http://#{EC2 の IP アドレス}/channels?lineprof=app/controllers' > /dev/null 2>&1
```

このコマンドを実行すると、以下のようなログが出力されるでしょう。

```
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]: [Rack::Lineprof] ===============================================================
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]: app/controllers/channels_controller.rb
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]:                |   1  class ChannelsController < ApplicationController
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]:                |   2    def index
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]:    8.1ms     5 |   3      render json: JSON.dump(Channel.all.to_a.map(&:serializable_hash))
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]:                |   4    end
Jul 20 08:07:31 ip-172-31-4-135 bundle[31085]:                |   5  end
```

# その他のアプリケーションプロファイラ

rack-lineprof は Rails の controller や model 等のプロファイリングをする際に非常に有用ですが、
今回の Websocket の例のように、Rack の処理内で完結しないようなアプリケーションや、Rack を用いないようなの Ruby コードのプロファイリングをする際には、
標準ライブラリの [profile](https://docs.ruby-lang.org/ja/2.5.0/library/profile.html) や、 [ruby-prof](https://github.com/ruby-prof/ruby-prof) などのライブラリを用いることが出来ます。

ここでは、`ruby-prof` を導入して chat 部分のプロファイリングを試してみます。

Gemfile に次のようにして `ruby-prof` を追加し、手元で `bundle install` します。

```
diff --git a/Gemfile b/Gemfile
index fae6861..5ad6e30 100644
--- a/Gemfile
+++ b/Gemfile
@@ -11,7 +11,7 @@ gem 'sqlite3'
 gem 'bootsnap', '>= 1.1.0', require: false

 gem 'rack-lineprof'
-gem 'stackprof'
+gem 'ruby-prof'
```

次に、`app/middlewares/chat_app.rb` のプロファイリングしたい箇所に次のようなコードを挿入します。


```
diff --git a/app/middlewares/chat_app.rb b/app/middlewares/chat_app.rb
index fb2fec6..54d5210 100644
--- a/app/middlewares/chat_app.rb
+++ b/app/middlewares/chat_app.rb
@@ -50,6 +50,7 @@ class ChatApp
   private

   def process_message(event)
+    RubyProf.start
     ws = event.current_target
     prefix, command, params = parse_message(event.data)
     case command
@@ -81,6 +82,9 @@ class ChatApp
     else
       raise ChatMessageError, "Unknown command: #{command}"
     end
+    result = RubyProf.stop
+    printer = RubyProf::FlatPrinter.new(result)
+    printer.print(STDOUT)
   rescue ChatMessageError => e
     reply(ws, SYSTEM_NAME, :error, [e.message])
   end
```

これを `git commit` し、`git push` した後に `bundle exec cap production deploy` を実行してデプロイします。

その後、EC2 インスタンスにログインし、変更を反映させるために slackpad-server を再起動し、Rails の標準出力を確認します。

```
(EC2) $ sudo systemctl restart slackpad-server
(EC2) $ sudo journalctl -f -u slackpad-server
```

実行しながら、別のウィンドウでチャットに join してユーザを名乗ってみます。

```
(Mac) $ bin/setup
(Mac) $ yarn run wscat --connect '#{インスタンスのIPアドレス}/ws'
:
> user ["rrreeeyyy"]
```

すると、EC2 側のウィンドウに次のようにプロファイリング結果が出力されます。

```
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: Measure Mode: wall_time
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: Thread ID: 20632100
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: Fiber ID: 21902340
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: Total Time: 0.03305792808532715
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: Sort by: total_time
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:   %total   %self      total       self       wait      child            calls     name
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: --------------------------------------------------------------------------------
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:  100.00%   0.08%      0.033      0.000      0.000      0.033                1     ChatApp#process_message
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.033      0.000      0.000      0.033              1/1     ChatApp#join_channel
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000              1/2     ChatApp#reply
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000              1/1     ChatApp#parse_message
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000             1/66     Kernel#hash
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000             1/22     Array#include?
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000              1/6     Hash#values
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]: --------------------------------------------------------------------------------
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.033      0.000      0.000      0.033              1/1     ChatApp#process_message
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:   98.85%   0.25%      0.033      0.000      0.000      0.033                1     ChatApp#join_channel
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.032      0.000      0.000      0.032              1/1     ActiveRecord::Querying#find_or_create_by!
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000              1/1     Set#each
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000            1/146     Class#new
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000              1/1     Set#add
Jul 20 12:02:56 ip-172-31-4-135 bundle[2862]:                       0.000      0.000      0.000      0.000             1/66     Kernel#hash
:
```

上部の Total Time がプロファイリングを仕込んだ箇所の処理が終わるまでに掛かった合計の時間で、
合計の時間から、それぞれのメソッドにかかった時間が表示されています。

また、`---` から後ろに続く部分では、`ChatApp#process_message` がどのメソッドを呼んだか、また、呼んだメソッドでどの程度時間が掛かったかが記されています。
これをどんどん追っていくことで、最終的にどのメソッドで時間が掛かっているのか特定することができるようになっています。

# クックパッドにおけるパフォーマンスモニタリング

クックパッドでは、ここまで紹介してきたモニタリングツールの他に、以下のようなものを利用しています。

- [Zabbix](https://www.zabbix.com/jp/)
  - OSS の監視モニタリングツール。パフォーマンスモニタリングのほか、サーバの死活監視や異常検知にも利用
- [Prometheus](https://prometheus.io/)
  - OSS の監視モニタリングツール。データの取得方法 (pull) やストレージ (TSDB) など、Zabbix とは違ったアプローチが採用されており次世代監視ツールとも言われる
- [New Relic](https://newrelic.com/)
  - 監視、モニタリングを提供する SaaS。 stackprof で取得したようなアプリケーションの詳細な情報を可視化して表示、分析することが可能 (クックパッドではこの機能のみを利用)
- [DataDog](https://www.datadoghq.com/)
  - 監視、モニタリングを提供する SaaS。 New Relic と同様だが、サーバメトリクスなどの収集、表示に強い

