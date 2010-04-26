#!/tools/bin/ruby

# Scaffold script to write the launch_rnaseq_pipeline.rb script for a given set of parameters

$:<<"#{File.dirname(__FILE__)}/lib"
require 'options'
require 'local_utils.rb'

require 'net/http'
require 'rubygems'
require 'active_support'

def main
  parse_opts
  write_scripts
end

def parse_opts
  
  Options.use(%w{ruby rnaseq_pipeline=s working_dir=s export_file=s label=s org=s readlen=i max_mismatches=i script_dir=s rnaseq_dir=s pp_id=i template=s ruby=s dry_run bin_dir=s host=s email=s})

  

  defaults={
    :bin_dir=>'/local/jdrf_tools/bin',
    :rnaseq_pipeline=>'/proj/hoodlab/share/vcassen/rna-seq/scripts/rnaseq_pipeline.rb',
    :working_dir=>'/solexa/hood/022210_LYC/100309_HWI-EAS427_0014_FC61502AAXX/Data/Intensities/BaseCalls/GERALD_16-03-2010_sbsuser/post_pipeline_419',
    :export_file=>'s_1_export.txt',
    :label=>'sample_419_fcl_590',
    :org=>'human',
    :readlen=>75,
    :max_mismatches=>1,
    :script_dir=>'/proj/hoodlab/share/vcassen/rna-seq/scripts',
    :rnaseq_dir=>'/proj/hoodlab/share/vcassen/rna-seq',
    :pp_id=>0,
    :email=>'vcassen@systemsbiology.org',
    :template=>'/proj/hoodlab/share/vcassen/rna-seq/scripts/launch_rnaseq_pipeline.template.rb'
  }
  Options.use_defaults(defaults)
  Options.parse
end

def write_scripts
  write_entry_script
  write_launch_qsub_script
  write_qsub_script
end



def write_entry_script
  
end

def write_launch_qsub_script
end

def write_qsub_script
end

def something
  host=(!Options.host.nil? ? Options.host : `hostname`.chomp).split('.')[0].to_sym
  bin_dir={:aegir=>'/hpc/bin',
    :bento=>'/tools/bin',
    :mimas=>'/tools/bin'}[host]
  bin_dir='/tools/bin' if bin_dir.nil?
  ruby=File.join(bin_dir,'ruby')

  rnaseq_pipeline=Options.rnaseq_pipeline
  working_dir=Options.working_dir
  export_file=Options.export_file
  label=Options.label
  org_name=Options.org
  readlen=Options.readlen
  max_mismatches=Options.max_mismatches
  script_dir=Options.script_dir
  rnaseq_dir=Options.rnaseq_dir
  pp_id=Options.pp_id
  email=Options.email
  template=Options.template
  dry_run=Options.dry_run ? '-dry_run' : ''


  template_text=''
  File.open(Options.template).each do |l|
    template_text+=l
  end

  rnaseq_pipeline_script = eval template_text
  output_filename="#{working_dir}/rnaseq_pipeline.#{label}.rb"
  output=File.open(output_filename,"w")
  output.puts rnaseq_pipeline_script
  output.close
  puts "#{output_filename} written"

end



main()
