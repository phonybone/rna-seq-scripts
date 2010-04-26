#puts "#{__FILE__} checking in"
class File
  def self.chop_ext(path)
    File.join(File.dirname(path),File.basename(path,File.extname(path)))
  end
  def self.replace_ext(path,ext)
    [chop_ext(path),ext].join('.')
  end
end
