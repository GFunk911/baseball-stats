require 'rake'

task :make_exe do 
  puts `rubyscript2exe.bat todays_starters.rb --test`
end

task :push do 
  puts `git push origin master`
end

