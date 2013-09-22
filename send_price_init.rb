#!/usr/bin/ruby
#
require "bunny"
require "json"
require "couchrest"

conn = Bunny.new()
conn.start

channel = conn.create_channel

queue = channel.queue("price_scraper_init")

card_names = Array.new()

db = CouchRest.database("http://127.0.0.1:5984/steam")
db.view("cards/card_name_by_game_name", params = {})["rows"].each do |row|
#db.view("cards/card_name_by_game_name", params = {"key"=>"Gratuitous Space Battles"})["rows"].each do |row|
  payload = Hash.new()
  payload["game_name"] = row["key"]
  payload["card_name"] = row["value"]
  queue.publish(payload.to_json)
end

#card_names = [{"game_name" => "team fortress", "card_name" => "ENGINEER"}, {"game_name" => "team fortress", "card_name" => "SPY"}]
#card_names.each do |game_card|
#  payload = game_card
#  queue.publish(payload.to_json)
#end

conn.stop
