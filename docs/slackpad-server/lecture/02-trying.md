# アプリケーションを動かしてみる

API の仕様 <https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/> を参考にしつつ
セットアップしたアプリケーションを実際に手元で動かしてみましょう。

<!-- TOC -->

- [アプリケーションを動かしてみる](#アプリケーションを動かしてみる)
    - [API 開発用ツールのインストール](#api-開発用ツールのインストール)
    - [REST API](#rest-api)
    - [Chat Protocol (WebSocket)](#chat-protocol-websocket)
    - [テスト (RSpec) を実行する](#テスト-rspec-を実行する)

<!-- /TOC -->

## API 開発用ツールのインストール
REST API 開発のために `curl`, `jq` コマンドを利用します。
jq コマンドはおそらくみなさんのマシンにまだはいっていないと思うので以下のコマンドでインストールしてください。

```console
$ brew install jq
```

この資料では curl コマンドをクライアントとして紹介していますが、好みのクライアントがある方は
それらを利用して問題ありません。
[Postman](https://www.getpostman.com/) なども便利で割とオススメできます。

## REST API
仕様 <https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/#rest-api>
を参考に手元の slackpad-server の REST API にリクエストを送ってみましょう。

例として [`GET /channels`](https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/#get-channels) を叩いてみます。

```console
$ curl -s http://localhost:3000/channels | jq
[
  {
    "id": 1,
    "name": "general",
    "created_at": "2018-07-23 14:47:11 utc",
    "updated_at": "2018-07-23 14:47:11 utc"
  }
]
```

のようにチャンネル一覧が取得できます。

## Chat Protocol (WebSocket)
<https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/#chat-protocol-websocket>
などを参考に手元の slackpad-server のチャット機能にアクセスしてみましょう。

ここでは [wscat](https://www.npmjs.com/package/wscat) をクライアントとして利用してみます。

まず
[user コマンド](https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/#user-nickname)
でログインし、
[message コマンド](https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/#message-channel-message)
で general チャンネルにメッセージを送信してみましょう。

```console
$ yarn run wscat --connect localhost:3000/ws
yarn run v1.7.0
$ /Users/sunao-komuro/tmp/slackpad-server/node_modules/.bin/wscat --connect localhost:3000/ws
connected (press ctrl+c to quit)
> user ["hogelog"]
< :hogelog user ["hogelog"]
> message ["general", "こんにちは"]
< :hogelog message ["general","こんにちは"]
```

wscat の送ったメッセージに対してサーバがレスポンスを返してきています。
次にその wscat は起動したまま、別の wscat からも slackpad-server に接続してメッセージを送ってみましょう。

```console
$ yarn run wscat --connect localhost:3000/ws
yarn run v1.7.0
$ /Users/sunao-komuro/tmp/slackpad-server/node_modules/.bin/wscat --connect localhost:3000/ws
connected (press ctrl+c to quit)
> user ["sunao"]
< :sunao user ["sunao"]
> message ["general", "こんにちは！"]
< :sunao message ["general","こんにちは！"]
```

この状態で最初に起動した wscat に以下のメッセージが返ってきているはずです。

```console
< :sunao message ["general","こんにちは！"]
```

## テスト (RSpec) を実行する
clone してきた slackpad-server アプリケーションには rspec で書かれたテストが存在します。
このテストは slackpad-server という Rails アプリケーションが仕様通りに動作しているかをチェックしています。

以下のコマンドを実行してみてください。

（`bin/rails db:reset RAILS_ENV=test` は新規テーブルやカラムの変更などをしない限り最初の一回だけでいいです）

```console
$ bin/rails db:reset RAILS_ENV=test
$ bin/rspec
```

以下のような内容の、いかにも失敗してそうな結果が出力されているはずです。

```console
Capybara starting Puma...
* Version 3.11.4 , codename: Love Song
* Min threads: 0, max threads: 4
* Listening on tcp://127.0.0.1:60133
FFFFFFFF..

Failures:

  1) Chat user command success
     Failure/Error:
       expect($ws_messages).to eq([
         ':hogelog user ["hogelog"]',
         ':hogelog join ["general"]',
       ])

       expected: [":hogelog user [\"hogelog\"]", ":hogelog join [\"general\"]"]
            got: [":hogelog user [\"hogelog\"]"]

       (compared using ==)
     # ./spec/features/chat_spec.rb:31:in `block (3 levels) in <top (required)>'
     # ./spec/features/chat_spec.rb:21:in `block (2 levels) in <top (required)>'
...
Finished in 0.96812 seconds (files took 1.52 seconds to load)
10 examples, 8 failures

Failed examples:

rspec ./spec/features/chat_spec.rb:28 # Chat user command success
rspec ./spec/features/chat_spec.rb:39 # Chat join command success
rspec ./spec/features/chat_spec.rb:53 # Chat part command success
rspec ./spec/features/chat_spec.rb:68 # Chat message command success
rspec ./spec/features/chat_spec.rb:85 # Chat list command success
rspec ./spec/requests/api_spec.rb:9 # API GET /channels success
rspec ./spec/requests/api_spec.rb:22 # API GET /channels/:channel_id/messages success
rspec ./spec/requests/api_spec.rb:35 # API POST /channels/:channel_id/messages success
```

実装が不完全な slackpad-server の実装を進め、仕様通りの挙動を満たすようになった時にはこれらのテストは全て通り
`10 examples, 0 failures` のような結果が得られるはずです。

※ これらのテストを満たしていれば必ず仕様通りの動作をしていることを保証するものではありません。

<a href="01-overview" class="float-left">&laquo; 概要</a>
<a href="03-reading" class="float-right">アプリケーションを読み解いていく &raquo;</a>
