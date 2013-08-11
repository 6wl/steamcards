#!/usr/bin/ruby
#
require "bunny"
require "json"

conn = Bunny.new()
conn.start

channel = conn.create_channel

queue = channel.queue("game_scraper")
payload = {"game" => "blah"}
queue.publish(payload.to_json)

conn.stop
