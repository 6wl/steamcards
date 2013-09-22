#!/usr/bin/ruby
#
require "nokogiri"
require "bunny"
require "httparty"
require "json"
require "couchrest"
require "yaml"

class Scraper
  attr_reader :average_price

  def initialize()
    @db = CouchRest.database("http://localhost:5984/steam")
    @average_price = 0.00
  end

  def get_average_from_db(card_name, game_name)
    rows = @db.view('_design/prices/_view/average_per_game_card', :key => [game_name, card_name])["rows"]
    if rows.length > 0
      @average_price = rows[0]["value"]
    else
      @average_price = nil
    end
  end

  def scrape()
    url = "http://steamcommunity.com/market"
    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    items = doc.css('.market_listing_row')

    items_newly = items[10...20]

    items_newly.each do |item|
      item_name = item.css('.market_listing_item_name').text
      item_name = item_name.gsub(/ \(Trading Card\)/, '')
      
      game_name = item.css('.market_listing_game_name').text
      game_name = game_name.gsub(/ Trading Card/, '')

      price = item.css('.market_listing_price.market_listing_price_with_fee').text
      price = price.match(/(\d*(\.|,)\d*)/)[0]
      price = price.gsub(/,/, '.')
      price = price.to_f

      price_average = self.get_average_from_db(item_name, game_name)
      puts "Found... #{item_name}, #{game_name} for #{price}, with average #{price_average}"

      if (price_average.to_f * 0.7) > price
        buy_it = true
      end

      if @average_price
        puts "Item name: #{item_name}"
        puts "Game name: #{game_name}"
        puts "Item price: #{price}"
        puts "Item average price: #{@average_price}"
        puts "PRICE IS 70% OF AVERAGE" if buy_it
        puts "\n"
      end
    end
  end
  
  def should_buy?(item_name, game_name, listed_price)
    price_average = self.get_average_from_db(item_name, game_name)
    if (price_average.to_f * 0.7) > listed_price
      return true
    else
      return false
    end
  end

  def check_list()
    self.scrape

  end

end

s = Scraper.new()
#s.get_average_from_db("Charger", "Left 4 Dead 2")
s.scrape
