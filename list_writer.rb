#!/usr/bin/ruby
require "bunny"
require "couchrest"

class Trader

  attr_reader :steam_id, :games_list, :cards_hash
  attr_reader :output
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
    self.trade_intro()
    self.have_for_trade()
    self.want_from_trade()
  end

  def trade_intro
    intro = File.read("intro.txt") if File.exists?("intro.txt")
    @output << intro
  end

  def have_for_trade
    @output << "Have for trade:\n"
    @cards_hash.each do |game, cards|

      # skip the game if its included in the exclude list
      if @have_excludes.include?(game)
        break
      end

      # decide if its an empty game
      if @print_empty == true
        @output << "\n#{game}:\n"
      else
        if own_any_cards?(cards)
          ownage = self.ownage(cards)
          @output << "\n#{game} #{ownage[1]}/#{ownage[0]}:\n"
        end
      end

      cards.each do |card_details|
        if @have_dups_only
          @output << " - (#{card_details["quantity"]}) #{card_details["badge name"]}\n" if card_details["quantity"] > 1
        else
          @output << " - (#{card_details["quantity"]}) #{card_details["badge name"]}\n" if card_details["quantity"] > 0
        end
      end

    end
  end

  def want_from_trade
    @output << "\n\nWant from trade:\n"
    @cards_hash.each do |game, cards|
      if @want_includes.include?(game)
        @output << "\n#{game}:\n"

        cards.each do |card_details|
          if @want_missing_only
            @output << " - #{card_details["badge name"]}\n" if card_details["quantity"] == 0
          else
            @output << " - #{card_details["badge name"]}\n"
          end
        end
      end
    end
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

  def ownage(cards_array)
    total_in_set = cards_array.length
    
    total_unique_owned = cards_array.length
    cards_array.each do |card|
      if card["quantity"] == 0
        total_unique_owned -= 1
      end
    end

    total_owned = 0
    cards_array.each do |card|
      total_owned += card["quantity"]
    end

    return [total_in_set, total_unique_owned, total_owned]
  end

  def total_ownage()
    total_games = 0

    @cards_hash.each do |game, cards|
      cards.each do |card|
        if card["quantity"] > 0
          total_games += 1
          break
        end
      end
    end


    total_cards = 0
    
    @cards_hash.each do |game, cards|
      cards.each do |card|
        if card["quantity"] > 0
          total_cards += card["quantity"]
        end
      end
    end

    puts total_games, total_cards
  end

end

t = Trader.new("ql6wlld", "", ["System Shock 2"], ["System Shock 2"])
t.build_trade
puts t.output
t.total_ownage
