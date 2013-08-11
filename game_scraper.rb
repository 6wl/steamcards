#!/usr/bin/ruby
#
require "nokogiri"
require "bunny"
require "httparty"
require "json"
require "couchrest"

class Scraper
  attr_reader :cards_hash

  def initialize()
    @cards_hash = Hash.new()
    @db = CouchRest.database!("http://127.0.0.1:5984/steam")
  end

  def scrape()
    url = "http://www.steamcardexchange.net/index.php?showcase-filter-all"
    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    game_list = doc.css('a.showcase-game')
    game_list.each do |game|
      game_id = game.attributes["href"].value.split("-")[2].to_i
      name = game.children.text.to_s
      @cards_hash[name] = {"id" => game_id}
    end
  end

  def write()
    key = @cards_hash.keys[0]
    @doc = @db.get("games")
    @cards_hash.each do |key, value|
      puts key, value
      @doc[key] = value
      puts @doc
    end
    @db.save_doc(@doc)
  end

end
  
conn = Bunny.new()
conn.start()

channel = conn.create_channel()

queue = channel.queue("game_scraper")

queue.subscribe(:block => true, :ack => true) do |devlivery_info, properties, payload|
  payload = JSON.parse(payload)
  puts "[+] Accepted message to publish"
  s = Scraper.new()
  puts "[+] Beginning scrap of games"
  s.scrape
  puts "[+] Writing out data to DB"
  s.write
  puts "[+] Finished scraping and write"
end
