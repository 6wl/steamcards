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
    @game = Hash.new()
    @db = CouchRest.database("http://127.0.0.1:5984/steam")
  end

  def scrape()
    cards = Hash.new()
    cards = {"cards" => []}
    url = "http://steamcommunity.com/id/#{@steam_id}/gamecards/#{@game_id}/"

    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    current_game = doc.css('.profile_small_header_location')[1].text
    @game = {"game_name" => current_game}

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

      #@game.merge!("cards")[badge_current_index - 1] = {"card_name" => badge_text, "owned" => badge_quantity}
      cards["cards"][badge_current_index - 1] = {"card_name" => badge_text, "owned" => badge_quantity}
    end
    @game.merge!(cards)
  end
  
  def merge_in_new(doc, game)
    doc["game_name"] = game["game_name"]
    doc["cards"] = game["cards"]
    return doc
  end

  def write()
    doc = @db.view("games/game_by_id", {"key" => @game_id})["rows"][0]["value"]
    merged_doc = self.merge_in_new(doc, @game)
    @db.save_doc(merged_doc)
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
