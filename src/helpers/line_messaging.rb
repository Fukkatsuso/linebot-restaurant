require "sinatra/base"

module Sinatra
  module LINEMessagingHelper
    # 「キーワード検索」への返答
    def keyword_search_info
      {
        type: 'text',
        text: "キーワードを入力してネ"
      }
    end

    # 「位置情報検索」への返答
    def location_search_info
      {
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

    # 位置情報への返答
    def location_search_confirm(lat, lng, range = 3)
      {
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
              data: "action=genre_search_info&lat=#{lat}&lng=#{lng}&range=#{range}"
            },
            {
              type: 'postback',
              label: "いいえ",
              displayText: "いいえ",
              data: "action=search_restaurants&lat=#{lat}&lng=#{lng}&range=#{range}"
            }
          ]
        }
      }
    end

    # ジャンル検索用のクイックリプライ
    def genre_search_quickreply(items)
      {
        type: 'text',
        text: "ジャンルを選んでネ",
        quickReply: {
          items: items
        }
      }
    end

    # 位置情報+ジャンルで検索するポストバックアクション
    def genre_postback(genre, lat, lng, range = 3)
      {
        type: 'action',
        action: {
          type: 'postback',
          label: genre['name'],
          displayText: genre['name'],
          data: "action=search_restaurants&lat=#{lat}&lng=#{lng}&range=#{range}&genre=#{genre['code']}"
        }
      }
    end

    def search_results(r)
      results = []
      if r['results']['results_returned'].to_i == 0
        results << {
          type: 'text',
          text: "ごめんなさい。見つかりませんでした(._.)"
        }
        return results
      end
      results << {
        type: 'text',
        text: "#{r['results']['shop'].length}件見つかりました"
      }
      bubbles = []
      r['results']['shop'].each do |s|
        bubbles << restaurant_bubble(s)
      end
      results << carousel("検索結果", bubbles)
      return results
    end

    def carousel(alt_text, bubbles)
      {
        type: 'flex',
        altText: alt_text,
        contents: {
          type: 'carousel',
          contents: bubbles
        }
      }
    end

    def restaurant_bubble(r)
      {
        type: "bubble",
        size: "mega",
        hero: restaurant_bubble_hero(r['photo']['pc']['l']),
        body: restaurant_bubble_body(r),
        footer: restaurant_bubble_footer(r['urls']['pc'], r['name'])
      }
    end

    private 
    
    def restaurant_bubble_hero(photo_url)
      {
        type: "image",
        url: photo_url,
        size: "full",
        aspectMode: "cover",
        aspectRatio: "320:213"
      }
    end

    def restaurant_bubble_body(r)
      {
        type: 'box',
        layout: 'vertical',
        contents: [
          restaurant_bubble_body_titlebox(r['name'], r['genre']['catch']),
          {
            type: 'box',
            layout: 'vertical',
            contents: [
              restaurant_bubble_body_detailbox("Genre", r['genre']['name']),
              restaurant_bubble_body_detailbox("Open", r['open']),
              restaurant_bubble_body_detailbox("Place", r['address'])
            ],
            paddingTop: "16px",
            spacing: 'sm'
          }
        ]
      }
    end

    def restaurant_bubble_body_titlebox(restaurant_name, catch_text)
      {
        type: 'box',
        layout: 'vertical',
        contents: [
          {
            type: 'text',
            text: restaurant_name,
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
                text: catch_text,
                color: '#666666',
                size: 'sm',
                wrap: true,
                flex: 5
              }
            ]
          }
        ]
      }
    end

    def restaurant_bubble_body_detailbox(title, detail)
      {
        type: 'box',
        layout: 'baseline',
        spacing: 'sm',
        contents: [
          {
            type: 'text',
            text: title,
            color: "#999999",
            size: 'sm',
            flex: 1
          },
          {
            type: 'text',
            text: detail,
            color: '#666666',
            size: 'sm',
            wrap: true,
            flex: 5
          }
        ]
      }
    end

    def restaurant_bubble_footer(site_url, gmap_query)
      {
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
              uri: site_url
            }
          },
          {
            type: 'button',
            style: 'link',
            height: 'xs',
            action: {
              type: 'uri',
              label: 'マップで見る',
              uri: googlemapurl(gmap_query)
            }
          }
        ],
        paddingAll: 'none'
      }
    end

    def googlemapurl(query)
      url = "https://www.google.com/maps/search/?api=1&query=#{query}"
      URI.encode(url.force_encoding("UTF-8"))
    end
  end

  helpers LINEMessagingHelper
end