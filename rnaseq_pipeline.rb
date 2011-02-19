#!/hpc/bin/ruby

# This is the main rnaseq_pipeline script.

require 'rubygems'
require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'action_mailer'

#$:<<'/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/lib'
$:<<"#{File.dirname(__FILE__)}/lib"
require 'local_utils.rb'
require 'options'
require 'app_config'

def parse_cmdline()
  all_opts=%w{working_dir=s export_file=s export_file2 label=s pp_id=i org=s readlen=i max_mismatches=i align_params=s
   dry_run erccs rnaseq_dir=s script_dir=s bin_dir=s genomes_dir min_score=i ref_genome=s user=s
   run_export2fasta  run_align  run_makerds  run_erange  run_erccs  run_stats  run_pslReps  run_pslSort}
  
  Options.use(all_opts)
  
  config_file=File.replace_ext(__FILE__,'conf')
  conf=YAML.load_config config_file
  Options.use_defaults conf

  Options.required(%w{working_dir export_file label org readlen max_mismatches rnaseq_dir script_dir})
# Options.required(%w{working_dir export_file label org readlen max_mismatches rnaseq_dir script_dir pp_id})
  Options.parse()
end



# config globals:
def config_globals
  $working_dir=Options.working_dir
  $export_file=Options.export_file
  $export_file2=Options.export_file2
  script_dir=Options.script_dir
  $timepoints=[[Time.now,'starting']]
  rnaseq_dir=Options.rnaseq_dir
  $export_filepath="#{$working_dir}/#{Options.export_file}"
  $post_slimseq="#{script_dir}/post_to_slimseq.pl"
  $export2fasta="#{script_dir}/fq_all2std.pl"
  $bowtie_exe="#{rnaseq_dir}/bowtie/bowtie"
  $erange_dir="#{rnaseq_dir}/commoncode"
  $rds_dir="#{$working_dir}/rds"
  $erange_script="#{rnaseq_dir}/commoncode/runStandardAnalysisNFS.sh"
  align='bowtie'
  $makerds_script="#{rnaseq_dir}/commoncode/makerdsfrom#{align}.py"
  $stats_script="#{script_dir}/gather_stats.pl"
  $bowtie2count="#{script_dir}/bowtie2count.ercc.pl"
  $normalize_erccs="#{script_dir}/normalize_erccs.pl"
  $genomes_dir='/jdrf/data_var/solexa/genomes'
  $perl="#{Options.bin_dir}/perl"
  $python="#{Options.bin_dir}/python"
  $psl_ext='psl'
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

    # steps:
    if Options.run_export2fasta
      export2fasta(fasta_format(), $export_file)
      export2fasta(fasta_format(), $export_file2) unless $export_file2.nil?
    end
    align(fasta_format())                    if Options.run_align
    makerds()                                if Options.run_makerds
    call_erange()                            if Options.run_erange
    stats()                                  if Options.run_stats
    erccs()                                  if Options.run_erange
    stats2()                                 if Options.run_stats

  rescue Exception => e
    puts "Caught exception (#{e.class}): #{e.message}"
    puts e.backtrace
    exit_code=1
    end_message='Failed'

    report_to_mothership(e)
  end

  post_status(Options.pp_id,end_message)
  $timepoints<<[Time.now,'done']
  report_times()
  rm_lock()
  exit exit_code
end


def touch_lock
  begin
    lock_file="#{$working_dir}/lock.file"
    system("touch #{lock_file}")
    FileUtils.chmod 0777, lock_file
    system("touch #{$working_dir}/last.run")
    FileUtils.chmod 0777, "#{$working_dir}/last.run"
  rescue Exception => rt
    $stderr.puts rt.message
  end
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
## might have to do it twice if paired end
def export2fasta(fasta_format, export_file)
  post_status(Options.pp_id,'extracting reads from ELAND file')
  $timepoints<<[Time.now,'export2fasta starting']

  trans_type='solexa2fastq'    # could change this... fixme
  translation_cmd="#{$perl} #{$export2fasta} #{trans_type} #{$working_dir}/#{export_file}"
  puts "translation cmd: #{translation_cmd} > #{$working_dir}/#{export_file}.#{fasta_format}"

  # unlink converted export file if it exists (so that redirection, below, won't fail)
  if (FileTest.readable?("#{$working_dir}/#{export_file}.#{fasta_format}") and !Options.dry_run) then
    FileUtils.remove "#{$working_dir}/#{export_file}.#{fasta_format}"
  end

  launch("#{translation_cmd} > #{$working_dir}/#{export_file}.#{fasta_format}")

# this writes #{$working_dir}/#{export_file}.#{fasta_format}
end

########################################################################
def align(fasta_format)
  return bowtie()
end

########################################################################
## bowtie-cmd.sh:
## Note: bowtie needs .ewbt files to work from
## Paired end, color space; what is the best way to specify various options/cmds
## Hard-coding one function per parameter set seems (is) stupid;
## 
## Bowtie Usage:
##
##  bowtie [options]* <ebwt> {-1 <m1> -2 <m2> | --12 <r> | <s>} [<hit(output)>]
##

def bowtie()
  fasta_format=fasta_format()
  $timepoints<<[Time.now,'bowtie starting']
  if ($export_file2.nil?) then
    reads_file="#{$working_dir}/#{$export_file}.#{fasta_format}"	# export file converted to fasta format
  else 
    # paired end alignment
    reads_file="-1 #{$working_dir}/#{$export_file}.#{fasta_format} -2  #{$working_dir}/#{$export_file2}.#{fasta_format}"
  end
  max_mismatches=Options.max_mismatches
  ref_genome=Options.ref_genome
  bowtie_opts=Options.align_params

  repeats="#{reads_file}.repeats.#{fasta_format}"
  unmapped="#{reads_file}.unmapped.#{fasta_format}"

  alignment_cmd="#{$bowtie_exe} #{ref_genome} #{bowtie_opts} #{reads_file} --un #{unmapped} --max #{repeats} #{$bowtie_output}"

  # reads_file is the input

  puts "alignment cmd: #{alignment_cmd}"
  post_status(Options.pp_id, 'aligning reads (bowtie)')
  launch alignment_cmd

  puts "#{$bowtie_output} written"
  puts ""
end




########################################################################
## makeRdsFromBowtie-cmd.sh:

# due to an apparent bug in makerdsfrombowtie.py, we need to rm rds_output
# if it exists.  The bug (actually in commoncode.py) is that it uses the 
# sql "create table if not exists <tablename>", without dropping the table/db
# first.  The effect is that the tables get appended to, not re-written.

def makerds()
  post_status(Options.pp_id,'Creating RDS files from alignment')
  $timepoints<<[Time.now,'makerds starting']

#  alignment_output= aligner()=='blat' ? $blat_output : $bowtie_output
  alignment_output=$bowtie_output
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
    puts "count_erccs: status is #{$?}"        
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
  $stderr.puts "\n#{cmd}"
  unless Options.dry_run
    success=system cmd
    raise "**************\n\nFAILED\n********\n\n: $? is #{$?}" unless success
  end
end

def post_status(pp_id, status)
  return if pp_id.nil? or pp_id.to_i<=0
  cmd="#{$perl} #{$post_slimseq} -type rnaseq_pipelines -id #{pp_id} -field status -value '#{status}'"
  begin
    launch(cmd)
  rescue Exception=>e
    $stderr.puts "Error in '#{cmd}:"
    $stderr.puts "#{e.class}: #{e.message}"
  end
end

########################################################################
def aligner
  return 'bowtie'
#  Options.readlen>=50 ? 'blat':'bowtie'
end

def fasta_format
#  Options.readlen>=50 ? 'fa':'faq'
  'faq'
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

def report_to_mothership(e)
  return unless e.is_a?(Exception)
  begin
    require 'mail'
    msg=<<"MSG"
#{e.message}
#{e.traceback}

#{Options.all}
MSG
    mail = Mail.new do
      from 'vcassen@systemsbiology.net'
      to 'vcassen@systemsbiology.net+rnaseq_pipeline'
      subject e.message
      body msg
    end
    mail.deliver!
    
  rescue Exception=>e
    # not much we can do, maybe log it
  end
end


########################################################################



main()
