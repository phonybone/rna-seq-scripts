class AppConfig  
  def self.load(config_file, section)
    if (config_file.nil?)
      if (not defined?(RAILS_ROOT))
        raise "undefined config_file"
      end
      config_file = File.join(RAILS_ROOT, "config", "application.yml")
    end
    puts "config_file is #{config_file}"

    if File.exists?(config_file)
      yml_contents=YAML.load(File.read(config_file))
      if (section.nil?) 
        section = defined?(RAILS_ENV) ? RAILS_ENV : 'default'
      end
      if (not defined? yml_contents[section] or yml_contents[section].nil?)
        raise "no section '#{section}' in #{config_file}"
      end

      config = yml_contents[section]
      puts "config is #{config.inspect}"

      config.keys.each do |key|
        cattr_accessor key
        send("#{key}=", config[key])
      end

      common=yml_contents['common']
      if common
        common.keys.each do |key|
          cattr_accessor key
          send("#{key}=",common[key])
        end
      end                       # if common
    else
      raise "#{config_file} dosen't exists"
    end                         # if File.exists?
  end
end
