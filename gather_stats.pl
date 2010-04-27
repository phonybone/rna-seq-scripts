#!/bin/env perl

# 


use strict;
use warnings;
use Carp;
use Data::Dumper;
use DBI;

use lib '/proj/hoodlab/share/vcassen/rna-seq/scripts/lib';
use lib '/proj/hoodlab/share/vcassen/rna-seq/scripts/lib/PhonyBone';
use Options;

# cmd-line args:
# working_dir should be the post_pipeline directory underneath the export file
# export_file should only be the filename and not include the path directory (fixme: this assumes a link in working_dir to the export file)
# job_name can be anything but preferably should be the same job_name that was used to run the qsub script (that runs the rna-seq pipeline).  
#  It is used in the name of the .stats file created.

BEGIN: {
  Options::use(qw(d h working_dir=s export=s job_name=s));
    Options::useDefaults(
			 rds_dir=>'rds',
			 );
    
    Options::required(qw(working_dir export job_name));
    Options::get();
    die usage() if $options{h};
    $ENV{DEBUG}=1 if $options{d};
}

MAIN: {
    my $dbh=connect_rds();

    prequisites();

    # reports:
    my $report;
    $report.=count_export_lines();
    my $h=parse_job_output();
    my $total_aligned_reads=sum_values($h);

    $report.="$total_aligned_reads total aligned reads\n";
    $report.=report_str($h);

    $h=count_db_stats($dbh);
    $report.=report_str($h);

    $h=parse_rdslog();
    $report.=report_str($h);

    my $stats_file=join('/',$options{working_dir},"$options{export}.stats");
    open (STATS,">$stats_file") or die "Can't open $stats_file for writing: $!\n";
    print STATS $report;
    close STATS;
    warn "$stats_file written\n";
}

sub prerequisites {
    my $output_file=join('/',$options{working_dir},"$options{job_name}.out");
    my $logfile=join('/',$options{working_dir},'rds',$options{export}).'.rds.log';
    foreach my $f ($output_file, $logfile) {
	open(F,$f) or die "check: Can't open $f: $!\n";
	close F;
    }

    my $stats_file=join('/',$options{working_dir},"$options{export}.stats"); # writing
    open(F,">>$stats_file") or die "check: Can't open $stats_file for appending: $!\n";
    close F;
}


sub count_export_lines {
    my $export_file=join('/',$options{working_dir},$options{export});
    warn "counting lines in $export_file...\n" if $ENV{DEBUG};
    my $count=`wc -l $export_file | cut -f1 -d/  `;
    warn $count if $ENV{DEBUG};
    chomp $count;
    sprintf "export file: %d total reads\n", $count;
}

# I'm not sure we really want this stat: it may be left over from the previous db....
sub parse_job_output {
    my $output_file=join('/',$options{working_dir},"$options{job_name}.out");
    warn "parsing job output $output_file...\n";
    my $report={title=>"From job output:"};
    open (JOB_OUTPUT,$output_file) or die "Can't open $output_file: $!\n";
    while (<JOB_OUTPUT>) {
	/(\d+) unique reads, (\d+) spliced reads and (\d+) multireads/ or next;
	@$report{qw(unique spliced multi)}=($1,$2,$3);
	last;			# quit at first successful match
    }
    close JOB_OUTPUT;
    $report;
}

sub count_db_stats {
    my ($dbh)=@_;
    warn "querying database...\n";
    my $report={title=>'From Database:'};
    foreach my $table (qw(uniqs splices multi)) {
	foreach my $field ('count(*)','count(distinct readID)') {
	    my $sql="SELECT $field FROM $table"; # for uniqs and splices it's probably the same
	    warn sprintf("query: $sql (%s)\n", scalar localtime) if $ENV{DEBUG};
	    my $rows=$dbh->selectall_arrayref($sql) or die "error trying to execute '$sql': ",$DBI::errstr;
	    my $count=$rows->[0]->[0];
	    my $label=sprintf "%s %s",$table,($field=~/distinct/i? 'distinct':'total');
	    $report->{$label}=$count;
#	    $report.="$_ ($label): $count\n";
	}
    }
    $report;
}

# have to figure out exactly what these numbers mean
sub parse_rdslog {
    my $logfile=join('/',$options{working_dir},'rds',$options{export}).'.rds.log';
    warn "parsing $logfile...\n";
    open (LOGFILE,$logfile) or die "Can't open $logfile: $!\n";
    my ($n_uniques, $n_multis, $n_splices);
    my $line;
    while (<LOGFILE>) {		# we just want the last line, and the file is short
	$line=$_;
    }
    close LOGFILE;
    ($n_uniques, $n_multis, $n_splices)=$line=~/(\d+) unique\D*(\d+) multi\D*(\d+) spliced/g;
    my %report;
    @report{qw(uniqs multi splices title)}=($n_uniques,$n_multis,$n_splices,'From Logfile:');
    \%report;
}

sub dump_master {
    my ($dbh)=@_;
    my $sql="SELECT * FROM SQLITE_MASTER";
    my $rows=$dbh->selectall_arrayref($sql);
    warn "SQLITE_MASTER: ",Dumper($rows);
}

# return a $dbh
sub connect_rds {
    my $engine='SQLite';
    my $host='localhost';
    my $db_type='db';
    my $dir=join('/', $options{working_dir}, 'rds');
    chdir $dir or die "Can't cd to $dir: $!\n";
    my $db_name=$options{export};
    my $dsn="DBI:$engine:$db_name.rds";
    warn "dsn is $dsn" if $ENV{DEBUG};
    my $user=$ENV{USER};
    my $password='';
    my $attrs={};
    my $dbh=DBI->connect($dsn,$user,$password,$attrs) or die "Can't connect: ",$DBI::errstr;
}

sub report_str {
    my ($report)=@_;
    confess "report missing or not a HASHREF" unless ref $report eq 'HASH';
    
    my $title=delete $report->{title};
    my $report_str="\n$title\n";
    $report_str.=join("\n",map {"$_: $report->{$_}"} sort keys %$report);
    $report_str.="\n";
    $report->{title}=$title;
    $report_str;
}

sub sum_values {
    no warnings;
    my $h=shift;
    my $sum=0;
    do { $sum+=$_ } foreach values %$h;
    $sum;
}
