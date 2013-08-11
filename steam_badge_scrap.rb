#!/usr/bin/ruby
require "json"
require "yaml"
require "nokogiri"
require "httparty"
require "bunny"

class Trader
  attr_reader :steam_id, :games_list, :have_excludes, :wants_include, :have_dups_only, :cards_hash
  
  def initialize(steam_id, game_list, have_excludes, want_includes, force_rebuild_card_cache)
    @steam_id = steam_id
    @game_list = game_list
    @have_excludes = have_excludes
    @want_includes = want_includes
    @have_dups_only = false
    @browser = ""
    @cards_hash = Hash.new()
    @output = String.new()
    @forum_intro = String.new()
    @force_rebuild_card_cache = force_rebuild_card_cache
  end

  def all_trading_card_games
    url = "http://www.steamcardexchange.net/index.php?showcase-filter-all"
    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    game_list = doc.css('a.showcase-game')
    game_list.each do |game|
      game_id = game.attributes["href"].value.split("-")[2].to_i
      name = game.children.text
      @game_list.push(game_id)
    end
      puts @game_list.inspect

  end

  def populate_card_hash
    if card_cash_rebuild_need?
      self.rebuild_card_cache()
    else
      self.get_card_cache
    end
  end

  def card_cash_rebuild_need?
    if not File.exists?("card_cache.json") or @force_rebuild_card_cache
      return true
    else
      return false
    end
  end

  def get_card_cache
    @cards_hash = JSON.parse(File.read("card_cache.json")).to_h
  end

  def rebuild_card_cache()
    @game_list.each do |game_id|
      url = "http://steamcommunity.com/id/#{@steam_id}/gamecards/#{game_id}/"
      self.populate_card_stats(url)
    end
    self.write_card_cache
  end

  def write_card_cache
    File.open("card_cache.json", 'w') {|f| f.write(@cards_hash.to_json) }
  end

  def populate_card_stats(url)
    url = url
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

  def have_for_trade(games, dups_only = false)
    i = 0
    @output << "Have for trade:\n\n"
    @cards_hash.each do |game, cards|
      if not games.include?(game)
        @output << "#{game}:\n"
        cards.each do |card_details|
          if dups_only
            @output << " - #{card_details["badge name"]}\n" if card_details["quantity"] > 1
          else
            @output << " - #{card_details["badge name"]}\n" if card_details["quantity"] > 0
          end
          i += 1
        end
        @output << "\n"
      end
    end
    puts "total for trade: #{i}"
  end

  def wants_from_trade(games)
    @output << "Want from trade:\n\n"
    @cards_hash.each do |game, cards|
      if games.include?(game)
        @output << "#{game}:\n"
        cards.each do |card_details|
          @output << " - #{card_details["badge name"]}\n" if card_details["quantity"] == 0
        end
        @output << "\n"
      end
    end
  end

  def add_intro(intro = "")
    intro = File.read("trade_intro.txt") if File.exists?("trade_intro.txt")
    @output << intro
  end

  def write_output
    File.open("trade.txt", 'w') {|f| f.write(@output) }
  end

  def get_item_value(item_name)
    @market_hash = Hash.new()

    url = "http://steamcommunity.com/market/search?q=#{item_name}"
    puts url

    html = HTTParty.get(url).body
    doc = Nokogiri::HTML(html)

    results = doc.css(".market_listing_row_link")

    results.each do |result|
     result_item = result.css('.market_listing_item_name').text.strip
      
      result_quantity = result.css('.market_listing_num_listings_qty').text.strip
      result_quantity = result_quantity.to_i

      result_price = result.css('.market_listing_right_cell').text
      result_price = result_price.split("$")[1].split(" ")[0].to_f

      puts result_item
      puts result_price
      puts result_quantity
    end

    
#    profile = Selenium::WebDriver::Firefox::Profile.new
#    profile["permissions.default.image"] = 2
#    @browser = Watir::Browser.new(:firefox, :profile => profile)
#    item_list.each do |item_string|
#      query_hash = Hash.new()
#      query_hash["q"] = item_string.gsub(" ", "+")
#      query_string = self.create_querystring_from_hash(query_hash)
#      @browser.goto("http://steamcommunity.com/market/search#{query_string}")
#      if @browser.div(:id => "result_0")
#        puts "Found an result_0 for item #{item_string}"
#        result_0 = @browser.div(:id => "result_0")
#        detail_text = result_0.element(:class => "market_listing_right_cell").text.split("\n")
#        @q = detail_text[0].to_i
#        @p = detail_text[2][1...-4].to_f
#        puts "Quantity #{@q}"
#        puts "Price #{@p}"
#      else
#        puts "I didn't find a result_0 for item #{item_string}"
#        @q = 0
#        @p = 0.0
#      end
#      @market_hash[item_string] = [@q, @p]
#    end
#    @browser.close
#    return @market_hash
  end

  def create_querystring_from_hash(hash)
    query_string = String.new()
    query_string << "?"
    hash.each {|key,value| query_string << "#{key}=#{value}"}
    return query_string
  end

  def merge_market_data
    @cards_hash.each do |game|
      existance_value = String.new()
      game[1].each do |badge|
        existance_value = badge["badge name"]
        if @market_hash.has_key?(existance_value)
          badge["market data"] = @market_hash[existance_value]
        end
      end
    end
  end

  def list_all_cards
    full_card_list = Array.new()
    @cards_hash.each do |game|
      game[1].each do |badge|
        full_card_list.push(badge["badge name"])
      end
    end
    return full_card_list
  end
  
end


@wants = ["System Shock 2"]
@exclude = []
@dups_only = true
do_rebuild_card_cache = true


t = Trader.new("ql6wlld", @game_ids, @excludes, @wants, do_rebuild_card_cache)

#t.get_item_value("Warchief")
t.all_trading_card_games
#t.populate_card_hash

exit

#t.add_intro()
#t.have_for_trade(@exclude, @dups_only)
#t.wants_from_trade(@wants)
#t.write_output
#t.list_all_cards
#t.get_items_value(t.list_all_cards)
#t.merge_market_data
#t.write_card_cache

puts "Total games with trading cards: #{t.cards_hash.length}"
