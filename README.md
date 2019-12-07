# Restaurant Search App

## Setup
### Env
```
$ touch apikey.env
# ホットペッパーAPIキー
$ echo "HOTPEPPER_API_KEY=hoge" >> apikey.env
# チャネルID
$ echo "LINE_CHANNEL_ID=fuga" >> apikey.env
# チャネルシークレット
$ echo "LINE_CHANNEL_SECRET=hogehoge" >> apikey.env
# チャネルアクセストークン
$ echo "LINE_CHANNEL_TOKEN=hogefuga" >> apikey.env
```

### Sinatra
```
$ docker-compose run app bundle install --path vendor/bundle
```

### Local debug
```
$ docker-compose up
(another tab) $ ngrok http 4567
```