require 'open-uri'
require 'hpricot'
require 'pp'

def doc
  $doc ||= Hpricot(open('http://jira.princeton.com/secure/IssueNavigator.jspa?requestId=11084&mode=hide&os_username=filter_owner&os_password=pcipass'))
end

class Hpricot::Elem
  def parent_of(t)
    (parent.name == t) ? parent : parent.parent_of(t) 
  rescue
    nil
  end
  def columns(r,ops={})
    res = []
    r = [r] if r.is_a? Numeric
    r.each do |col_i| 
      col = (self/"tr/td[#{col_i}]") 
      col.each_with_index do |x,i| 
        res[i] ||= []
        res[i] << x.inner_text.strip unless res[i] == :reject
        res[i] = :reject if ops[col_i] and !(x.inner_text.strip =~ ops[col_i])
      end
    end
    res = res[1..-1] if ops[:remove_header]
    res.reject { |x| x == :reject }
  end
end

def table_with_cells(*strs)
  table_lists = strs.flatten.map { |str| (doc/"//td[text()='#{str}']").map { |x| x.parent_of('table') }.select { |x| x } }
  table_lists.flatten.select { |x| table_lists.all? { |table_list| table_list.include?(x) } }.first
end


pp table_with_cells(:Assignee,:Reporter).columns(2..3,2 => /PEG-\d+/)
