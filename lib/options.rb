class Options
  require 'rubygems'              # for active_record
  require 'active_record'         # for cattr_accessor

  @@opts=Hash.new                 # keys are ...?
  def self.opts_hash; @@opts; end
  @@valid_key_classes=%w{String Symbol}
  @@valid_value_classes=%w{String Symbol Fixnum Float}
  def self.valid_key_class(o)
    @@valid_key_classes.include? o.class.to_s
  end
  def self.valid_value_class(o)
    @@valid_value_classes.include? o.class.to_s
  end

  # define the options to use
  # eg: fuse|f=i
  # Can be called repeatedly? I think so
  def self.use(*args)
    args.flatten.each do |arg|
      (formstr,arg_type)=arg.split('=')
      arg_type||='b'
      forms=formstr.split('|')
      alt=forms[0]
      forms.each do |f|
        h=Hash.new
        h['alt']=alt
        h['type']=arg_type
        @@opts[f.to_sym]=h

        cattr_accessor f          # defines the new accessor
      end
    end
  end


  def self.use_defaults(h) 
    raise "#{h} not a Hash" unless h.kind_of?(Hash)
    h.each_pair do |k,v|
      k=k.to_sym
      @@opts[k]={} if @@opts[k].nil?
      set_value(k,v)
    end
  end

  def self.required(*args)
    args.flatten.map{|a| a.to_sym}.each do |a|
      a_hash=@@opts[a] or raise "'#{a}: unknown cmd-line option"
      a_hash[:required]=true;
    end
  end

  # set a value;
  # checks for known (named) values, correct type
  # raises exceptions on errors
  # returns void
  # stores values in both @@opts and via accessors
  def self.set_value(name,raw_value)
    raise "name is nil!" if name.nil?
    raise "set_value: unknown name #{name}" if @@opts[name.to_sym].nil?
    raise "internal error: missing 'alt' value for #{name}" if @@opts[name.to_sym]['alt'].nil?
    name=@@opts[name.to_sym]['alt'].to_sym

    # convert raw_value to appropriate type
    value=''
    raise "set_value: no type for options '#{name}'" if @@opts[name]["type"].nil?
    case @@opts[name]["type"]
    when 'b'
      if (raw_value.class==TrueClass || raw_value.class==FalseClass) then
        value=raw_value
      elsif (raw_value.class==String)
        value=!raw_value.match(/^f|false|t|true$/i)
      else
        #        puts @@opts[name].inspect
#        raise "illegal class for boolean assignment: '#{name}=#{raw_value.to_s} (#{raw_value.class}) (must be TrueClass, FalseClass, or String)"
        raise "'#{raw_value.to_s}': not a boolean nor one of 'true','false'"
      end

    when 'i'
      raise "'#{raw_value.to_s}': not an integer" if raw_value.class==String and !raw_value.match(/^[-+]?\d+$/)
      value=raw_value.to_i

    when 'f'
      float_re=Regexp.new '^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$' # taken from `man perlfaq4`
      raise "'#{raw_value.to_s}': not a float" if raw_value.match(float_re).nil?
      value=raw_value.to_f

    else
      value=raw_value

    end
    @@opts[name][:value]=value
    begin
      send("#{name}=",value)    # also set the accessor
    rescue Exception => e
      #    puts "msg is #{e.message}"
      if e.message.match(/undefined method/)
        raise "'#{name}': not a valid option"
      else
        raise e
      end
    end

#    puts "name=#{name}, alt=#{@@opts[name]['alt']}"
#    set_value(@@opts[name]['alt'],value) unless @@opts[name]['alt']==name

  end


  def self.parse(*args)
    args=ARGV if args.size==0
    args=args.flatten

    # Stringify args, then change all '-arg=val' to '-arg', 'val', 
    args.map! {|x| x=x.to_s}    # convert all args to String (probably unnecessary, but ya never know)

    # what if we just immediately assign these, instead of pushing back to args???
    args1=Array.new
    args.each do |arg|
      if arg.match(/^-[^=]+=/)  # if it starts with '-' and there's a '=' somewhere after, but not right after the '-'
        a,v=arg.split('=')
        a.sub!(/^-+/,'')
        v.gsub!(/^['"]/,'')
        v.gsub!(/["']$/,'')
        set_value(a,v)          # bam!
      else
        args1<<arg              # carry through
      end
    end
    args=args1
    
    raw_opts=Array.new
    need_value=nil
    
    # chew through args:
    args.each do |a|
      arg=String.new a          # has to be here to avoid "frozen value" errors (trying to alter an immutable string??)
      if arg.match(/^-/)
        arg.sub!(/^-+/,'')       # get rid of leading '-'s
        arg=arg.to_sym

        raise "missing value for '#{need_value}' (#{arg})" unless need_value.nil?
        raise "unknown arg #{arg}\n\n#{@@opts.inspect}" unless known_arg(arg)
        t=arg_type(arg)
        if arg_type(arg)=='b'
          set_value(arg,true)
        else
          need_value=arg
        end

      else                      # arg doesn't start with '-'
        if need_value.nil?
          raw_opts<<arg
        else
          set_value(need_value,arg)
          need_value=nil
        end                       # if need_value.nil?
      end                         # if arg.match(/^-/)
    end                           # args.each do |arg|
    
    # check for missing value at end:
    raise "missing value for '#{need_value}'" unless need_value.nil?

    # check all requried opts are present:
    missing=Array.new
    @@opts.each_pair do |name,a_hash|
      missing << name if (a_hash[:required] && a_hash[:value].nil?) 
    end
    if missing.length > 0
      raise "missing options: #{missing.join(', ')}" 
    end
    
    return raw_opts
  end

  def self.known_arg(arg)
    !@@opts[arg.to_sym].nil?
  end

  def self.arg_type(arg)
    @@opts[arg.sym]['type']
  end

  # retrieve a specfic option value:
  def self.value_of(name)
    name=name.to_sym
    return nil if @@opts[name].nil?
    @@opts[name] && @@opts[name][:value]
  end

  # same as above
  def self.[](name) value_of(name) end

  def self.[]=(name,value)
    name=name.to_sym
    if (@@opts[name])
      #    @@opts[name][:value]=value
      set_value(name,value)
    end
  end


  # return a hash of all options and values
  def self.all
    all={}
    @@opts.each_pair do |name,a_hash|
      all[name]=a_hash[:value]
    end
    all
  end

  def self.pretty_print(joiner="\n")
    report=Array.new
    @@opts.each_pair do |name,a_hash|
      report<<"#{name}: #{a_hash[:value]}"
    end
    report.join(joiner)
  end

  # use a hash to set defaults.  This calls use(k), then use_default(k,v)
  # for each element in the hash.  Barfs (raises) exceptions if the class
  # of either key of value is invalid (according to self.valid_[key|value]_class().
  def self.use_hash(h)
    h.each_pair do |k,v|
      raise "invalid key class: #{k}, #{k.class}" unless valid_key_class(k)
      raise "invalid value class: #{v}, #{v.class}" unless valid_value_class(k)
      arg_type=k.class.to_s.downcase[0,1]
      use(k+'='+arg_type)
      use_defaults({k=>v})
    end
  end

  def self.arg_type(name)
    @@opts[name.to_sym]['type']
  end

  #  puts "#{__FILE__} checking in"
end
