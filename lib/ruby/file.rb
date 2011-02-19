#puts "#{__FILE__} checking in"
class File

  def self.chop_ext(path)
    File.join(File.dirname(path),File.basename(path,File.extname(path)))
  end

  def self.replace_ext(path,ext)
    [chop_ext(path),ext].join('.')
  end

  def self.slurp(filename)
    contents=''
    File.open(filename).each do |l|
      contents+=l
    end
    contents
  end

  def self.spit(filename,contents)
    File.open(filename,"w") do |f|
      f.puts contents
    end
  end
end
