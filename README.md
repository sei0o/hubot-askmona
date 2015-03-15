hubot-askmona
=======

(This README.md was written in Japanese.)

AskMona用のHubot Adapter

## 使い方

```
module.exports = (bot) ->
  bot.respond /おはよう/, (msg) ->
    msg.reply "もう夜やで" #=> >>(レス番号) もう夜やで
  bor.respond /Monaくれ/, (msg) ->
    # msg.tip (レス番号: msg.message.idで取得できる), (量: mona単位), (匿名なら 1 が入る)
    msg.tip msg.message.id, 0.001, 0
```

基本は他のadapterと変わりませんが、投げ銭機能が独自で実装されています(tip)。
本家hubotにはないメソッドのため、この機能を使いたい場合は以下のことを行ってください。

(botのディレクトリを`bot/`とします)
1. bot/node_modules/hubot/src/response.coffee を開く
2. 以下のようにtipメソッドを追加する **インデントに注意!**
```
  # Returns nothing.
  send: (strings...) ->
    @robot.adapter.send @envelope, strings...
    
  # ここ!
  tip: (resp_id, amount, anonymous = 1) ->
    @robot.adapter.tip resp_id, amount, anonymous

  # Public: Posts an emote back to the chat source ...
```
3. adapter.coffeeにも同様に追加しておくのもgood (他のAdapterに付けかえる際にerrorがでるため)

## インストール

### Ask Mona側
1. Ask Monaにログインする
2. [開発者マイページ](http://askmona.org/developers/mypage)にアクセスする
3. アプリケーションを作成する
4. アプリケーションIDと開発シークレットキー、連携ページURLをメモする
5. ログアウトして、bot用アカウントでログインする(アカウントが同一ならばそのまま)
6. 先ほどメモした連携ページURLに飛ぶ
7. JSON形式の認証コードが表示されるので、secretkeyの値、u_idの値をメモする
8. botに反応させたいトピックのIDをメモする

### ローカル側
1. hubotのpackage.jsonのdependenciesに`hubot-askmona`を追加
2. `$ npm install`
3. `~/.bash_profile`に以下を追記
```
export HUBOT_ASKMONA_DEV_SECRETKEY=(4.でメモした開発者シークレットキー)
export HUBOT_ASKMONA_APP_ID=(4.でメモしたアプリケーションID)
export HUBOT_ASKMONA_USER_ID=(7.でメモしたu_id)
export HUBOT_ASKMONA_SECRETKEY=(7.でメモしたsecretkey)
export HUBOT_ASKMONA_TOPIC_ID=(8.でメモしたトピックのID)
export REDIS_URL=redis://127.0.0.1:6379/hubot
```
4. `$ source ~/.bash_profile`
5. `$ redis-server`
6. `$ bin/hubot -a askmona -n BOT_NAME -l BOT_ALIAS


## contribution
1. Forkする ( http://github.com/sei0o/hubot-askmona/fork )
2. branchつくる(git checkout -b my-new-feature)
3. Commitする(git commit -am 'Add some feature')
4. Pushする~~~(git push origin my-new-feature)
5. Pull Request ~~~~

## LICENSE

`LICENSE`ファイルを見てください