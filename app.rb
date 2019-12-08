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
      config.channel_id = ENV["LINE_CHANNEL_ID"]
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
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
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          messages = nil
          if event.message['text'] == "いち"
            messages = {
              type: 'text',
              text: "こちらから位置情報を送信してください\nline://nv/location"
            }
          else
            params = {
              keyword: event.message['text']
            }
            r = restaurants(params, 3)
            messages = text_replies(r)
          end
          puts "[response] #{messages}"
          client.reply_message(event['replyToken'], messages)
        when Line::Bot::Event::MessageType::Location
          params = {
            lat: event.message['latitude'],
            lng: event.message['longitude']
          }
          r = restaurants(params, 3)
          messages = text_replies(r)
          puts "[response] #{messages}"
          client.reply_message(event['replyToken'], messages)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
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

    def text_replies(r)
      replies = []
      r["results"]["shop"].each do |s|
        text = ""
        text += "[#{s["name"]}]\n"
        text += "-address: #{s["address"]}\n"
        text += "-genre: #{s["genre"] ? s["genre"]["name"] : ""}, #{s["sub_genre"] ? s["sub_genre"]["name"] : ""}\n"
        text += "-open: #{s["open"]}\n"
        text += "-url: #{s["urls"] ? s["urls"]["pc"] : ""}\n"
        reply = {
          type: 'text',
          text: text
        }
        replies << reply
      end
      return replies
    end
  end
end