#!/usr/bin/ruby
#
require "bunny"
require "json"

conn = Bunny.new()
conn.start

channel = conn.create_channel

queue = channel.queue("card_scraper")

#game_ids = ["550", "620", "730", "207610", "107100", "55230", "4000", "1250", "98200", "201790", "300", "219150", "233740", "220860", "440", "91310", "3830", "211360", "105600", "49600", "204300", "245070", "40800", "238210", "35720", "41800", "225260", "8930", "4920", "212680", "108710", "41070", "200710", "63710", "107200", "214560", "113200", "104900", "72850", "20920", "220", "219740", "219190", "203210", "93200", "219200", "18500"]
game_ids = [15540, 92300, 224540, 223630, 108710, 217690, 234900, 236730, 204300, 107100, 49600, 8870, 218060, 63710, 239800, 111800, 49520, 225260, 204450, 3020, 204360, 241410, 214610, 219640, 238870, 225420, 231430, 115100, 730, 203770, 228440, 225360, 46750, 300, 91310, 216250, 211400, 218410, 18500, 224600, 243950, 230050, 220440, 219740, 570, 219200, 209060, 98800, 236090, 232050, 208140, 214570, 227300, 8500, 33680, 237430, 38600, 228260, 220260, 223730, 207890, 45400, 45450, 98200, 212680, 4000, 216130, 223220, 216090, 41800, 44350, 214770, 239450, 209080, 220, 25890, 203140, 219150, 207080, 41730, 241320, 57740, 229890, 242110, 233230, 220200, 1250, 227160, 203350, 42170, 230700, 550, 230650, 208600, 233510, 58230, 211340, 42910, 214560, 232750, 220860, 43160, 113020, 226740, 22100, 48700, 225220, 4920, 227280, 207530, 17710, 211360, 208520, 201790, 233740, 104900, 24240, 237570, 105800, 205610, 620, 223470, 215470, 235360, 233450, 3830, 222140, 237590, 201570, 221040, 222480, 204630, 222660, 227800, 222730, 93200, 217140, 35450, 234490, 55230, 210770, 218680, 45100, 41070, 8930, 204880, 228960, 238890, 202170, 227100, 45000, 239660, 212480, 107200, 239350, 115110, 212070, 46260, 220660, 227680, 245070, 207150, 231020, 234160, 209540, 224820, 40800, 233720, 233700, 238210, 206370, 440, 105600, 113200, 72850, 230820, 215280, 231160, 207610, 20920, 211260, 203210, 201420, 203160, 200710, 34330, 214360, 35720, 209950, 57690, 219190, 72200, 13230, 233530, 42160, 230410, 222750, 200170, 234290, 215690, 220820]
game_ids.each do |game_id|
  payload = {"game_id" => game_id, "steam_id" => "ql6wlld"}

  queue.publish(payload.to_json)
end

conn.stop
