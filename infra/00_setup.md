[note]

以下の資料において、実行すべきコマンドの中に `#{なにか}` という表記があった場合、当該の部分を自分の環境に応じて書き換えて実行してください。

また、`$` から始まるコードブロックでは、`$` に続くコマンドを一般ユーザで実行することを示しています。
`(Mac) $ ...` のブロックは、`$` に続くコマンドを手元の Mac で実行することを示し、
`ubuntu@ip-10-x-x-x:~$ ...` や `(EC2) $ ...` のようなブロックでは、`$` に続くコマンドを起動したインスタンス上で実行すべきコマンドであることを示しています。

# セットアップ

今回のインターンシップでは、[AWS (Amazon Web Service)](https://aws.amazon.com/) を利用して講義を進めていきます。

AWS とは、Amazon が提供するクラウドサービスの総称、およびその企業名です。
詳細は後の講義にて説明しますが、クックパッドは全てのサービスを AWS の上で展開しています。
全てのサービスを API で操作できるようになっていることが一つ大きな特徴です。

[Amazon EC2](https://aws.amazon.com/ec2/) は AWS が提供するサービスの一つで、
簡単に説明すると "仮想マシン (VM) を自由に貸してくれるサービス" です。
個々の仮想マシンは "インスタンス" と呼ばれます。
インスタンスの起動時間に対して課金されるため、"使いたい時に起動し、使わない時は止める" ことで
コストを最適化することが可能です。

いくつか、最低限知っておきたい (この講義で利用する) 用語を説明します。

- インスタンスタイプ
   - インスタンススペックの呼称。一意の名称に対してスペックが決まっている
   - 詳細は [ここ](https://aws.amazon.com/ec2/instance-types/) を参照
- VPC
   - AWS 上に作成できる仮想ネットワーク。全てのインスタンスが同じネットワークに接続されていると、例えば他利用者のインスタンスから自分のインスタンスにアクセスできるといった不都合も生じるが、自分用のプライベートネットワークを作成できるようになっている。その単位。
- サブネット
   - VPC をさらに細かく区切る単位。インスタンス起動時にはそのインスタンスが所属する VPC とサブネットを選択する。
- タグ
   - AWS におけるリソース (インスタンス, VPC, サブネットなど) に自由に付加できるメタデータ。例えば id ではない名前や、利用者の情報などを付加することができる。
- セキュリティグループ
   - 要はファイアウォール。インスタンス上ではなく EC2 のコンソールで制御できるため管理がしやすい。複数のインスタンスを同じセキュリティグループに所属させることも可能 (DB は同じセキュリティグループに、など)
- AMI
   - Amazon Machine Image の略称。EC2 における仮想イメージであり、多くの AMI が公開されている。自分の AMI を作成することもできる。

より詳しく知りたい人は AWS のドキュメントを見てみましょう。
- [EC2 のドキュメント](https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/concepts.html)
- [VPC のドキュメント](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html)

### VPC とサブネットの関係

![](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/images/vpc-diagram.png)

![](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/images/subnets-diagram.png)

## マネジメントコンソールにログインする

AWSを操作するには主に2つの方法があります。

- マネジメントコンソールと呼ばれるWeb UIを使う
- コマンドラインツール（awscli）や各言語用のSDKを利用する

今回はマネジメントコンソールを使って進めていきます。

1. https://xxxxxxxxxxxx.signin.aws.amazon.com/console
2. 指示された ID でログイン。パスワードは共有されたものを利用してください
3. パスワードを変更
4. 右上のリージョンが Tokyo になっていなかったら切り替え

これ以降の操作は右上のリージョン表示を確認して進めてください。講義が進められなくなるおそれがあります。

## 言語設定

マネジメントコンソールは英語、日本語をはじめとするいくつかの言語を選択できます。どの言語で使ってもいいですが、研修資料では英語版にそって記載していきます。
英語に変更する場合、左下の「日本語」を選択した上で"English"を選択します。

## CodeCommit 用 SSH 鍵の登録

今回の講義では GitHub のかわりに [AWS CodeCommit](https://aws.amazon.com/jp/codecommit/) という git レポジトリサービスを利用します。
https://console.aws.amazon.com/iam/home?region=ap-northeast-1#/users にアクセスし、
自分のユーザを選択します。
"Security credentials" から "Upload SSH public key" を選択し、自分の SSH 公開鍵をアップロードしてください (AWS の制約で RSA の鍵を利用する必要があります)。

SSH 公開鍵がない人は、次のコマンドで作成してください。鍵を作る時にパスフレーズを聞かれますが、適当に設定してください（空でも作成できます）。

```
$ ssh-keygen -t rsa
```

アップロードしたら、自分の ~/.ssh/config に以下のように設定を記載してください。

```
Host git-codecommit.ap-northeast-1.amazonaws.com
  User #{公開鍵アップロード後に表示された SSH key ID}
  IdentityFile ~/.ssh/id_rsa # (アップロードした公開鍵と対応する秘密鍵のパスに置き換える)
```

## キーペアの作成

EC2 インスタンスを起動する際、AMI から起動することになりますが、SSH 鍵を AMI に埋め込んでしまうと同じ認証情報を共有することになりとても危険です。
そのため、EC2 ではキーペアと呼ばれる SSH 鍵ペアをあらかじめ作成しておき、AMI 起動時にそれを埋め込むようにしています。

ここでは先程作成した鍵を登録します。https://ap-northeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-northeast-1#KeyPairs:sort=keyName にアクセスし、
"Import Key Pair" を選択し、"Load public key from file" から先程作成した鍵 (#{key\_name}.pub) を選択し、"Key pair name" には自分だと識別できる名前を入力してください。

## EC2インスタンスの起動

https://console.aws.amazon.com/ec2/home?region=ap-northeast-1#launchAmi=ami-940cdceb にアクセス

下記の設定で起動します。

- Instance Type: `c5.large`
- Network: vpc-4f77f328 (default)
- Subnet: subnet-f9f67ea2 (Default in ap-northeast-1c)
- Auto-assign Public IP: Enable
- IAM Role: InternEC2Role
- Volume Size(GiB) 20
- Tags
  - Key: `Name`, Value: `app-#{yourname}-001`
  - Key: `ResourceType`, Value: `Internship`
- Security Group: sg-9cb895e5 (default)
- Key Pair: 先程作成したキーペア

## SSH ログイン

では、先程起動したインスタンスに SSH ログインをして接続できるか確認してみます。

Instances にある起動したインスタンスを選択すると、Public DNS (IPv4) という箇所に、インスタンスに紐づく DNS 名が書いてあります。

```
(Mac) $ ssh -i ~/.ssh/#{key_name} ubuntu@#{インスタンスのPublicIPアドレス}
Welcome to Ubuntu 16.04.2 LTS (GNU/Linux 4.4.0-1022-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@ip-10-x-x-x:~$ exit
```

接続が確認できたら、exit で ssh を終了します。

## コードの clone

今回使う Rails アプリケーションなどのコード一式をセットアップします。
この作業はみなさんが使っている PC の上で行ってください。

まず[サンプルコードレポジトリ](https://ap-northeast-1.console.aws.amazon.com/codecommit/home?region=ap-northeast-1#/repository/summer-intern-slackpad-server/browse/master/--/)を clone しましょう。

```
(Mac) $ git clone ssh://git-codecommit.ap-northeast-1.amazonaws.com/v1/repos/summer-intern-slackpad-server
```

次に、作業のため自分のレポジトリを作成します。
https://ap-northeast-1.console.aws.amazon.com/codecommit/home?region=ap-northeast-1#/repository/list にアクセスし、
"Create repository" をクリックします。

- Repository name: 自分の名前を含むわかりやすいレポジトリ名
- Description: 自由

作成後、イベント通知の設定を行うか聞かれますが、使用しないため Skip します。
次に、作成したレポジトリをアプリケーションのコードが入っているディレクトリに追加します。

```
(Mac) $ cd summer-intern-slackpad-server
(Mac) $ git remote add myrepo ssh://git-codecommit.ap-northeast-1.amazonaws.com/v1/repos/#{作成したレポジトリ名}
(Mac) $ git push -u myrepo master # master ブランチのデフォルトリモートを myrepo に変更して push
```

## インスタンスの初期セットアップ

インスタンスに Ruby などの必要なソフトウェアをインストールします。
といっても今回は ssh 経由でコマンドを実行するのではなく、クックパッドで利用している [Itamae](http://itamae.kitchen/) という構成管理ツールを利用してセットアップを行います。

```
(Mac) $ bundle install -j4 --without test production
(Mac) $ cd itamae
```

以下の `--dry-run` をつけたコマンドで、構成管理ツールがどのような変更をするのか確認することができます。

```
(Mac) $ bundle exec itamae ssh --dry-run --key ~/.ssh/#{key_name} --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb initial.rb roles/app/default.rb
```

dry-run してみて問題なさそうであれば、dry-run オプションを外すことで実際に適用することができます。

```
(Mac) $ bundle exec itamae ssh --key ~/.ssh/#{key_name} --user ubuntu --host #{インスタンスのPublicIPアドレス} functions.rb initial.rb roles/app/default.rb
```

これは、対象のインスタンスに対して、`functions.rb`, `initial.rb`, `roles/app/default.rb` の 3 つのレシピを適用するコマンドです。
それぞれの中身に関しては今回は説明しませんが、Itamae に興味がある方は中身を眺めてみるのも良いでしょう。

これでインスタンスの初期セットアップは終了です。

## Rails アプリケーションのセットアップ

これで Rails アプリケーションを動かす下地をつくることができました。
次に、今回のために用意した Rails アプリケーションをデプロイし動かしてみましょう。

まず、Capistrano の設定ファイルを自分のインスタンスにデプロイ出来るように編集します。

```
${EDITOR} config/deploy/production.rb
```

6 行目の、`server` メソッドの第 1 引数を自分のインスタンスの FQDN に変更します。

```
server 'ec2-xxx-xxx-xxx-xxx.ap-northeast-1.compute.amazonaws.com', user: 'ubuntu', roles: %w{app db web}
```

45 行目の `keys` の値を自分の秘密鍵のパスに変更します。

```
  keys: %w(~/.ssh/key_name),
```

次に、別の設定ファイルを変更します。

```
${EDITOR} config/deploy.rb
```

5 行目の `repo_url` を先ほど作成した自分のレポジトリに設定します。
`https://` から始まる URL であることに気をつけてください。

```
set :repo_url, 'https://git-codecommit.ap-northeast-1.amazonaws.com/v1/repos/#{自分のレポジトリ名}'
```

変更が終わったら、手元の Mac で次のコマンドを実行しデプロイします。

```
(Mac)$ bundle exec cap production deploy
```

入力したら、ブラウザからインスタンスに HTTP 接続してみましょう。

# 手動で行わない理由

なぜコマンドを使わないのでしょう？不思議に思った方もいるかと思います。
クックパッドもその一つですが、インフラ環境がある程度成長してくると手動操作が思わぬミスや障害を招くことがあります。
また、大量のサーバを手動で操作しなければならないとなると相当効率が悪いことは想像に難くないでしょう。
そのため、多くの Web サービスではサーバのプロビジョニングツールやデプロイツールを利用し、手動操作を極力なくそうとしているのです。
以下に説明します。

# Infrastructure as Code

Infrastructure as Codeとはその名の通り、インフラをコードで記述することで管理をしやすくする手法です。
コードで記述することで

- バージョン管理ができる
  - gitなどを使うことで過去のインフラの状態も含めて把握できる
- 変更をレビューできる
  - たとえばGitHubのPull Requestsを使うことで、インフラに対する変更内容をレビューすることができる
- 繰り返し同じ作業ができ、インフラに再現性がある
  - 同じ環境を作るのも簡単
- テストがしやすい
  - ソフトウェアと同じようにインフラもテストを書くことができる

といったメリットがあります。

## Infrastructure as Codeのためのツール

- Dynamic Infrastructure Platforms
  - EC2 のような IaaS や OpenStack のような IaaS を構成するためのツール
- Infrastructure Orchestration Tools
  - Terraform や CloudFormation のような、IaaS 上でサーバ/ネットワーク/ストレージといったリソースを制御するためのツールやサービス
  - Consul, etcd, ZooKeeper のような Configuration Registry
- Server Configuration Tools
  - Puppet, Chef, Ansible, Itamae といったリソースの設定を行うためのツール
- Infrastructure Services
  - プロビジョニングしたインフラを管理するためのツール
  - モニタリング、サービスディスカバリ、プロセス・ジョブ管理、ソフトウェアデプロイメントなど

(http://mizzy.org/blog/2016/04/22/1/ より引用)

## Itamae

Itamaeはサーバプロビジョニングツールの一つで、設定ファイルの配置やパッケージのインストールなどのサーバ構築作業を自動化できます。
クックパッドでもItamaeを利用しています。

https://github.com/itamae-kitchen/itamae/wiki

今後本資料では基本的にコマンドラインを使った操作を説明しますが、配布している itamae レシピを拡張して利用していただいても構いません。
(ハマってついていけなくならない程度にしてください)

# デプロイメント

デプロイメント
Webアプリケーションにおけるデプロイとは、主に開発したアプリケーションコードを本番環境に移し、そのコードを用いてアプリを起動することを指します。
では、自分の開発したコードをどのように本番環境に移すのでしょう？
差分をいちいち覚えておいて手動で書き換えたのではあまりに危険です。おまけにサーバ数が増えたら地獄を見ます。
そのためにデプロイツールを利用します。デプロイをツール化、自動化することで
- 素早くサービスをデプロイでき、またそれを繰り返せる
- オペレーションミスが抑止される
- 違う人でも全く同じオペレーションが期待できる
- デプロイやロールバック (問題があった際ソフトウェアのバージョンを切り戻すこと) ができる

などのメリットがあります。
クックパッドは60~160台ほどの EC2 インスタンスで動いていますが、1日に10回前後のデプロイがあります。

## capistrano

[capistrano](https://github.com/capistrano/capistrano)は Ruby 製のデプロイツールです。
特に Rails に関係するデプロイツールとしては最も使われているツールでしょう。
簡単な設定を書くだけで、アプリケーションのデプロイやその後の再起動、ロールバックを複数台のサーバにわたって行うことができます。

今回は既に capistrano によってデプロイ環境ができていますので、今後アプリケーションコードに変更を加える際は git レポジトリで変更管理をし、
capistrano を利用してデプロイを行いましょう。

## mamiya

capistrano によって大抵の環境では問題なくデプロイを行うことができるのですが、
クックパッドの環境では使われているサーバの数や capistrano の構造上、デプロイに時間がかかるようになっていました。
そのため、[sorah/mamiya](https://github.com/sorah/mamiya)というツールが開発され、これを使ってデプロイをしています。

これにより、150台以上の EC2 インスタンスへ1分以内でデプロイできるようになっています。

## ログ

アプリケーション、サーバの状態を知りたいときはログを閲覧します。ログファイルの場所はソフトウェアによって異なりますが、主に

- `/var/log`以下
- アプリケーションディレクトリ以下の`log`ディレクトリ

にあることが多いです。たとえば、Railsアプリケーションのログは

```
(EC2)$ tail ~/slackpad-server/shared/log/production.log
```

で閲覧できます（`tail`はファイルの末尾を出力するコマンド）。
