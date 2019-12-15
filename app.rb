require "sinatra/base"
require "sinatra/reloader"
require "line/bot"
require "json"
require "net/http"
require "uri"
require "./src/helpers/restaurant.rb"
require "./src/helpers/line_messaging.rb"

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    also_reload "./src/helpers/restaurant.rb"
    also_reload "./src/helpers/line_messaging.rb"
  end

  helpers Sinatra::RestaurantHelper
  helpers Sinatra::LINEMessagingHelper

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
            params = { keyword: event.message['text'] }
            r = get_restaurants(params, MAX_RESULT)
            messages = search_results(r)
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
        when "search_restaurants"
          params = data.select{|k, v| k != 'action'}
          r = get_restaurants(params, MAX_RESULT)
          messages = search_results(r)
        when "genre_search_info"
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
    # ジャンル検索は位置情報の絞り込みに使用
    def genre_search_info(lat, lng, range = 3)
      items = []
      genres = get_genres(true, 13) # ランダム, ボタンは13個まで
      genres['results']['genre'].each do |genre|
        items << genre_postback(genre, lat, lng, range)
      end
      genre_search_quickreply(items)
    end
  end
end