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
          r = JSON.parse(restaurants({keyword: event.message['text']}).body)
          message = {
            type: 'text',
            text: (r["results"]["shop"][0]["name"]).to_s
          }
          puts message
          client.reply_message(event['replyToken'], message)
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
    def restaurants(params)
      uri = "http://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
      uri += "?key=#{ENV['HOTPEPPER_API_KEY']}"
      uri += "&format=json"
      uri += "&count=1"
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
    end
  end
end