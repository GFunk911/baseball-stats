class Time
  def ymdhms(del="_")
    strftime("%Y#{del}%m#{del}%d#{del}%H#{del}%M#{del}%S")
  end
  def mdhms
    strftime("%m/%d %H:%M:%S")
  end
  def hms
    strftime("%H:%M:%S")
  end
end

class PCILog
  attr_accessor :name, :file_ext, :new_every_time
  def klass
    self.class
  end
  def initialize(fname)
    @fname = fname.to_s
    @file = nil
    @hooks = []
    @echo = false
  end
  def echo?
    @echo == true
  end
  def echo!
    @echo = true
  end
  def file_name
    @fname + "." + file_ext
  end
  def file_ext
    @file_ext ||= "log"
  end
  def file_loc
    log_dir + "/" + file_name
  end
  def archived_file_name
    @fname + "_" + time_str + "." + file_ext
  end
  def archived_file_loc
    klass.archived_log_dir + "/" + archived_file_name
  end
  def time_str
    Time.now.ymdhms
  end
  def exists?
    FileTest.exist?(file_loc)
  end
  def archive!
    File.rename(file_loc,archived_file_loc) if exists?
  end
  def start!
    archive!
  end
  def format(s)
    s = s.to_s
    s = s + "\n"
    s
  end
  def write(s)
    File.open(file_loc,File::WRONLY|File::CREAT|File::EXCL) do |f|
      f << format(s)
    end
    puts format(s) if echo?
  end
  def log(s)
    start! if @file.nil? or @new_every_time == true
    write(s)
    @hooks.each { |hook| hook.call(s) }
    self
  end
  def <<(s)
    log(s)
  end
  def hook(&b)
    @hooks << b
  end
  def self.log_hash
    Hash.new() { |h,k| h[k] = PCILog.new(k) }
  end
  def self.[](l)
    @logs ||= log_hash
    @logs[l]
  end
  def self.log_dir
    LOGS_DIR
  end
  def log_dir
    klass.log_dir
  end
  def self.archived_log_dir
    log_dir + "/old_logs"
  end
  def release!
    if @file||4 != 4
      @file.close
      @file = nil
    end
  end
  def self.release!
    @logs.each do |k,v|
      v.release!
    end
  end
end    

class PVar < PCILog
  def store!
    write_to_file { |f| Marshal.dump(@val,f) }
  end
  def val=(i)
    @val = i
    store!
  rescue => exp
    puts "val= class #{i.class}"
    raise exp
  end
  def val
    load_val_from_file unless defined?(@val)
    @val
  end
  def val_from_file
    v = nil
    if File.exist?(file_loc)
      File.open(file_loc,File::RDONLY) do |f|
        v = Marshal.load(f)
      end
    end
    v
  rescue => exp
    puts "Exception in PVar::val_from_file (#{@fname})"
    raise exp
  end
  def load_val_from_file
    @val = val_from_file
  end
  def write_to_file
    archive!
    File.open(file_loc,File::WRONLY|File::CREAT|File::TRUNC) do |f|
      yield(f)
    end
  end
  def self.[](n)
    @vars ||= Hash.new() { |h,k| h[k] = new(k) }
    @vars[n]
  end
  def self.def_to_methods!
    meths = [:to_s,:to_i,:to_f]
    meths.each do |sym|
      define_method(sym) do
        self.val.send(sym)
      end
    end
  end
  def delete!
    File.delete(file_loc)
    @val = nil
  end
  def_to_methods!
  def set!
    @val = yield(val)
    store!
  end
  def save_after!
    yield(val)
    store!
  end
  def store_after
    yield(val)
    self.val = val
  end
end

class PVarDir < PVar
  attr_writer :dir
  def initialize(a)
    super(a[1])
    self.dir = a[0]
  end
  def dir
    raise "foo" if @dir.nil? or @dir.to_s.strip == ""
    @dir
  rescue => exp
    puts exp
    raise exp
  end
  def log_dir
    klass.log_dir + "/#{dir}"
  end
  def make_dir!
    if Dir.entries(klass.log_dir).select { |x| x == dir.to_s }.empty?
      Dir.mkdir(log_dir)
    end
  end
  def self.[](n)
    @vars ||= Hash.new() { |h,k| h[k] = new(k) }
    res = @vars[n]
    res.make_dir!
    res
  end 
  def delete_dir!
    Dir.delete(log_dir)
  end
  def self.refresh_all!
    @vars = Hash.new() { |h,k| h[k] = new(k) }
  end
end

class PArr
  include Enumerable
  attr_reader :name, :meta
  def initialize(name)
    @name = name
    handle_startup_commands!
  end
  def ld
    File.dirname(__FILE__) + "/logs"
  end
  def startup_command_file_exists?
    if Dir.entries(ld).select { |x| x == name.to_s }.empty?
      #puts "no parr dir file, found #{Dir.entries('logs').sort.join(' | ')}"
      false
    else
      res = Dir.entries("#{ld}/#{name}/").select { |x| x == "startup_commands.rb" }.size > 0
      #puts (res ? "found startup commands file" : "no startup commands file")
      res
    end
  end
  def startup_command_file_loc
    "#{ld}/#{name}/startup_commands.rb"
  end
  def startup_command_str
    File.open(startup_command_file_loc,File::RDONLY) do |f|
      f.inject("") { |s,i| s + i + ";" }
    end
  end
  def execute_startup_commands!
    #puts "executing startup commands #{startup_command_str}"
    instance_eval(startup_command_str)
  end
  def handle_startup_commands!
    if startup_command_file_exists?  
      execute_startup_commands! 
      comment_startup_commands!
    else
      #puts "no startup commands"
    end
  end
  def comment_startup_commands!
    str = startup_command_str.split(";").map { |x| (x =~ /^#/) ? x : "##{x}" }.join("\n")
    File.open(startup_command_file_loc,File::WRONLY|File::TRUNC) { |f| f << str }
  end
  def size
    meta.size
  end
  def keys
    meta
  end
  def values
    keys.map { |k| self[k] }
  end
  def meta
    PVarDir[[name,meta_name]].val ||= []
  end
  def meta_pvar
    PVarDir[[name,meta_name]]
  end
  def meta=(x)
    PVarDir[[name,meta_name]].val = x
  end
  def meta_name
    "#{name}_meta"
  end
  def spot_name(i)
    "#{name}_#{i}"
  end
  def spot_sym(i)
    spot_name(i).to_sym
  end
  def [](i)
    PVarDir[[name,spot_sym(i)]].val
  end
  def []=(i,o)
    PVarDir[[name,spot_sym(i)]].val = o
    self.meta += [i] unless self.meta.include?(i)
  end
  def self.arr_hash
    Hash.new { |h,k| h[k] = PArr.new(k) }
  end
  def self.[](l)
    @arrs ||= arr_hash
    @arrs[l]
  end
  def each
    meta.each do |i|
      yield(i,self[i])
    end
  end
  def delete(k)
    return unless meta.include?(k)
    self.meta = self.meta - [k]
    PVarDir[[name,spot_sym(k)]].delete!
  end
  def empty?
    keys.empty?
  end
  def clear!
    keys.each { |k| delete(k) }
    raise "foo" unless meta.empty?
  end
  def delete!
    clear!
    meta_pvar.delete!
    raise "foo" unless meta_pvar.val.nil?
    meta_pvar.delete_dir!
  end
end

class File
  def self.archived_name(fn)
    n,file_ext = *(fn.split("."))
    Time.now.ymdhms
    n + "_" + Time.now.ymdhms + "." + file_ext
  end
  def self.archive!(file_path)
    path,fn = File.split(file_path)
    new_path = path + "/old_logs/" + archived_name(fn)
    rename(file_path,new_path)
  end
end

class PVar
  def hash_get_with_default(*args)
    self.val = {} unless val
    k = args.flatten
    if val[k].nil?
      self.val[k] = yield(*args) 
      self.val = self.val
    end
    self.val[k]
  end
end