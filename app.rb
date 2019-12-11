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
            r = restaurants(params, 3)
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
          r = restaurants(params, 3)
          messages = restaurants_reply(r)
        when "keyword_search"
          messages = keyword_search_info
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

    def restaurants_reply(r)
      replies = []
      r['results']['shop'].each do |s|
        text = ""
        text += "[#{s['name']}]\n"
        text += "-address: #{s['address']}\n"
        text += "-genre: #{s['genre'] ? s['genre']['name'] : ""}, #{s['sub_genre'] ? s['sub_genre']['name'] : ""}\n"
        text += "-open: #{s['open']}\n"
        text += "-url: #{s['urls'] ? s['urls']['pc'] : ""}\n"
        reply = {
          type: 'text',
          text: text
        }
        replies << reply
      end
      return replies
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

    def location_search_confirm(lat, lng, range = 3)
      confirm = {
        type: 'template',
        altText: "絞り込み検索",
        template: {
          type: 'confirm',
          text: "キーワードで絞り込みますか？",
          actions: [
            {
              type: 'postback',
              label: "はい",
              displayText: "はい",
              data: "action=keyword_search&lat=#{lat}&lng=#{lng}&range=#{range}"
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