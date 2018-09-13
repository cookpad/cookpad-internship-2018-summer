# 概要

<!-- TOC -->

- [概要](#概要)
    - [チャットアプリケーションの仕様](#チャットアプリケーションの仕様)
    - [セットアップ](#セットアップ)

<!-- /TOC -->

## チャットアプリケーションの仕様
今回のチャットアプリケーション API は REST API と WebSocket API を提供します。
API の仕様は <https://cookpad.github.io/cookpad-internship-2018-summer/slackpad-server/> にまとまっています。

## セットアップ
まず以下のコマンドを実行し、手元で slackpad-server アプリケーションの起動まで実施してください。

```console
$ git clone git@github.com:cookpad/cookpad-internship-2018-summer.git
$ cd cookpad-internship-2018-summer/slackpad-server/
$ bin/setup
$ bin/rails s
=> Booting Puma
=> Rails 5.2.0 application starting in development 
=> Run `rails server -h` for more startup options
Puma starting in single mode...
* Version 3.11.4 (ruby 2.3.7-p456), codename: Love Song
* Min threads: 5, max threads: 5
* Environment: development
* Listening on tcp://0.0.0.0:3000
Use Ctrl-C to stop
```

<a href="02-trying" class="float-right">アプリケーションを動かしてみる &raquo;</a>
