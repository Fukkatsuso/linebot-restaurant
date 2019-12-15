require "sinatra/base"
require "json"
require "net/http"
require "uri"

module Sinatra
  module RestaurantHelper
    def get_restaurants(params, max)
      uri = "http://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
      uri += "?key=#{ENV['HOTPEPPER_API_KEY']}"
      uri += "&format=json"
      uri += "&count=#{max}"
      params.each do |k, v|
        puts "[#{k}] #{v}"
        uri += "&#{k}=#{v}"
      end
      call_api(uri)
    end

    def get_genres(random = false, max = nil)
      uri = "http://webservice.recruit.co.jp/hotpepper/genre/v1/"
      uri += "?key=#{ENV['HOTPEPPER_API_KEY']}"
      uri += "&format=json"
      ret = call_api(uri)
      genres = ret['results']['genre']
      genres.shuffle! if random
      max = genres.length if max.nil? || (max > genres.length)
      ret['results']['genre'] = genres[0..max-1]
      return ret
    end

    private
    def call_api(uri)
      uri = URI.parse(URI.encode(uri.force_encoding("UTF-8")))
      puts "[uri] #{uri}"
      req = Net::HTTP::Get.new(uri)
      res = Net::HTTP.start(uri.host, uri.port) { |http|
        http.request(req)
      }
      JSON.parse(res.body)
    end
  end

  helpers RestaurantHelper
end