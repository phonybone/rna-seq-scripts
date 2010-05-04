#!/hpc/bin/ruby

# This is the main rnaseq_pipeline script.

require 'rubygems'
require 'sqlite3'
require 'fileutils'
require 'yaml'

#$:<<'/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/lib'
$:<<"#{File.dirname(__FILE__)}/lib"
require 'local_utils.rb'
require 'options'
require 'app_config'

def parse_cmdline()
  all_opts=%w{working_dir=s export_file=s label=s pp_id=i org=s readlen=i max_mismatches=i align_params=s
   dry_run erccs rnaseq_dir=s script_dir=s bin_dir=s min_score=i ref_genome=s user=s
   run_export2fasta  run_align  run_makerds  run_erange  run_erccs  run_stats  run_pslReps  run_pslSort
   run_blat_rna_all call_store_hits call_filter_hits}
  
  Options.use(all_opts)
  
  config_file=File.replace_ext(__FILE__,'conf')
  conf=YAML.load_config config_file
  Options.use_defaults conf
  Options.use_defaults(:user=>'solexatrans')

  Options.required(%w{working_dir export_file label pp_id org readlen max_mismatches rnaseq_dir script_dir})
  Options.parse()
#  puts Options.all.inspect
end



# config globals:
def config_globals
  $working_dir=Options.working_dir
  $export_file=Options.export_file
  script_dir=Options.script_dir
  $timepoints=[[Time.now,'starting']]
  rnaseq_dir=Options.rnaseq_dir
  $export_filepath="#{$working_dir}/#{Options.export_file}"
  $post_slimseq="#{script_dir}/post_to_slimseq.pl"
  $export2fasta="#{script_dir}/fq_all2std.pl"
  $bowtie_exe="#{rnaseq_dir}/bowtie/bowtie"
  $blat_exe='/package/genome/bin/blat'
  $erange_dir="#{rnaseq_dir}/commoncode"
  $rds_dir="#{$working_dir}/rds"
  $erange_script="#{rnaseq_dir}/commoncode/runStandardAnalysisNFS.sh"
  align=Options.readlen >= 50 ? 'blat' : 'bowtie'
  $makerds_script="#{rnaseq_dir}/commoncode/makerdsfrom#{align}.py"
  $stats_script="#{script_dir}/gather_stats.pl"
  $bowtie2count="#{script_dir}/bowtie2count.ercc.pl"
  $normalize_erccs="#{script_dir}/normalize_erccs.pl"
  $genomes_dir='/jdrf/data_var/solexa/genomes'
  $perl="#{Options.bin_dir}/perl"
  $python="#{Options.bin_dir}/python"
  $psl_ext='psl'
  $blat_output="#{$working_dir}/#{$export_file}.#{$psl_ext}"
  $bowtie_output="#{$working_dir}/#{$export_file}.#{fasta_format()}.bowtie.out"
  $pslSort='/package/genome/bin/pslSort'
  $pslReps='/package/genome/bin/pslReps'

  $config_file='/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/config/rnaseq.conf'
  AppConfig.load($config_file,'default')

  ENV['ERANGEPATH']=$erange_dir
  ENV['CISTEMATIC_ROOT']="#{$genomes_dir}/mouse" # even for human???
  ENV['PYTHONPATH']=rnaseq_dir
  ENV['BOWTIE_INDEXES']="#{$genomes_dir}/#{Options.org}"
  ENV['CISTEMATIC_TEMP']="#{rnaseq_dir}/tmp"
end

def main
  exit_code=0
  end_message='Finished'
  puts "Started at #{Time.now}"
  parse_cmdline()
  config_globals()

  begin
    touch_lock()
    post_status(Options.pp_id,'Starting') # Can't do this until we've parsed options, assigned globals
    integrity_checks()
    mk_working_dir()

    export2fasta(fasta_format())             if Options.run_export2fasta
    align(fasta_format())                    if Options.run_align
    makerds()                                if Options.run_makerds
    call_erange()                            if Options.run_erange
    stats()                                  if Options.run_stats
    erccs()                                  if Options.run_erange
    stats2()                                 if Options.run_stats
  rescue Exception => e
    puts "Caught exception: #{e.message}"
    exit_code=1
    end_message='Failed'
  end

  post_status(Options.pp_id,end_message)
  $timepoints<<[Time.now,'done']
  report_times()
  rm_lock()
  exit exit_code
end


def touch_lock
  lock_file="#{$working_dir}/lock.file"
  system("touch #{lock_file}")
  system("touch #{$working_dir}/last.run")
end

def rm_lock
  lock_file="#{$working_dir}/lock.file"
  system("rm -f #{lock_file}")
end

def integrity_checks
  messages=Array.new

  readables=[$export_filepath, $config_file]
  readables.each do |file|
    messages << "#{file}: no such file or unreadable"  unless FileTest.readable? file
  end

  org=Options.org.downcase
  messages << "Unknown org '#{org}'" unless org=='mouse' or org=='human'

  # also need to test executable scripts, maybe write access to working_dir
  exes=[$post_slimseq,
        $export2fasta,
        $bowtie_exe,
        $bowtie2count,
        $makerds_script,
        $erange_script,
        $stats_script,
        $bowtie2count,
        $pslSort,
        $pslReps,
        $normalize_erccs]
  exes.each do |exe|
    messages << "#{exe}: not found or not executable" unless FileTest.executable? exe
  end
  if messages.length > 0
    puts messages.join("\n")
    exit 1
  end
  $stderr.puts 'integrity checks passed'
end

def mk_working_dir()
  FileUtils.mkdir $working_dir unless FileTest.directory? $working_dir
  FileUtils.mkdir "#{$working_dir}/rds" unless FileTest.directory? "#{$working_dir}/rds"
  FileUtils.chmod 0777, $working_dir
  FileUtils.chmod 0777, "#{$working_dir}/rds"

  FileUtils.cd $working_dir
  puts <<"BANNER"
*****************************************************
writing output to:
#{$working_dir}
*****************************************************
   
BANNER
  
end

########################################################################
## translate export.txt file to fasta format

def export2fasta(fasta_format)
  post_status(Options.pp_id,'extracting reads from ELAND file')
  $timepoints<<[Time.now,'export2fasta starting']
  trans_type=fasta_format=='blat' ? 'solexa2fasta' : 'solexa2fastaq'
  translation_cmd="#{$perl} #{$export2fasta} #{trans_type} #{$working_dir}/#{$export_file}"
  puts "translation cmd: #{translation_cmd} > #{$working_dir}/#{$export_file}.#{fasta_format}"

  # unlink converted export file if it exists (so that redirection, below, won't fail)
  if (FileTest.readable?("#{$working_dir}/#{$export_file}.#{fasta_format}") and !Options.dry_run) then
    FileUtils.remove "#{$working_dir}/#{$export_file}.#{fasta_format}"
  end

  launch("#{translation_cmd} > #{$working_dir}/#{$export_file}.#{fasta_format}")

# this writes #{$working_dir}/#{$export_file}.#{fasta_format}
end

########################################################################
def align(fasta_format)
  if aligner()=='blat'
    return blat()
  else
    return bowtie()
  end
end

########################################################################
## bowtie-cmd.sh:
## Note: bowtie needs .ewbt files to work from; don"t exist yet for critters other than mouse

def bowtie()
  fasta_format=fasta_format()
  $timepoints<<[Time.now,'bowtie starting']
  reads_file="#{$working_dir}/#{$export_file}.#{fasta_format}"	# export file converted to fasta format
  max_mismatches=Options.max_mismatches
  ref_genome=Options.ref_genome
  bowtie_opts=Options.align_params

  repeats="#{reads_file}.repeats.#{fasta_format}"
  unmapped="#{reads_file}.unmapped.#{fasta_format}"

  alignment_cmd="#{$bowtie_exe} #{ref_genome} -n #{max_mismatches} #{bowtie_opts} #{reads_file} --un #{unmapped} --max #{repeats} #{$bowtie_output}"

  # reads_file is the input

  puts "alignment cmd: #{alignment_cmd}"
  post_status(Options.pp_id, 'aligning reads (bowtie)')
  launch alignment_cmd

  puts "#{$bowtie_output} written"
  puts ""
end

#-----------------------------------------------------------------------

def blat()
  $timepoints<<[Time.now,'blat starting']
  org=Options.org.downcase
  label=Options.label
  $timepoints<<[Time.now,'starting blat']

  # initialization:
  blat=AppConfig.blat
  genomes="#{$genomes_dir}/#{org}/fasta"

  readlen=Options.readlen
  maxMismatches=Options.max_mismatches
  minScore=readlen-maxMismatches
  Options.min_score=minScore    # really? are you sure you want to set this here???
  blat_opts="-ooc=#{genomes}/11.ooc -out=pslx -minScore=#{minScore}"

  rna_db="#{$working_dir}/rds/#{$export_file}.rna"
  reads_fasta="#{$working_dir}/#{$export_file}.fa" # has to be a .fa format, not .faq (I think)

  # main processing starts here:
  if Options.run_blat_rna_all
    blat_result=blat_rna(blat,reads_fasta) 
    $timepoints<<[Time.now,'rna_reads_fasta']
    table=store_hits(blat_result,rna_db,readlen) 
    $timepoints<<[Time.now,'rna store_hits']
    reads_fasta=filter_hits(reads_fasta,rna_db,table) # overwrite name of reads file
    $timepoints<<[Time.now,'rna filter_hits']
  end
  blat_chrs(reads_fasta,blat,genomes,blat_opts) 
  $timepoints<<[Time.now,'blat_chrs']
  pslReps() if Options.run_pslReps
  $timepoints<<[Time.now,'pslReps']
  pslSort() if Options.run_pslSort
  $timepoints<<[Time.now,'pslSort']

end

#-----------------------------------------------------------------------
# run blat against the rna.fa file:
def blat_rna(blat,reads_fasta)
  $timepoints<<[Time.now,'blat_rna starting']

  rna_genome="#{$genomes_dir}/#{Options.org}/fasta/rna.fa"
  rna_output="#{$working_dir}/#{$export_file}.rna.psl"
  rna_blat_opts="-out=pslx -minScore=#{Options.min_score}"

  cmd="#{blat} #{rna_genome} #{reads_fasta} #{rna_blat_opts} #{rna_output}"
  puts "\n#{cmd}\n"
  launch cmd

  filter_minScore(rna_output)
  rna_output
end

#-----------------------------------------------------------------------
# run blat against all chrs using each .nib file:
def blat_chrs(reads_fasta,blat,genomes,blat_opts)
  # build chr array; can't believe there's not a better way to convert a range to an array:
  org=Options.org.downcase.to_sym
  n_chrs={:human=>22, :mouse=>19}[org]

  chrs=Array.new
  (1..n_chrs).each {|i| chrs<<i}
  chrs<<'X'
  chrs<<'Y'

  chrs.each {|chr|
    $timepoints<<[Time.now,"blat chr #{chr} starting"]
    blat_chr_output="#{$working_dir}/#{$export_file}.#{chr}.#{$psl_ext}"
    cmd="#{blat} #{genomes}/chr#{chr}.nib #{reads_fasta} #{blat_opts} #{blat_chr_output}"
    puts "\n#{cmd}\n"

    launch cmd
    filter_minScore(blat_chr_output)
  }
end


#-----------------------------------------------------------------------
# remove all hits below minScore (since I can't seem to get blat to do
# that for me :( 
def filter_minScore(blat_result)
  return if Options.dry_run
  tmp_filename="#{blat_result}.tmp"
  tmp_file=File.open(tmp_filename,"w")
  File.open(blat_result,"r").each do |l|
    stuff=l.split
    next if stuff[0].to_i<Options.min_score
    next if stuff[1].to_i>Options.max_mismatches
    tmp_file.puts l 
  end

  FileUtils.mv(tmp_filename,blat_result)
  blat_result
end

#-----------------------------------------------------------------------
# concat and sort blat results
# pslSort dirs[1|2] outFile tempDir inDir(s)
def pslSort()
  $timepoints<<[Time.now,'pslSort starting']
  FileUtils.rm $blat_output if FileTest.exists? $blat_output
  cmd="#{$pslSort} dirs #{$blat_output} #{$working_dir}/tmp #{$working_dir}"
  puts "\n#{cmd}\n"
  launch cmd
end

#-----------------------------------------------------------------------
# filter repeats
#$BLATPATH/pslReps -minNearTopSize=70 s3_1.hg18.blat s3_1.hg18.blatbetter s3_1.blatpsr
def run_pslReps()
  raise "pslReps nyi"
  pslOpts='-minNearTopSize=70'
  pslreps_output="#{$working_dir}/#{$export_file}.pslreps"

  cmd="#{$pslReps} #{pslOpts} #{pslreps_output}"
end

#-----------------------------------------------------------------------
# remove all the hits found in #{blat_result} from #{export_file}, using the tmp db #{db}
# Steps:
# 1. insert all uniq seqs in blat_result (corrected for mismatches) into db
def store_hits(blat_result,db,readlen)
  dbh=SQLite3::Database.new(db)
  table=File.basename($export_file.clone) # have to clone export_file because otherwise it gets changed with gsub! below
  table.gsub!(/\./, '_')
  return table unless Options.call_store_hits || Options.dry_run
  puts "store_hits: storing hits in #{blat_result} into #{table}"
  dbh.execute("DROP TABLE IF EXISTS #{table}")
  dbh.execute("CREATE TABLE #{table} (seq CHAR(#{readlen}) PRIMARY KEY)")
  puts "#{table}: shazam!"

  # insert the blat results into the db
  n_insertions=0

  dbh.execute('PRAGMA synchronous=OFF')
  dbh.execute('PRAGMA cache_size=20000')
  dbh.execute('BEGIN TRANSACTION')
  File.open(blat_result).each do |l|
    stuff=l.split
    read=stuff[21]; next if read.nil?
    read.sub!(/,$/, '')
    strand=stuff[8]
    match=stuff[0]
    next if read.length != readlen
    next if match.to_i < readlen-Options.max_mismatches
    begin
      rows=dbh.query("SELECT COUNT(*) FROM #{table} WHERE seq='#{read}'").next
      next if rows[0].to_i>0    # I'm liking sqlite3 less and less
      dbh.execute("INSERT INTO #{table} (seq) VALUES ('#{read}')")
      n_insertions+=1
    rescue Exception => e
      puts "#{read}: #{e.message}"
    end
  end

  dbh.execute('END TRANSACTION')

  puts "#{n_insertions} reads stored to #{table}"
  table
end

#-----------------------------------------------------------------------
# 2. filter export_file, looking up each result in db and omitting it from output if found.
# returns name of reads fastafile with all rna seqs removed (suffix='.no_rna.fa')
def filter_hits(fq_output,db,table)
  dbh=SQLite3::Database.new(db)

  outfile=File.replace_ext("#{fq_output}","no_rna.fa")
  return outfile unless Options.call_filter_hits || Options.dry_run # wtf??? fixme
  return outfile if Options.dry_run # fixme here, too
  puts "filter_hits: writing to #{outfile}"
  out=File.open(outfile,"w")
  n_read=n_written=0
  header=''
  dbh.execute('PRAGMA synchronous=OFF')
  dbh.execute('PRAGMA cache_size=20000')
  dbh.execute('BEGIN TRANSACTION')
  File.open(fq_output).each do |l|
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
  dbh.execute('END TRANSACTION')

  out.close
  printf "#{n_read} read, #{n_written} written (%5.2f%%)\n", n_written.to_f/n_read.to_f*100.0
  outfile
end


#check
########################################################################
## makeRdsFromBowtie-cmd.sh:

# due to an apparent bug in makerdsfrombowtie.py, we need to rm rds_output
# if it exists.  The bug (actually in commoncode.py) is that it uses the 
# sql "create table if not exists <tablename>", without dropping the table/db
# first.  The effect is that the tables get appended to, not re-written.

def makerds()
  post_status(Options.pp_id,'Creating RDS files from alignment')
  $timepoints<<[Time.now,'makerds starting']

  alignment_output= aligner()=='blat' ? $blat_output : $bowtie_output
  rds_output="#{$rds_dir}/#{$export_file}.rds"
  FileUtils.remove rds_output if FileTest.readable? rds_output and !Options.dry_run
  org=Options.org.downcase
  rds_opts= "-forceRNA -index -cache 1000 -rawreadID -RNA #{$genomes_dir}/#{org}/knownGene.txt"

  makerds_cmd="#{$python} #{$makerds_script} #{Options.label} #{alignment_output} #{rds_output} #{rds_opts}"
  launch(makerds_cmd)
  puts "#{rds_output} written"
end


########################################################################
## runStandardAnalysisNFS-cmd.sh:

def call_erange
  $timepoints<<[Time.now,'erange starting']
  post_status(Options.pp_id,'running ERANGE')
  $stderr.puts "CISTEMATIC_ROOT is #{ENV['CISTEMATIC_ROOT']}"
  cmd="time sh #{$erange_script}  #{Options.org.downcase} #{$rds_dir}/#{$export_file} #{$genomes_dir}/#{Options.org.downcase}/repeats_mask.db 5000"
  launch cmd
end

########################################################################
# gather stats:

def stats
  stats_file="#{$working_dir}/#{$export_file}.stats"
  stats_cmd="#{$perl} #{$stats_script} -working_dir #{$working_dir} -export #{$export_file} -job_name #{Options.label}"
  final_rpkm_file="#{$rds_dir}/#{$export_file}.final.rpkm"

  puts 'gathering stats...'
  post_status(Options.pp_id,'generating stats')

  launch(stats_cmd)
end


# ERCC section copied from ~vcassen/software/Solexa/RNA-seq/ERCC/ercc_pipeline.qsub
def erccs
  if Options.erccs
    $timepoints<<[Time.now,'erccs starting']
    ########################################################################
    # count ERCC alignments, utilizing original counts:
    
    ercc_counts="#{$working_dir}/#{$export_file}.ercc.counts" # output 
    count_erccs_cmd="#{$perl} #{$bowtie2count} #{alignment_output} > #{ercc_counts}"
    normalize_cmd="#{$perl} #{$normalize_erccs} -alignment_output #{alignment_output} -force" # fixme: need total_aligned_reads from script...
    
    raise "#{alignment_output} unreadable" unless FileTest.readable? alignment_output
    
    launch(count_erccs_cmd)
    puts "count_erccs: status is #{$?}"        # fixme
    exit $? if $?.to_i>0
    puts "#{ercc_counts} written"
    
    ########################################################################
    # get total aligned reads from the stats file:
    
    File.open(stats_file).each do |l|
      break if (total_aligned_reads=l.match(/(\d+) total aligned reads/).to_i > 0) 
    end
    puts "total_aligned_reads: #{total_aligned_reads}"
    
    
    ########################################################################
    # normalize read counts:
    # writes to #{alignment_output}.normalized (sorta; removes old suffix first, ie, "out"->"normalized").
    puts "normalize cmd: #{normalize_cmd}"
    launch("#{normalize_cmd} -total_aligned_reads #{total_aligned_reads}")
    
  end				# end ERCC section
end

########################################################################
## Stats2:

def stats2
  final_rpkm_file="#{$rds_dir}/#{$export_file}.final.rpkm"
  stats_file="#{$working_dir}/#{$export_file}.stats"
  n_genes=`wc -l #{final_rpkm_file}`.split(/\s+/)[0]
  stats=File.open(stats_file,'a')
  stats.puts "number of genes observed: #{n_genes}"
  stats.close

  # update slimseq with stats file and status:
end


########################################################################
def launch(cmd) 
  puts "\n#{cmd}"
  unless Options.dry_run
    success=system cmd
    raise "**************\n\nFAILED\n********\n\n: $? is #{$?}" unless success
  end
end

def post_status(pp_id, status)
  return if pp_id.nil? or pp_id.to_i<=0
  launch("#{$perl} #{$post_slimseq} -type post_pipelines -id #{pp_id} -field status -value '#{status}'")
end

########################################################################
def aligner
  Options.readlen>=50 ? 'blat':'bowtie'
end

def fasta_format
  Options.readlen>=50 ? 'fa':'faq'
end


########################################################################

def complement(s)
  s.tr 'acgtACGT','tgcaTGCA'
end

########################################################################
def report_times()
  begin
    last_tp=$timepoints.shift
    start=last_tp
    $timepoints.each do |tp|
      puts "#{last_tp[1]} to #{tp[1]}: #{last_tp[0].since(tp[0])}"
      last_tp=tp
    end

    last=$timepoints.pop
    puts "#{start[1]} to #{last[1]} (total): #{start[0].since(last[0])}"
  rescue Exception => e
    puts "Error in report_times: #{e.message}"
  end
  puts "report written at #{Time.now}"
end

########################################################################



main()
