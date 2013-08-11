#!/usr/bin/ruby
#
require "bunny"
require "couchrest"

class Trader

  attr_reader :steam_id, :games_list, :cards_hash
  attr_writer :want_includes, :want_missing_only
  attr_writer :have_excludes, :have_dups_only
  attr_writer :print_index, :print_quantity, :print_empty

  def initialize(steam_id, game_list, want_includes, have_excludes)
    @steam_id = steam_id
    @game_list = game_list
    @want_includes = want_includes
    @have_excludes = have_excludes
    @want_missing_only = true
    @have_dups_only = false
    @print_index = true
    @print_quantity = true
    @print_empty = false

    db = CouchRest.database("http://127.0.0.1:5984/steam")
    doc = db.get("games")
    @cards_hash = doc.to_hash
    @cards_hash.delete("_id")
    @cards_hash.delete("_rev")
  end

  def build_trade
    @output = String.new
    @output << "Have for trade:\n\n"
    @cards_hash.each do |game, cards|

      # skip the game if its included in the exclude list
      if @have_excludes.include?(game)
        break
      end

      # decide if its an empty game
      if @print_empty == true
        @output << "#{game}:\n"
      else
        if own_any_cards?(cards)
          @output << "#{game}:\n"
        end
      end

    end
  puts @output
  end

  def own_any_cards?(cards_array)
    have_cards = false
    cards_array.each do |card|
      if card["quantity"] > 0
        have_cards = true
        break
      end
    end
    return have_cards
  end
end

t = Trader.new("ql6wlld", "", "", "")
t.build_trade
