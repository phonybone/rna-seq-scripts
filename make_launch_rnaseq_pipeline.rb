#!/tools/bin/ruby

# Scaffold script to write the launch_rnaseq_pipeline.rb script for a given set of parameters

$:<<"#{File.dirname(__FILE__)}/lib"
require 'options'
require 'local_utils.rb'

require 'net/http'
require 'rubygems'
require 'active_support'

#$:<<'/net/dblocal/apps/SLIMarray/rails/cap_slimarray_staging/slimseq_phonybone/vendor/plugins/post_pipelines/app/models/'
#require 'post_pipeline'

def main
  parse_opts
  write_scripts
end

def parse_opts
  
  Options.use(%w{ruby rnaseq_pipeline=s working_dir=s export_file=s label=s org=s readlen=i max_mismatches=i 
                 script_dir=s rnaseq_dir=s proj_dir=s pp_id=i template=s ruby=s dry_run bin_dir=s host=s email=s qsub=s
                 ref_genome=s bowtie_opts=s})

  conf=YAML.load_config 'make_launch_rnaseq_pipeline.conf'
  Options.use_defaults(conf)
  Options.parse


end

def write_scripts
  write_entry_script
  write_launch_qsub_script
  write_qsub_script
end

########################################################################

def entry_file
  "#{Options.working_dir}/#{Options.label}.entry.sh"
end
def launch_qsub_file
  "#{Options.working_dir}/#{Options.label}.qsub.sh"
end
def qsub_file
  "#{Options.working_dir}/#{Options.label}.launch.sh"
end

########################################################################
# Write the script that qsub will invoke:
def write_entry_script
  launch_qsub=launch_qsub_file()

  template_file=File.join(Options[:proj_dir],Options[:script_dir],'entry.template')
  template=File.slurp template_file
  script=eval template
  File.spit(entry_file(),script)
  $stderr.puts "#{entry_file} written"
end

def write_launch_qsub_script
  qsub=Options[:qsub]
  qsub_file=qsub_file()
  
  template_file=File.join(Options[:proj_dir],Options[:script_dir],'launch_qsub.template')
  template=File.slurp template_file

  working_dir=Options.working_dir
  label=Options.label

  script=eval template
  File.spit(launch_qsub_file(),script)
  $stderr.puts "#{launch_qsub_file} written"
end

# Write the script that will launch the pipeline (invoked by the entry script)
def write_qsub_script()

  # Current file(template) is launch_rnaseq_pipeline.template.rb
  # needed: ruby, rnaseq_pipeline, working_dir*, export_file*, label*, org_name*, readlen, max_mismatches*, script_dir, rnaseq_dir, bin_dir, pp_id, [dry_run]
  # This is the only file that needs writing now
  # see also make_launch_rnaseq_pipeline.rb


  pp_id=Options[:pp_id]
  ruby=Options[:ruby]
  rnaseq_pipeline=File.join(Options[:proj_dir],Options[:script_dir],'rnaseq_pipeline.rb')
  readlen=Options.readlen # fixme: data in table is busted for some samples
  script_dir=Options[:script_dir]
  rnaseq_dir=Options[:rnaseq_dir]
  bin_dir=Options[:bin_dir]
  dry_run_flag= Options.dry_run ? '-dry_run':'' # dry_run comes from form, so values are [0|1]
  email=Options.email
  working_dir=Options.working_dir
  export_file=Options.export_file
  label=Options.label
  org_name=Options.org
  max_mismatches=Options.max_mismatches

  # ref_genome is only needed for bowtie, but include always anyway
  ref_genome=Options.ref_genome
  bowtie_opts=Options[:bowtie_opts]
  
  template_file=File.join(Options[:proj_dir],Options[:script_dir],'qsub.template')
  template=File.slurp template_file
  script=eval template
  File.spit(qsub_file(),script)
  $stderr.puts "#{qsub_file} written"
end

#-----------------------------------------------------------------------

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
  output_filename="#{Options.working_dir}/rnaseq_pipeline.#{Options.label}.rb"
  output=File.open(output_filename,"w")
  output.puts rnaseq_pipeline_script
  output.close
  puts "#{output_filename} written"

end



main()
