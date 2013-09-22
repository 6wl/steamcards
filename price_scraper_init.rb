#!/usr/bin/ruby
#
require "nokogiri"
require "bunny"
require "httparty"
require "json"
require "couchrest"
require "yaml"

class Scraper
  attr_reader :game_card

  def initialize(config, game_card)
    connection = "http://#{config["server"]}:#{config["port"]}/#{config["database"]}"
    @game_card = game_card
    @db = CouchRest.database!(connection)
  end

  def scrape()
    url = "http://steamcommunity.com/market/search"
    query = {"q" => @game_card}

    html = HTTParty.get(url, :query => {"q" => "#{@game_card["card_name"]} + #{@game_card["game_name"]} + Trading Card" }).body
    doc = Nokogiri::HTML(html)

    results = doc.css('.market_listing_row')
    
    begin
      card_name = results[0].css('.market_listing_item_name').text
      details = results[0].css('.market_listing_right_cell').text.strip
      @price = details[/\d+\.\d+/]
    rescue
      @price = 0.00
    end

  end
  
  def merge_in_new(doc)
    price_hash = {"time" => Time.new().to_i, "price" => @price.to_f}
    cards = doc["cards"]
    card_index = 0
    cards.each do |card|
      if card["card_name"] == @game_card["card_name"]
        if doc["cards"][card_index].has_key?("price_history")
          doc["cards"][card_index]["price_history"] << price_hash
        else
          doc["cards"][card_index]["price_history"] = [price_hash]
        end
        break
      end
      card_index += 1
    end
    return doc
  end

  def write()
    doc = @db.view("games/game_by_name", {"key" => @game_card["game_name"]})["rows"][0]["value"]
    merged_doc = self.merge_in_new(doc)
    @db.save_doc(merged_doc)
  end

end
 
config = YAML.load_file("config.yaml")

conn = Bunny.new()
conn.start()

channel = conn.create_channel()
channel.prefetch(1)

queue = channel.queue("price_scraper_init")

queue.subscribe(:ack => true, :block => true) do |delivery_info, properties, payload|
  payload = JSON.parse(payload)
  puts "[+] Message to price scrape for game_name #{payload["game_name"]}, card_name #{payload["card_name"]}"
  s = Scraper.new(config, payload)
  s.scrape
  s.write
  puts "[+] Finished scraping and write"
  channel.ack(delivery_info.delivery_tag)
end
