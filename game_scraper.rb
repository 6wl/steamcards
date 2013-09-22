#!/usr/bin/ruby
#
require "nokogiri"
require "bunny"
require "httparty"
require "json"
require "couchrest"
require "yaml"

class Scraper
  attr_reader :cards_hash

  def initialize(config)
    connection = "http://#{config["server"]}:#{config["port"]}/#{config["database"]}"
    @games = Array.new()
    @db = CouchRest.database!(connection)
  end

  def scrape()
    url = "http://www.steamcardexchange.net/index.php?showcase-filter-all"
    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    game_list = doc.css('a.showcase-game')
    game_list.each do |game|
      game_id = game.attributes["href"].value.split("-")[2].to_i
      game_name = game.children.text.to_s
      @games.concat([{"game_name" => game_name, "game_id" => game_id}])
    end
  end

  def create_unique()
    @games.each do |game|
      params = {"key" => game["game_id"]}
      doc = @db.view("games/exists_by_id", params)
      if doc["rows"].length == 0
        new_doc = {"game_name" => nil, "game_id" => game["game_id"]}
        @db.save_doc(new_doc)
      end
    end
  end

end

config = YAML.load_file("config.yaml")

conn = Bunny.new()
conn.start()

channel = conn.create_channel()

queue = channel.queue("game_scraper")

queue.subscribe(:block => true, :ack => true) do |devlivery_info, properties, payload|
  payload = JSON.parse(payload)
  puts "[+] Accepted message to publish"
  s = Scraper.new(config)
  puts "[+] Beginning scrap of games"
  s.scrape
  puts "[+] Writing out data to DB"
  s.create_unique
  puts "[+] Finished scraping and write"
end
