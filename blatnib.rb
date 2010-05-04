#!/hpc/bin/ruby
require 'fileutils'

# run blat on a (converted) export.txt file (fastaq).  Run it against each
# chr for the organism.  
# Use .nib files
# concat and sort all results

require 'rubygems'
require 'sqlite3'

class File
  def self.chop_ext(path)
    File.join(File.dirname(path),File.basename(path,File.extname(path)))
  end
  def self.replace_ext(path,ext)
    [chop_ext(path),ext].join('.')
  end
end

class Time
  SECS_IN_MIN=60
  SECS_IN_HOUR=SECS_IN_MIN*60
  SECS_IN_DAY=SECS_IN_HOUR*24
  SECS_IN_YEAR=SECS_IN_DAY*365 # screw leap years
  
  def self.timespan(t1,t0)
    t0=t0.to_i
    t1=t1.to_i
    d=(t1-t0).abs
    nYears=d/SECS_IN_YEAR
    d=d%SECS_IN_YEAR
    nDays=d/SECS_IN_DAY
    d=d%SECS_IN_DAY
    nHours=d/SECS_IN_HOUR
    d=d%SECS_IN_HOUR
    nMins=d/SECS_IN_MIN
    d=d%SECS_IN_MIN
    
    str=''
    str+="#{nYears} years " if nYears>0
    str+="#{nDays} days " if nDays>0
    str+="#{nHours} hours " if nHours>0
    str+="#{nMins} mins " if nMins>0
    str+="#{d.to_i} secs"
    str
  end

  def since(t0)
    Time.timespan(self,t0)
  end
end


def main
  org=:human
  n_chrs={:human=>22, :mouse=>19}[org]
  label='sample_412_fcl_585'
  timepoints=[[Time.now,'start']]

  # crude flow control:
  run_fq_all2std=    false

  $run_blat_rna_all=  false
  $call_store_hits=  false
  $call_filter_hits= false

  run_blat=          false
  run_pslReps=       false      # always false for now
  run_pslSort=       false
  run_makerds=       true

  # initialization:
  blat='/package/genome/bin/blat'
  genomes="/jdrf/data_var/solexa/genomes/#{org}/fasta"
  readlen=75
  maxMismatches=2
  minScore=readlen-maxMismatches
  blat_opts="-ooc=#{genomes}/11.ooc -out=pslx -minScore=#{minScore}"
  working_dir='/solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_412/10K'
  export_file='s_1_export.10K.txt'
  psl_ext='psl'
#  bin_dir='/tools/bin'
  bin_dir='/hpc/bin'
  perl="#{bin_dir}/perl"
  python="#{bin_dir}/python"
  db="#{working_dir}/rds/#{export_file}.sqlite"
  blat_output="#{working_dir}/#{export_file}.#{psl_ext}"
  fq_output="#{working_dir}/#{export_file}.fa"

  # build chr array; can't believe there's not a better way to convert a range to an array:
  chrs=Array.new
  (1..n_chrs).each {|i| chrs<<i}
  chrs<<'X'
  chrs<<'Y'

  # main processing starts here:
  fq_output=run_fq_all2std(working_dir,export_file,perl) if run_fq_all2std
  timepoints<<[Time.now,'fq_output']
  if $run_blat_rna_all
    blat_result=run_blat_rna(working_dir,export_file,genomes,blat,fq_output) 
    timepoints<<[Time.now,'fq_output']
    table=store_hits(working_dir,export_file,blat_result,db,readlen) 
    timepoints<<[Time.now,'store_hits']
    fq_output=filter_hits(working_dir,fq_output,db,table) 
    timepoints<<[Time.now,'filter_hits']
  end
  run_blat(fq_output,working_dir,export_file,psl_ext,blat,genomes,blat_opts,chrs,minScore,maxMismatches) if run_blat
  timepoints<<[Time.now,'run_blat']
  run_pslReps(working_dir,export_file) if run_pslReps
  timepoints<<[Time.now,'pslReps']
  run_pslSort(working_dir,blat_output) if run_pslSort
  timepoints<<[Time.now,'pslSort']
  run_makerds(working_dir,export_file,genomes,python,label,blat_output) if run_makerds
  timepoints<<[Time.now,'run_makerds']

  time_report(timepoints)
end

########################################################################
# run fq_all2std:
def run_fq_all2std(working_dir,export_file,perl)
  fq_all2std='/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/fq_all2std.pl'
  fq_input="#{working_dir}/../#{export_file}"
  fq_output="#{working_dir}/#{export_file}.fa"
  cmd="#{perl} #{fq_all2std} solexa2fasta #{fq_input} >#{fq_output}"
  puts "\n#{cmd}\n"
  
  ok=system cmd
  raise "\nblat: #{cmd}: $? is #{$?}" unless ok
  fq_output
end

########################################################################
# run blat against the rna.fa file:
# doesn't run if #{export_file}.rna.psl exists
def run_blat_rna(working_dir,export_file,genomes,blat,fq_output)
  rna_genome="#{genomes}/rna.fa"
  rna_output="#{working_dir}/#{export_file}.rna.psl"
  return rna_output if File.exists? rna_output and not $run_blat_rna_all # fixme: might need a separate global flag?
  cmd="#{blat} #{rna_genome} #{fq_output} -out=pslx #{rna_output}"
  puts "\n#{cmd}\n"
  ok=system cmd
  raise "\nblat_rna: #{cmd}: $? is #{$?}" unless ok
  rna_output
end


########################################################################
# run blat against all chrs using each .nib file:
def run_blat(fq_output,working_dir,export_file,psl_ext,blat,genomes,blat_opts,chrs,min_score,max_mismatch)
  chrs.each {|chr|
    blat_chr_output="#{working_dir}/#{export_file}.#{chr}.#{psl_ext}"
    cmd="#{blat} #{genomes}/chr#{chr}.nib #{fq_output} #{blat_opts} #{blat_chr_output}"
    puts "\n#{cmd}\n"

    ok=system cmd
    raise "\nblat: #{cmd}: $? is #{$?}" unless ok

    filter_minScore(blat_chr_output,min_score,max_mismatch)
  }
end

########################################################################
# filter repeats
#$BLATPATH/pslReps -minNearTopSize=70 s3_1.hg18.blat s3_1.hg18.blatbetter s3_1.blatpsr
def run_pslReps(working_dir,export_file)
  raise "pslReps nyi"
  pslReps='/package/genome/bin/pslReps'
  pslOpts='-minNearTopSize=70'
  pslreps_output="#{working_dir}/#{export_file}.pslreps"

  cmd="#{pslReps} #{pslOpts} "
end

########################################################################
# concat and sort blat results
# pslSort dirs[1|2] outFile tempDir inDir(s)
def run_pslSort(working_dir,blat_output)

  pslSort='/package/genome/bin/pslSort'

  FileUtils.rm blat_output if FileTest.exists? blat_output
  cmd="#{pslSort} dirs #{blat_output} #{working_dir}/tmp #{working_dir}"
  puts "\n#{cmd}\n"
  ok=system cmd
  raise "#{cmd}: $? is #{$?}" unless ok
end



########################################################################
# remove all hits below minScore (since I can't seem to get blat to do
# that for me :( 
def filter_minScore(blat_result, min_score, max_mismatch)
  tmp_filename="#{blat_result}.tmp"
  tmp_file=File.open(tmp_filename,"w")
  File.open(blat_result,"r").each do |l|
    stuff=l.split
    next if stuff[0].to_i<min_score
    next if stuff[1].to_i>max_mismatch
    tmp_file.puts l 
  end

  FileUtils.mv(tmp_filename,blat_result)
  
end

########################################################################
# use makerdsfromblat.py to, make the rds db from the blat results:
def run_makerds(working_dir,export_file,genomes,python,label,blat_output)
  makerds="/proj/hoodlab/share/vcassen/rna-seq/commoncode/makerdsfromblat.py"
  outrdsfile="#{working_dir}/rds/#{export_file}.rds"
  FileUtils.rm outrdsfile if FileTest.exists? outrdsfile
  options="-forceRNA -index -cache 1000 -rawreadID -RNA #{genomes}/knownGene.txt"

  cmd="#{python} #{makerds} #{label} #{blat_output} #{outrdsfile} #{options}"
  puts cmd
  ok=system cmd
  raise "#{cmd}: $? is #{$?}" unless ok
end

# remove all the hits found in #{blat_result} from #{export_file}, using the tmp db #{db}
# Steps:
# 1. insert all uniq seqs in blat_result (corrected for mismatches) into db
def store_hits(working_dir,export_file,blat_result,db,readlen)
  dbh=SQLite3::Database.new(db)
  table=File.basename(export_file.clone) # have to clone export_file because otherwise it gets changed with gsub! below
  table.gsub!(/\./, '_')
  return table unless $call_store_hits
  puts "store_hits: storing hits in #{blat_result} into #{table}"
  dbh.execute("DROP TABLE IF EXISTS #{table}")
  dbh.execute("CREATE TABLE #{table} (seq CHAR(#{readlen}) PRIMARY KEY)")
  puts "#{table}: shazam!"

  # insert the blat results into the db
  n_insertions=0
  puts "blat_result is #{blat_result}"
  File.open(blat_result).each do |l|
    stuff=l.split
    read=stuff[21]; next if read.nil?
    read.sub!(/,$/, '')
    strand=stuff[8]
    match=stuff[0]
    next if read.length!=readlen
    next if match.to_i<readlen-2     # fixme: set to max_mismatches or something
    #    read=rev_comp(read) if strand=='-'
#    a=[read, read.reverse, complement(read), complement(read).reverse]
    a=[read]
    a.each do |s|
      begin
        rows=dbh.query("SELECT COUNT(*) FROM #{table} WHERE seq='#{s}'").next
        next if rows[0].to_i>0    # I'm liking sqlite3 less and less
        dbh.execute("INSERT INTO #{table} (seq) VALUES ('#{s}')")
        n_insertions+=1
      rescue Exception => e
        puts "#{s}: #{e.message}"
      end
    end
  end

  puts "#{n_insertions} reads stored to #{table}"
  table
end

# 2. filter export_file, looking up each result in db and omitting it from output if found.
# returns name of reads fastafile with all rna seqs removed (suffix='.no_rna.fa')
def filter_hits(working_dir,fq_output,db,table)
  dbh=SQLite3::Database.new(db)

  outfile=File.replace_ext("#{fq_output}","no_rna.fa")
  return outfile unless $call_filter_hits
  puts "filter_hits: writing to #{outfile}"
  out=File.open(outfile,"w")
  n_read=n_written=0
  header=''
  File.open("#{fq_output}").each do |l|
    if l.match('^>')
      header=l
      next
    end
    read=l.chomp.downcase
    if read.match(/^[acgtn]+$/)
      n_read+=1
    else
      raise "bad read?: '#{read}'"
    end

    row=dbh.query("SELECT count(seq) FROM #{table} WHERE seq='#{read}'").next # gets first
    if row[0].to_i==0            # if found, we want to OMIT it from the new .fa file
      out.puts header
      out.puts l 
      n_written+=1
#      puts "didn't find '#{read}', retaining" 
    else
#      puts "found '#{read}'"
    end
  end

  out.close
  printf "#{n_read} read, #{n_written} written (%5.2f%%)\n", n_written.to_f/n_read.to_f*100.0
  outfile
end


def complement(s)
  s.tr 'acgtACGT','tgcaTGCA'
end

def time_report(timepoints)
  begin
    last_tp=timepoints.shift
    start=last_tp
    timepoints.each do |tp|
      puts "#{last_tp[1]} to #{tp[1]}: #{last_tp[0].since(tp[0])}"
      last_tp=tp
    end

    last=timepoints.pop
    puts "#{start[1]} to #{last[1]} (total): #{start[0].since(last[0])}"
  rescue Exception => e
    puts "Error in time_report: #{e.message}"
  end
end



main()
