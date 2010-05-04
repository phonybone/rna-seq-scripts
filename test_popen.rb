cmd='qstat -u solxabot -ext'

contents=IO.popen(cmd).read
puts contents
exit

contents=IO.popen(cmd).each do |line|
  puts line
  stuff=line.split
  if (job_id=stuff[0].to_i)>0
    err_code=stuff[7]
    puts "job_id is #{job_id}; err_code is #{err_code}"
  end
end

puts "contents is #{contents}"


