#puts "#{__FILE__} checking in"
module YAML
  def self.load_config(filename)
    conf=File.open(filename) { |yml| YAML.load yml }
  end
end

