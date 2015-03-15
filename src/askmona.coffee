{Adapter, TextMessage} = require 'hubot'
{EventEmitter} = require 'events'
request = require 'request'
crypto = require 'crypto'
colors = require 'colors'

class AskMona extends Adapter
  send: (envelope, strings...) ->
    @bot.send string for string in strings
  
  reply: (envelope, strings...) ->
    @bot.send ">>#{envelope.message.id} #{string}" for string in strings
  
  tip: (resp_id, amount, anonymous = 1) ->
    @bot.tip resp_id, amount, anonymous
  
  run: ->
    self = @ # 別スコープ(functionのなか)からでもrun直下のスコープの変数を呼ぶため
    @listening = false
    
    console.log "AskMona Adapter Launched".yellow
    options =
      dev_secret: process.env.HUBOT_ASKMONA_DEV_SECRETKEY
      app_id: parseInt process.env.HUBOT_ASKMONA_APP_ID, 10
      user: parseInt process.env.HUBOT_ASKMONA_USER_ID, 10
      secret: process.env.HUBOT_ASKMONA_SECRETKEY
      topic: parseInt process.env.HUBOT_ASKMONA_TOPIC_ID, 10
    
    console.log "#{k} is #{v}".blue for k,v of options
    
    bot = new AskMonaStreaming options, self.robot
    
    bot.on "response", (responses) ->
      for res in responses
        user = self.robot.brain.userForId res.u_id, { name: res.u_name }# よくわからん
        self.receive new TextMessage user, res.response, res.r_id
    
    @bot = bot
    
    bot.on "started", ->
      if !self.listening # 一回だけ
        self.bot.listen()
        self.listening = true
      
    self.emit "connected"
    
exports.use = (robot) ->
  new AskMona robot
    
class AskMonaStreaming extends EventEmitter
  self = "" # 別スコープ(functionの中など)からでもインスタンスメソッドを呼ぶため
  constructor: (options, robot) ->
    @dev_secret = options.dev_secret
    @app_id = options.app_id
    @secret = options.secret
    @topic = options.topic
    @topic_last_request = 0
    @user = options.user
    @robot = robot
    self = @ # インスタンス自身を代入
    
    # 前回起動時にlisten:で保存しておいたものを取り出す
    @topic_last_resp_id = 0
    robot.brain.on "loaded",  -> # redisから読み込んだら
      self.topic_last_resp_id = robot.brain.get "topic_last_resp_id" or 0
      self.emit "started" # Adapterに伝える

  send: (text) -> # レス投稿
    params =
      app_id: self.app_id
      u_id: self.user
      nonce: self.generateNonce 10
      time: self.nowEpochSecond() + 200
      auth_key: ""
      t_id: self.topic
      text: text
    
    params.auth_key = self.generateAuthKey self.dev_secret, self.secret, params.nonce, params.time
    
    # そのまま?key=value&key ..ってやってもダメだったのでformデータとしてつける
    console.log params
    request.post "http://askmona.org/v1/responses/post", {form: params}, (err, res, body) ->
      data = JSON.parse(body)
      
      if data.status == 0
        console.log "AskMonaStreaming: send Error".red
        console.log data.error.red
      else
        console.log "AskMonaStreaming: send Success".green
    
  tip: (resp_id, amount, anonymous = 1) ->
    params =
      app_id: self.app_id
      u_id: self.user
      nonce: self.generateNonce 10
      time: self.nowEpochSecond()
      auth_key: ""
      t_id: self.topic
      r_id: resp_id
      amount: amount
      anonymous: anonymous
      
    params.auth_key = self.generateAuthKey self.dev_secret, self.secret, params.nonce, params.time
    
    request.post "http://askmona.org/v1/account/send", {form: params}, (err, res, body) ->
      data = JSON.parse(body)
      if data.status == 0
        console.log "AskMonaStreaming: tip Error".red
        console.log data.error.red
  
  listen: -> # トピックからレスを取得(継続的に)
    timer = setInterval ->
      console.log "Start Request (from: #{self.topic_last_resp_id + 1})".green
      
      params =
        t_id: self.topic
        from: self.topic_last_resp_id + 1 # +1しているのは、最後に取得したレスの"次"から取得するため
        to: 1000 # from以降のレスポンス全て
        if_modified_since: self.topic_last_request
      
      request.get "http://askmona.org/v1/responses/list#{self.generateReqString params}", (err, res, body) ->
        data = JSON.parse(body)
        console.log "listen: response: #{data.status}".yellow
        
        if data.status == 1 && data.responses.length > 0
          last = data.responses[data.responses.length - 1] # 最後のレスを取得
          self.topic_last_resp_id = last.r_id # 最後のレス番号を更新
          self.topic_last_request = self.nowEpochSecond()
          
          # 最後まできたらtimerを止める
          if self.topic_last_resp_id == 1000
            clearInterval timer
            
          # 次回の起動に備えてtopic_last_resp_idを保存しておく
          # 次回からは保存したところからレスを取得する
          self.robot.brain.set "topic_last_resp_id", self.topic_last_resp_id
          
          self.emit "response", data.responses
    , 1000
    
  generateNonce: (length) ->
    return "" if length <= 0
    str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    return (str[Math.floor(Math.random() * str.length)] for index in [1..length]).join ""
    
  generateAuthKey: (dev_secret, secret, nonce, time) ->
    # see: https://gist.github.com/JasonGiedymin/2410489
    str = dev_secret + nonce + time + secret
    return crypto.createHash("sha256").update(str).digest("base64")
    
  generateReqString: (obj) ->
    str = "?"
    for key, value of obj
      str += "#{key}=#{value}&"
    return str
  
  nowEpochSecond: ->
    Math.floor( (new Date).getTime() / 1000.0 )