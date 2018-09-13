# 仕様

slackpad-server は REST API と Chat Protocol (WebSocket) を提供します。

<!-- TOC -->

- [仕様](#仕様)
    - [REST API](#rest-api)
        - [GET /channels](#get-channels)
            - [パラメタ](#パラメタ)
            - [例](#例)
        - [GET /channels/:channel_id/messages](#get-channelschannel_idmessages)
            - [パラメタ](#パラメタ-1)
            - [例](#例-1)
        - [POST /channels/:channel_id/messages](#post-channelschannel_idmessages)
            - [パラメタ](#パラメタ-2)
            - [例](#例-2)
        - [POST /images](#post-images)
            - [パラメタ](#パラメタ-3)
            - [例](#例-3)
        - [GET /images/:id](#get-imagesid)
            - [パラメタ](#パラメタ-4)
            - [例](#例-4)
    - [Chat Protocol (WebSocket)](#chat-protocol-websocket)
        - [フォーマット](#フォーマット)
            - [コマンド（クライアントメッセージ）](#コマンドクライアントメッセージ)
            - [リプライ（サーバメッセージ）](#リプライサーバメッセージ)
        - [コマンド](#コマンド)
            - [`user [<nickname>]`](#user-nickname)
                - [リプライ](#リプライ)
                - [例](#例-5)
            - [`join [<channel>]`](#join-channel)
                - [リプライ](#リプライ-1)
                - [例](#例-6)
            - [`part [<channel>]`](#part-channel)
                - [リプライ](#リプライ-2)
                - [例](#例-7)
            - [`message [<channel>, <message>]`](#message-channel-message)
                - [リプライ](#リプライ-3)
                - [例](#例-8)
            - [`list [<channel>]`](#list-channel)
                - [リプライ](#リプライ-4)
                - [例](#例-9)

<!-- /TOC -->

## REST API

REST API としては以下のエンドポイントが存在します。

- `GET /channels`
- `GET /channels/:channel_id/messages`
- `POST /channels/:channel_id/messages`
- `POST /images`
- `GET /images/:id`

### GET /channels
チャンネル一覧を取得。

#### パラメタ
<table>
<tr><th>パラメタ名</th><th>例</th><th></th></tr>
<tr><td>page</td><td>1</td><td>オプション</td></tr>
<tr><td>per_page</td><td>50</td><td>オプション</td></tr>
</table>

#### 例
```$console
$ curl -s http://localhost:3000/channels | jq
[
  {
    "id": 1,
    "name": "hogelog-channel",
    "created_at": "2018-07-12 13:42:18 UTC",
    "updated_at": "2018-07-12 13:42:18 UTC"
  },
  {
    "id": 2,
    "name": "general",
    "created_at": "2018-07-12 13:45:17 UTC",
    "updated_at": "2018-07-12 13:45:17 UTC"
  }
]
```

### GET /channels/:channel_id/messages
チャンネルの過去メッセージを受け取る。

#### パラメタ
<table>
<tr><th>パラメタ名</th><th>例</th><th></th></tr>
<tr><td>channel_id</td><td>1</td><td>必須</td></tr>
<tr><td>page</td><td>1</td><td>オプション</td></tr>
<tr><td>per_page</td><td>50</td><td>オプション</td></tr>
</table>

#### 例
```$console
$ curl -s 'http://localhost:3000/channels/1/messages?page=2' | jq
[
  {
    "id": 2,
    "nickname": "robot",
    "message": "こんにちわこんにちは！",
    "created_at": "2018-07-12 13:42:20 UTC",
  },
  {
    "id": 1,
    "nickname": "hogelog",
    "message": "Hello World!",
    "created_at": "2018-07-12 13:42:18 UTC",
  }
]
```

### POST /channels/:channel_id/messages
チャンネルにメッセージを投稿する。

#### パラメタ
<table>
<tr><th>パラメタ名</th><th>例</th><th></th></tr>
<tr><td>channel_id</td><td>1</td><td>必須</td></tr>
<tr><td>nickname</td><td>rrreeeyyy</td><td>必須</td></tr>
<tr><td>message</td><td>hello!</td><td>必須</td></tr>
</table>

#### 例
```$console
$ curl -s -X POST 'http://localhost:3000/channels/1/messages -d nickname=rrreeeyyy -d message="hello!"
{
  "id": 2,
  "channel_id": 1,
  "nickname": "rrreeeyyy",
  "message": "hello!",
  "created_at": "2018-07-27 10:54:11 UTC",
  "updated_at": "2018-07-27 10:54:11 UTC"
}
```

### POST /images
画像を投稿。

#### パラメタ
<table>
<tr><th>パラメタ名</th><th>例</th><th></th></tr>
<tr><td>filename</td><td>ok.gif</td><td>必須</td></tr>
<tr><td>data</td><td>R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAQQAOw==</td><td>必須</td></tr>
</table>

#### 例
```$console
$ curl -s -X POST http://localhost:3000/images -d filename=ok.gif -d data=R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAQQAOw==
{
  "id": 1,
  "filename": "ok.gif",
  "created_at": "2018-07-12 13:42:18 UTC",
  "updated_at": "2018-07-12 13:42:18 UTC"
}
```

### GET /images/:id
画像を取得。

#### パラメタ
<table>
<tr><th>パラメタ名</th><th>例</th><th></th></tr>
<tr><td>id</td><td>1</td><td>必須</td></tr>
</table>

#### 例
```$console
$ curl -v http://localhost:3000/images/1
...
< HTTP/1.1 200 OK
< Content-Type: image/gif
< Content-Disposition: inline
< Content-Transfer-Encoding: binary
< Cache-Control: private
< ETag: W/"8d7483433b479a6f6ecf7257fc636d85"
< X-Request-Id: 58d81b47-c7be-4fb6-80fe-10b0fa0982ad
< X-Runtime: 0.002065
< Transfer-Encoding: chunked
<
* Connection #0 to host localhost left intact
GIF89a,;
```

## Chat Protocol (WebSocket)
slackpad-server アプリケーションは /ws のパスで WebSocket ベースのチャット機能を提供する。
/ws に接続したクライアントには各クライアントが送った各種コマンドに対するリプライが送られてくる。

チャットコマンドとしては以下のコマンドが存在します。

- `user [<nickname>]`
- `join [<channel>]`
- `part [<channel>]`
- `message [<channel>, <message>]`
- `list [<channel>]`

### フォーマット
#### コマンド（クライアントメッセージ）
`<command> <params>`

- クライアントメッセージは command, params の組み合わせとなる。
  - command は実行するコマンドを示す
  - params はコマンドに対する引数を示す
- 区切り文字は半角スペース
- params は必ず JSON の配列となる

#### リプライ（サーバメッセージ）
`:<prefix> <command> <params>`

- サーバメッセージは prefix, command, params の組み合わせとなる。
  - prefix はコマンドを実行したユーザまたはシステム名を示す
  - command は実行されたコマンドを示す
  - params は実行されたコマンドに対する引数を示す
- 区切り文字は半角スペース
- params は必ず JSON の配列となる

### コマンド
#### `user [<nickname>]`
接続クライアントのユーザ名で認識させる。
実行直後に general チャンネルにジョインされる。
このコマンドを実行前に各種コマンドを送った場合の動作は未定義。

##### リプライ
- `:<nickname> user <nickname>`
  - コマンドを送ったユーザに送信される
- `:<nickname> join general`
  - コマンドを送ったクライアントおよび general にジョインしている全クライアントに送信される

##### 例
```
> user ["hogelog"]
< :hogelog user ["hogelog"]
< :hogelog join ["general"]
```

#### `join [<channel>]`
チャンネルにジョインする。
ジョインしたチャンネルでの message リプライが送られてくるようになる。

##### リプライ
- `:<nickname> join [<channel>]`
  - コマンドを送ったクライアントおよび `<channel>` にジョインしている全クライアントに送信される

##### 例
```
> join ["じぇねらる"]
< :hogelog join ["じぇねらる"]
```

#### `part [<channel>]`
チャンネルを抜ける。
抜けたチャンネルからは message リプライが送られてこなくなる。

##### リプライ
- `:<nickname> part [<channel>]`
  - コマンドを送ったクライアントおよび `<channel>` にジョインしている全クライアントに送信される

##### 例
```
> part ["じぇねらる"]
< :hogelog part ["じぇねらる"]
```

#### `message [<channel>, <message>]`
チャンネルにメッセージを送信する。

##### リプライ
- `:<nickname> message [<channel>, <message>]`
  - `<channel>` にジョインしている全クライアントに送信される

##### 例
```
> message ["general", "はろーはろー"]
< :hogelog message ["general","はろーはろー"]
< :sunao message ["general","こんにちは。"]
```

#### `list [<channel>]`
チャンネルにジョインしているニックネーム一覧を取得します。

##### リプライ
- `:slackpad list [<channel>, [<nickname1>, <nickname2>, ...]]`
  - コマンドを送信したユーザに送信される

##### 例
```
> list ["general"]
< :slackpad list ["general", ["hogelog", "sunao", "superman"]]
```
