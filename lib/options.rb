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
  def self.use(*args)
    args.flatten.each do |arg|
      (formstr,type)=arg.split('=')
      type||='b'
      forms=formstr.split('|')
      alt=forms[0]
      forms.each do |f|
        h=Hash.new
        h['alt']=alt
        h['type']=type
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

  def self.set_value(name,raw_value)
    raise "name is nil!" if name.nil?
    name=name.to_sym

    # convert raw_value to appropriate type
    value=''
    case @@opts[name]['type']
    when 'b'
      if (raw_value.class==TrueClass || raw_value.class==FalseClass) then
        value=raw_value
      elsif (raw_value.class==String)
        value=!raw_value.match(/^f|false$/i)
      else
#        puts @@opts[name].inspect
        raise "illegal class for boolean assignment: '#{name}=#{raw_value.to_s} (#{raw_value.class}) (must be TrueClass, FalseClass, or String)"
      end

    when 'i'
      
      raise "#{raw_value}: not an integer" if raw_value.class==String and !raw_value.match(/^[-+]?\d+$/)
      value=raw_value.to_i

    when 'f'
      value=raw_value.to_f

    else
      value=raw_value

    end
    @@opts[name.to_sym][:value]=value
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

  end


  # parse the command line:
  def self.parse
    raw_opts=Array.new              
    need_value=''                 # holds the name of an opt waiting for a value (eg -fuse 1)
    

    ARGV.each do |arg|
      a=String.new(arg)           # otherwise you get some weird "frozen string" error

      # check for raw opt:
      if (!a.match(/^-/) && need_value.length==0) then
        raw_opts<<a
        next
      end

      # are we waiting for a value?
      if (need_value.length > 0) then
        if a.match(/^-/)
          if @@opts[need_value].type=='b'
            a=true
          else
            raise "#{need_value}: missing value" 
          end
        end
        set_value(need_value,a)
        need_value=''             # reset flag
        next
      end

      # remove leading '-'s
      a.sub!(/^-+/,'')

      # split into name,value
      (name,value)=a.split('=')
      name=name.to_sym

      # is this a known option?
      a_hash=@@opts[name] or raise "#{a}: unknown option"

      # does name need a value?  Do we have one?  
      raise "#{need_value}: missing value" if (need_value.length > 0 && value.length==0) 

      # is a value provided?
      if (!value.nil?) then
        set_value(name,value)
      else
        need_value=a 
      end
    end

    # check for dangling need_value
    if need_value.length > 0
      if type(need_value)=='b'
        set_value(need_value,true)
      else
        raise "#{need_value}: missing value" 
      end
    end
    # check all requried opts are present:
    missing=Array.new
    @@opts.each_pair do |name,a_hash|
      missing << name if (a_hash[:required] && a_hash[:value].nil?) 
    end
    if missing.length > 0
      raise "missing options: #{missing.join(', ')}" 
    end

    # return remaining args:
    raw_opts
  end


  # retrieve a specfic option value:
  def self.value_of(name)
    name=name.to_sym
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

  # use a hash to set defaults.  This calls use(k), then use_default(k,v)
  # for each element in the hash.  Barfs (raises) exceptions if the class
  # of either key of value is invalid (according to self.valid_[key|value]_class().
  def self.use_hash(h)
    h.each_pair do |k,v|
      raise "invalid key class: #{k}, #{k.class}" unless valid_key_class(k)
      raise "invalid value class: #{v}, #{v.class}" unless valid_value_class(k)
      type=k.class.to_s.downcase[0,1]
      use(k+'='+type)
      use_defaults({k=>v})
    end
  end

  def self.type(name)
    @@opts[name.to_sym]['type']
  end

end
