require 'yaml'

$: << File.expand_path(File.dirname(__FILE__)+"/lib")
$: << '/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/lib'
require 'options'

def main
  parse_options()
  environment_check()
  launch()
end


# Global vars:
# have to keep this sync'd with rnaseq_pipeline; ugh
$rnaseq_full_opts=%w{working_dir=s export_file=s label=s pp_id=i org=s readlen=i max_mismatches=i align_params=s ref_genome=s
   dry_run erccs rnaseq_dir=s script_dir=s bin_dir=s genomes_dir=s min_score=i ref_genome=s user=s
}
#   run_export2fasta  run_align  run_makerds  run_erange  run_erccs  run_stats  run_pslReps  run_pslSort
#   run_blat_rna_all call_store_hits call_filter_hits


$rnaseq_opts=$rnaseq_full_opts.map {|o| o.sub(/=.*$/,'').to_sym}


# parse command line opts; returns unparsed args
def parse_options

  defaults={
    :max_mismatches=>1,
    :align_params=>'-k 11 -m 10 -t --best -q -n 1',
    :script_dir=>'/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts',
    :rnaseq_dir=>'/proj/hoodlab/share/vcassen/rna-seq',
    :bin_dir=>'/hpc/bin',
    :dry_run=>false,
    :user=>ENV['USER'],

    :config_file=>'',
    :qsub_template=>'/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts/launch_rnaseq_pipeline.template.rb',
    :qsub_cmd=>"/sge/bin/lx24-amd64/qsub",
    :qsub_opts=>" -S /bin/sh"
  }

  Options.use($rnaseq_full_opts)

  # have to pre-process config_file:
  if (i=ARGV.index '-config_file')
    load_config(ARGV[i+1])
  end

  Options.required(%w{working_dir export_file label org readlen max_mismatches rnaseq_dir script_dir})
# Options.required(%w{working_dir export_file label org readlen max_mismatches rnaseq_dir script_dir pp_id})
  Options.use_hash(defaults)

  begin
    Options.parse()
  rescue RuntimeError=>e
    puts e.message
    puts
    usage()
    exit
  end

  if !Options.readlen.nil? && !Options.org.nil? && Options.ref_genome.nil?
    ref_genome="#{Options.org}_spliced_#{Options.readlen-4}"
    Options.set_value(:ref_genome,ref_genome)
  end

end

def usage
  list=['Options values:']
  Options.opts_hash.each_pair do |k,v|
    line=[k,Options.arg_type(k),Options.value_of(k)]
    default=Options.default_value(k)
    line << default unless default.nil?
    list << line.join("\t")

  end
  puts list.join("\n")
end


def load_config(config_file)
  yaml_contents=YAML.load(File.read(config_file))
  Options.use_hash(yaml_contents)
end

def launch
  cmd=assemble_cmd()
  qsub_script=write_qsub_script(cmd)
  
  launch_cmd="#{Options.qsub_cmd} #{Options.qsub_opts} #{qsub_script}"

  ok=system launch_cmd
  puts "#{ok} -> #{cmd}"
  ok
end

########################################################################

def environment_check
  messages=Array.new
  
  # check for qsub availability:
  qsub=Options.qsub_cmd
  messages << "qsub unavailable on this host" unless File.executable? qsub

  if (messages.length > 0) 
    message=messages.join("\n")
    puts messages
    exit 1
  end 
end

########################################################################

def assemble_cmd
  opt_hash=Options.all

  ruby=File.join(opt_hash[:bin_dir],'ruby')
  rnaseq_pipeline=File.join(opt_hash[:script_dir],'rnaseq_pipeline.rb')
  # todo: check the existence of the above!
  

  opts=[]
  opt_hash.each_pair do |k,v|
    next unless $rnaseq_opts.include?(k) 
    next if (v.nil? or v=='') and Options.arg_type(k) != 'b'

    v = "'#{v}'" if ((v.class==String and v.include?(' ')) or v=='')
    spacer=(v.nil? or v=='')? ' ' : '=' # use '=' mostly for align_params, whose value is '-k ...', which confuses options.rb otherwise
    opts.push("-#{k}#{spacer}#{v}")
  end
  opt_str=opts.sort.join(" ")

  cmd="#{ruby} #{rnaseq_pipeline} #{opt_str}"
end

def write_qsub_script(cmd)
  template_filename=Options.qsub_template
  template_file=File.open(template_filename)
  template=template_file.read
  template_file.close

  email="#{Options.user}.systemsbiology.org"
  label=Options.label
  working_dir=Options.working_dir
  script=eval template

  qsub_filename=File.join(Options.working_dir,"#{Options.label}.qsub")
  qsub_file=File.open(qsub_filename,"w")
  qsub_file.puts script
  qsub_file.close
  puts "#{qsub_filename} written"
  qsub_filename
end

main()
