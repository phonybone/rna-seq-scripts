require 'rubygems'
require 'mysql'

$:<< '/users/vcassen/proj_vcassen/rna-seq/rna-seq-scripts/lib'
require 'options'
require 'local_utils'

def main
  parse_options
  info=get_sample_info
  write_file info
end

def parse_options
  Options.use(%w{sample_id=i working_dir=s export_file=s label=s template_file=s gather_stats=s perl=s
                 host=s user=s password=s db=s
})
  Options.use_defaults({:template_file=>'/users/vcassen/proj_vcassen/rna-seq/rna-seq-scripts/make_gather_stats.template',
                         :gather_stats=>'/home/vcassen/proj/rna-seq/rna-seq-scripts/gather_stats.pl',
                         :perl=>'/hpc/bin/perl',
                         :host=>'deimos',:user=>'root',:password=>'kornDog',:db=>'slimseq_staging'
                       })
  Options.required(%w{sample_id})
  Options.parse()
#  Options.all.each do |o| puts o; end
end

def get_sample_info
  dbh=Mysql.new(Options.host,Options.user,Options.password,Options.db)

  sample_id=Options.sample_id
  query="SELECT fcls.sample_id, s.name_on_tube, fcls.flow_cell_lane_id, pr.eland_output_file from samples s join flow_cell_lanes_samples fcls on s.id=fcls.sample_id join pipeline_results pr on pr.flow_cell_lane_id=fcls.flow_cell_lane_id where s.id=#{sample_id}"
  results=dbh.query(query)
  raise "no results for '#{query}'" if results.to_a.size==0
  raise "too many results for '#{query}'" if results.to_a.size>1
  info=Array.new
  results.each do |result|
    export_path=result[3]
    export_file=File.basename export_path
    working_dir=File.join(File.dirname(export_path),"post_pipeline_#{sample_id}")
    name_on_tube=result[1]
    label=name_on_tube+'.'+export_file.split('_')[0,2].join('_')
    info=[working_dir,export_file,label]
  end
  info
end

def write_file(info)
  working_dir,export_file,label=info.flatten
  # assign local vars

  gather_stats=Options.gather_stats
  perl=Options.perl

  # slurp template 
  template=File.slurp Options.template_file
#  $stderr.puts "template is #{template}"

  # eval template
  script=eval template
#  $stderr.puts "script is #{script}"

  # spit script
  output_filename=File.join working_dir,"gather_stats.#{label}.sh"
  File.spit output_filename,script
  $stderr.puts "#{output_filename} written"
end

main()
