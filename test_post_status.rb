def main
  post_status(442,'Finished')
end

def launch(cmd) 
  puts "\n#{cmd}"
#  unless Options.dry_run
    success=system cmd
    raise "**************\n\nFAILED\n********\n\n: $? is #{$?}" unless success
#  end
  success
end

def post_status(pp_id, status)
  $perl='/hpc/bin/perl'
  script_dir='/proj/hoodlab/share/vcassen/rna-seq/rna-seq-scripts'
  post_to_slimseq='post_to_slimseq.pl'
  $post_to_slimseq="#{script_dir}/#{post_to_slimseq}"

  ok=launch("#{$perl} #{$post_to_slimseq} -type post_pipelines -id #{pp_id} -field status -value '#{status}'")
end

main()
