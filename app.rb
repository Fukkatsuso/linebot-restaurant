require "sinatra/base"
require "sinatra/reloader"
require "line/bot"
require "json"
require "net/http"
require "uri"

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  MAX_RESULT = 10

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_id = ENV['LINE_CHANNEL_ID']
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    }
  end
  
  post '/callback' do
    body = request.body.read
  
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
  
    events = client.parse_events_from(body)
    events.each do |event|
      messages = nil
      
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          puts "[request] #{event.message['text']}"
          if event.message['text'] == "キーワード検索"
            messages = keyword_search_info
          elsif event.message['text'] == "位置情報検索"
            messages = location_search_info
          else
            params = {
              keyword: event.message['text']
            }
            r = restaurants(params, MAX_RESULT)
            messages = restaurants_reply(r)
          end
        when Line::Bot::Event::MessageType::Location
          lat = event.message['latitude']
          lng = event.message['longitude']
          range = 3
          messages = location_search_confirm(lat, lng, range)
        end

      when Line::Bot::Event::Postback
        data = Rack::Utils.parse_nested_query(event['postback']['data'])
        puts "[postback] #{data}"
        case data['action']
        when "restaurants"
          params = data.select{|k, v| k != 'action'}
          r = restaurants(params, MAX_RESULT)
          messages = restaurants_reply(r)
        when "genre_search"
          params = data.select{|k, v| k != 'action'}
          messages = genre_search_info(params['lat'], params['lng'], params['range'])
        end
      end

      puts "[response] #{messages}"
      client.reply_message(event['replyToken'], messages)
    end
  
    "OK"
  end

  get '/' do
    "hello world"
  end

  helpers do
    def restaurants(params, count)
      uri = "http://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
      uri += "?key=#{ENV['HOTPEPPER_API_KEY']}"
      uri += "&format=json"
      uri += "&count=#{count}"
      params.each do |k, v|
        puts "[#{k}] #{v}"
        uri += "&#{k}=#{v}"
      end
      uri = URI.parse(URI.encode(uri.force_encoding("UTF-8")))
      puts "[uri] #{uri}"
      req = Net::HTTP::Get.new(uri)
      res = Net::HTTP.start(uri.host, uri.port) { |http|
        http.request(req)
      }
      JSON.parse(res.body)
    end

    def genres
      uri = "http://webservice.recruit.co.jp/hotpepper/genre/v1/"
      uri += "?key=#{ENV['HOTPEPPER_API_KEY']}"
      uri += "&format=json"
      uri = URI.parse(URI.encode(uri.force_encoding("UTF-8")))
      puts "[uri] #{uri}"
      req = Net::HTTP::Get.new(uri)
      res = Net::HTTP.start(uri.host, uri.port) { |http|
        http.request(req)
      }
      JSON.parse(res.body)
    end

    def restaurants_reply(r)
      replies = []
      if r['results']['shop'].length == 0
        reply = {
          type: 'text',
          text: "ごめんなさい。見つかりませんでした(._.)"
        }
        replies << reply
      else
        replies = []
        replies << {
          type: 'text',
          text: "#{r['results']['shop'].length}件見つかりました"
        }
        bubbles = []
        r['results']['shop'].each do |s|
          bubbles << restaurant_bubble(s)
        end
        replies << carousel(bubbles)
      end
      return replies
    end

    def restaurant_text(r)
      text = ""
      text += "[#{s['name']}]\n"
      text += "-address: #{s['address']}\n"
      text += "-genre: #{s['genre'] ? s['genre']['name'] : ""}, #{s['sub_genre'] ? s['sub_genre']['name'] : ""}\n"
      text += "-open: #{s['open']}\n"
      text += "-url: #{s['urls'] ? s['urls']['pc'] : ""}\n"
      return {
        type: 'text',
        text: text
      }
    end

    def restaurant_bubble(r)
      {
        type: "bubble",
        size: "mega",
        hero: {
          type: "image",
          url: r['photo']['mobile']['s'],
          size: "full",
          aspectMode: "cover",
          aspectRatio: "320:213"
        },
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'box',
              layout: 'vertical',
              contents: [
                {
                  type: 'text',
                  text: r['name'],
                  weight: 'bold',
                  size: 'lg',
                  wrap: true
                },
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: r['genre']['catch'],
                      color: '#666666',
                      size: 'sm',
                      wrap: true,
                      flex: 5
                    }
                  ]
                }
              ]
            },
            {
              type: 'box',
              layout: 'vertical',
              contents: [
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: "Genre",
                      color: "#999999",
                      size: 'sm',
                      flex: 1
                    },
                    {
                      type: 'text',
                      text: r['genre']['name'],
                      color: '#666666',
                      size: 'sm',
                      wrap: true,
                      flex: 5
                    }
                  ]
                },
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: "Open",
                      color: "#999999",
                      size: 'sm',
                      flex: 1
                    },
                    {
                      type: 'text',
                      text: r['open'],
                      color: '#666666',
                      size: 'sm',
                      wrap: true,
                      flex: 5
                    }
                  ]
                },
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: "Place",
                      color: "#999999",
                      size: 'sm',
                      flex: 1
                    },
                    {
                      type: 'text',
                      text: r['address'],
                      color: '#666666',
                      size: 'sm',
                      wrap: true,
                      flex: 5
                    }
                  ]
                }
              ],
              paddingTop: "16px",
              spacing: 'sm'
            }
          ]
        },
        footer: {
          type: 'box',
          layout: 'horizontal',
          contents: [
            {
              type: 'button',
              style: 'link',
              height: 'xs',
              action: {
                type: 'uri',
                label: 'URL',
                uri: r['urls']['pc']
              }
            },
            {
              type: 'button',
              style: 'link',
              height: 'xs',
              action: {
                type: 'uri',
                label: 'マップで見る',
                uri: restaurant_googlemapurl(r)
              }
            }
          ],
          paddingAll: 'none'
        }
      }
    end

    def restaurant_googlemapurl(r)
      url = "https://www.google.com/maps/search/?api=1&query=#{r['name']}"
      URI.encode(url.force_encoding("UTF-8"))
    end

    def carousel(bubbles)
      {
        type: 'flex',
        altText: '検索結果',
        contents: {
          type: 'carousel',
          contents: bubbles
        }
      }
    end

    def keyword_search_info
      info = {
        type: 'text',
        text: "キーワードを入力してネ"
      }
    end

    def location_search_info
      info = {
        type: 'template',
        altText: "位置情報送信ボタン",
        template: {
          type: 'buttons',
          text: "位置情報を送信してネ",
          actions: [
            {
              type: 'uri',
              label: "送信する",
              uri: "line://nv/location"
            }
          ]
        }
      }
    end

    def genre_search_info(lat, lng, range = 3)
      items = []
      i = 0
      genres['results']['genre'].each do |genre|
        item = {
          type: 'action',
          action: {
            type: 'postback',
            label: genre['name'],
            displayText: genre['name'],
            data: "action=restaurants&lat=#{lat}&lng=#{lng}&range=#{range}&genre=#{genre['code']}"
          }
        }
        items << item
        i += 1
        # ボタンは13個まで
        if i >= 13
          break
        end
      end
      return info = {
        type: 'text',
        text: "ジャンルを選んでネ",
        quickReply: {
          items: items
        }
      }
    end

    def location_search_confirm(lat, lng, range = 3)
      confirm = {
        type: 'template',
        altText: "絞り込み検索",
        template: {
          type: 'confirm',
          text: "ジャンルで絞り込みますか？",
          actions: [
            {
              type: 'postback',
              label: "はい",
              displayText: "はい",
              data: "action=genre_search&lat=#{lat}&lng=#{lng}&range=#{range}"
            },
            {
              type: 'postback',
              label: "いいえ",
              displayText: "いいえ",
              data: "action=restaurants&lat=#{lat}&lng=#{lng}&range=#{range}"
            }
          ]
        }
      }
    end
  end
end