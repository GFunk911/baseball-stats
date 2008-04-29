#!/usr/bin/env ruby
require 'open-uri'
require 'hpricot'
require 'pp'
require 'facets/enumerable/collect'
require 'facets/hash/autonew'
require 'facets/file/write'
require 'watir'
require 'log'

PCILog::LOGS_DIR = File.dirname(__FILE__) + "/logs"
PCILog::OLD_LOGS_DIR = File.dirname(__FILE__) + "/logs/old_logs"

begin 
  FileUtils.mkdir(File.dirname(__FILE__) + "/logs")
  FileUtils.mkdir(File.dirname(__FILE__) + "/logs/old_logs")
rescue
end

def doc
  $doc ||= Hpricot(open($url))
end

class String
  def to_num
    (self =~ /^[\d.]+$/) ? to_f.to_num : self      
  end
end

class Numeric
  def to_num
    (to_i == to_f) ? to_i : to_f
  end
end

class Hpricot::Elem
  def parent_of(t)
    (parent.name == t) ? parent : parent.parent_of(t) 
  rescue
    nil
  end
  def headings
    (self/"tr")[0].children.compact_map('') { |x| x.inner_text.strip }
  end
  def columns(r=nil,ops={})
    res = []
    r = [r] if r.is_a? Numeric
    r ||= 0..30
    r.each do |col_i| 
      col = (self/"tr/td[#{col_i}]") 
      break if (col.size == 0) and (col_i > 3)
      col.each_with_index do |x,i| 
        res[i] ||= []
        res[i] << x.inner_text.strip unless res[i] == :reject
        reg = ops[col_i] || ((i == 0) ? nil : ops[:body])
        if reg and !(x.inner_text.strip =~ reg)
          puts "rejecting #{x.inner_text} for not matching #{reg}"
          res[i] = :reject 
        end
      end
    end
    res = res[1..-1] if ops[:remove_header]
    res.reject { |x| x == :reject }
  end
  def column_hashes(ops={})
    cols = columns(nil,ops)
    hs = headings
    cols.map { |x| x = x.map { |el| el.to_num }; Hash.zipnew(hs,x) }
  end
end

def table_with_cells_cell_type(ct,*strs)
  table_lists = strs.flatten.map { |str| (doc/"//#{ct}[text()='#{str}']").compact_map { |x| x.parent_of('table') } }
  table_lists.flatten.select { |x| table_lists.all? { |table_list| table_list.include?(x) } }.first
end

def table_with_cells(*strs)
  table_with_cells_cell_type('th',*strs) || table_with_cells_cell_type('td',*strs)
end

