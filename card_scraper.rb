#!/usr/bin/ruby
#
require "nokogiri"
require "bunny"
require "httparty"
require "json"
require "couchrest"

class Scraper
  attr_reader :steam_id, :game_id

  def initialize(steam_id, game_id)
    @steam_id = steam_id
    @game_id = game_id
    @cards_hash = Hash.new()
    @db = CouchRest.database("http://127.0.0.1:5984/steam")
  end

  def scrape()
    url = "http://steamcommunity.com/id/#{@steam_id}/gamecards/#{game_id}/"

    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    current_game = doc.css('.profile_small_header_location')[1].text
    @cards_hash[current_game] = []

    badges = doc.css('.badge_card_set_card')
    badges.each do |badge|
      
      badge_text = badge.css('.badge_card_set_text')[0].text.strip
      badge_text = badge_text.delete("\t").delete("\n").delete("\r")
      badge_text.scan(/\(\d+\)/) { |number| badge_text = badge_text.delete(number) }
      
      badge_quantity = badge.css('.badge_card_set_text_qty').text
      if badge_quantity == nil
        badge_quantity = 0
      else
        badge_quantity = badge_quantity[1...-1].to_i
      end
      
      badge_index_and_series = badge.css('.badge_card_set_text')[1].text.strip
      
      badge_index, badge_series = badge_index_and_series.split(",")
      badge_current_index = badge_index.split(" of ")[0].to_i
      badge_total_index = badge_index.split(" of ")[1].to_i
      badge_current_series = badge_series.split(" ")[1].to_i

      @cards_hash[current_game][badge_current_index - 1] = {"badge name" => badge_text, "quantity" => badge_quantity}
    end

  end
  
  def write()
    key = @cards_hash.keys[0]
    @doc = @db.get("games")
    @doc[key] = @cards_hash[key]
    @db.save_doc(@doc)
  end

end
  
conn = Bunny.new()
conn.start()

channel = conn.create_channel()
channel.prefetch(1)

queue = channel.queue("card_scraper")

queue.subscribe(:ack => true, :block => true) do |delivery_info, properties, payload|
  payload = JSON.parse(payload)
  puts "[+] Message to scrap cards for game_id #{payload["game_id"]} for steam_id #{payload["steam_id"]}"
  s = Scraper.new(payload["steam_id"], payload["game_id"])
  s.scrape
  s.write
  puts "[+] Finished scraping and write"
  channel.ack(delivery_info.delivery_tag)
end
