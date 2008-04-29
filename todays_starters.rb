require 'table_parse'

def ie
  $ie ||= Watir::IE.new
end
at_exit { ie.close if $ie }

def player_url(pl,s)
  PVar[:player_urls].hash_get_with_default(pl,s) do |player,site|
    if site == 'THT'
      tht_url(player) 
    else
      ie.goto 'google.com'
      ie.text_field(:title,'Google Search').set("#{player} #{site}")
      ie.button(:value,"I'm Feeling Lucky").click
      ie.url
    end
  end
end

def raw_page_text(player,site)
  puts "getting page text for #{player} at #{site}"
  open(player_url(player,site)) { |f| f.read }
end

def page_text(player,site)
  PVar[:player_text].hash_get_with_default(player,site) { |p,t| raw_page_text(p,t) }
end

def raw_player_stat_hash(player,year)
  $doc = Hpricot(page_text(player,'THT'))
  h = table_with_cells('RA','FIP').column_hashes.find { |x| x['Year'] == year } || {}
  h2 = table_with_cells('W','L','ERA').column_hashes.find { |x| x['Year'] == year } || {}
  h.merge(h2)
end

def player_stat_hash(player,year)
  raw_player_stat_hash(player,year)
end

def stat_headings
  %w(G IP ERA xFIP W L K BB HR WHIP)
end

def tht_url(player)
  f,l = player.split
  "http://www.hardballtimes.com/main/stats/players/index.php?lastName=#{l}&firstName=#{f}"
end

module Today
  def self.starters
    player_ids.map { |x| "http://sports.espn.go.com/mlb/players/profile?playerId=#{x}" }.map do |url|
      ie.goto(url)
      ie.title.scan(/ESPN - (.*) Stats/).flatten.first
    end
  end

  def self.stat_rows
    starters.map do |player|
      h = player_stat_hash(player,2008)
      res = [player] + stat_headings.map { |x| h[x] }
      h = player_stat_hash(player,2007) 
      res += [''] + stat_headings.map { |x| h[x] }
    end
  end

  def self.player_ids
    ie.goto "http://sports.espn.go.com/mlb/scoreboard"
    res = ie.html.scan(/playerid=(\d+)[^\d]/i).flatten
    res = res[0..1] if ARGV.include?('--test')
    res
  end
end

def csv
  res = []
  res << ['Player'] + stat_headings + [''] + stat_headings
  res += Today.stat_rows
  res.map { |row| row.join(",") }.map_with_index { |x,i| (i%2==0 and i != 0) ? x+"\n" : x }.join("\n")
end

puts "Creating C:\\todays_starters.csv"
File.create("c:\\todays_starters.csv",csv)
exit
