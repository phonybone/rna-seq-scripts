#!/bin/env perl
use strict;
use warnings;
use Carp;
use Data::Dumper;
use lib '/proj/hoodlab/share/vcassen/rna-seq/scripts/lib';
use Options;
use PhonyBone::FileUtilities qw(file_iterator slurpFile);
use PhonyBone::ListUtilities qw(hash_iterator);

# Produce a normalized measure of ERCC presense from a set of aligned reads.
# Inputs:
# alignment file containing reads, with ERCC "genes" included
# Perl dump of hash containing ERCC length-based weights (see create_ercc_weights.pl)
#
# Outputs:
# 1. a tab-delimited file containing two columns: ERCC "gene" and normalized concentration.
# 2. a listing of raw ERCC counts (output is from `uniq -c`) 

# Steps:
# extract ERCC seqs from an alignment output file
# (uses `grep ERCC- <patman.out> | cut -f1 -d\| sort | uniq -c > ercc.counts`)
# count reads
# normalize each count by length of ERCC seq, per 10^6 reads
# gets total_aligned_reads from stats file (assuming there is one? So far, that's tag-counting only...
#
# This is written for patman output, which implies tag-counting (not rna-seq) which raises the question of
# why am I doing this since tag-counting is not length-dependent...

BEGIN: {
  Options::use(qw(d h
		  patman_output=s bowtie_output=s
		  force
		  total_aligned_reads=i
		  ));
    Options::useDefaults(weights=>'/jdrf/data_var/solexa/genomes/bacteria/081215_ERCC_reference.normalization_factors',
			 );
    Options::required(qw(total_aligned_reads));	# also need either patman_output or bowtie_output
    Options::get();
    die usage() if $options{h};
    die usage() unless $options{patman_output} || $options{bowtie_output};
    $ENV{DEBUG}=1 if $options{d};
}

my ($n_seqs,$total_length)=(0,0);
my %seq2len;
my %seq2weight;

MAIN: {
    # extract_erccs from patman (or bowtie) output:
    my $ercc_counts=$options{bowtie_output}? extract_erccs_bowtie($options{bowtie_output}) : extract_erccs_patman($options{patman_output});

    # read in ercc_counts
    my %ercc2count;
    file_iterator($ercc_counts,sub { my ($undef,$count,$ercc)=split(/\s+/,$_[0]); $ercc2count{$ercc}=$count });

    # read in weights
    my $weights=slurpFile($options{weights});
    my $VAR1;
    eval $weights;
    my %ercc2weight=%$VAR1;
#    warn "ercc2weight: ",Dumper(\%ercc2weight);

    # calculate normalization
    my %ercc2normalized;
    my $reads_factor=1_000_000/$options{total_aligned_reads};
    warn "reads_factor is $reads_factor\n";
    hash_iterator(\%ercc2count, sub {
	my ($ercc,$count)=@_;
	$ercc2normalized{$ercc}=$count*$reads_factor*$ercc2weight{$ercc};
    });

    # write to disk:
    my $output=$options{patman_output} || $options{bowtie_output};
    $output=~s/.[^.]*?$/.normalized/; # replace the file's suffix with '.normalized'

    open(OUTPUT,">$output") or die "Can't open $output for writing: $!\n";
#    hash_iterator(\%ercc2normalized, sub { print OUTPUT join("\t",@_),"\n" }); # doesn't alphabetize ercc keys
    foreach my $ercc (sort keys %ercc2normalized) {
	my $normalized=$ercc2normalized{$ercc};
	print OUTPUT join("\t",$ercc,$normalized),"\n";
    }
    close OUTPUT;
    warn "$output written\n";
}

sub extract_erccs_patman {
    my ($patman_output)=@_;
    return "$patman_output.erccs" if -r "$patman_output.erccs" && !$options{force};
    my $cmd="grep ERCC- $patman_output | cut -f1 -d\\| | sort | uniq -c > $patman_output.erccs";
    warn "$cmd\n";
    my $rc=system($cmd)>>8;
    die "Error executing '$cmd', quitting\n" unless $rc==0;
    warn "$patman_output.erccs written\n";
    "$patman_output.erccs";
}

sub extract_erccs_bowtie {
    my ($bowtie_output)=@_;
    return "$bowtie_output.erccs" if -r "$bowtie_output.erccs" && !$options{force};
    my $cmd="cut -f3  $options{bowtie_output} | grep ERCC- | sort | uniq -c > $bowtie_output.erccs";
    warn "$cmd\n";
    my $rc=system($cmd)>>8;
    die "Error executing '$cmd', quitting\n" unless $rc==0;
    warn "$bowtie_output.erccs written\n";
    "$bowtie_output.erccs";

    # is this really correct?  bowtie output does one line per alignment, so particular seqs
}
