#!/usr/bin/env ruby
class Object
  def common_methods
    7.methods + "".methods + 7.class.methods + "".class.methods
  end
  def uniq_methods
    (methods - common_methods).sort
  end
  def uniq_instance_methods(include_ar=true)
    (instance_methods - common_methods - superclass.instance_methods - uniq_modules.map { |x| x.instance_methods }.flatten + (include_ar ? ar_methods : [])).sort
  end
  def uniq_modules
    included_modules - superclass.included_modules
  end
  def ar_methods
    return [] unless inherits_from?(ActiveRecord::Base)
    columns.map { |x| x.name }.map { |x| [x,"#{x}="] }.flatten
  end
  def inherits_from?(x)
    return true if superclass == x
    return false unless superclass
    superclass.inherits_from?(x)
  end
end

require 'scrubyt'
require 'open-uri'
require 'pp'

def datja
  def_proc = lambda do
    fetch "http://sports.espn.go.com/mlb/scoreboard?date=20080428"
    content_page "http://sports.espn.go.com/mlb/scoreboard?date=20080430"
    starter do 
      team 'BAL:'
      name 'Cabrera'
    end
  end
  $ext ||= Scrubyt::Extractor.new(nil,def_proc)
  $data ||= $ext.result
end

def data
  def_proc = lambda do
    fetch "http://sports.espn.go.com/mlb/players/profile?statsId=7603"
    #content_page "http://sports.espn.go.com/mlb/scoreboard?date=20080430"
    era '2.89'
    so '11'
    whip '1.71'
  end
  $ext ||= Scrubyt::Extractor.new(nil,def_proc)
  $data ||= $ext.result
end

def todays_starters
  data.to_hash.map { |x| x[:team] }.map { |x| x.scan(/([A-Z][A-Z][A-Z]: [A-Z][a-z]+) /) }.flatten
end

def my_starters
  ['MIN: Baker','OAK: Blanton','DET: Bonderman','BAL: Cabrera','TAM: Shields','CIN: Arroyo','COL: Francis','PIT: Maholm','PIT: Snell','MIL: Suppan']
end

def my_starting_starters
  todays_starters.select { |x| my_starters.include?(x) }
end

pp data.to_hash

pp todays_starters
pp my_starting_starters
exit



