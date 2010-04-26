#!/bin/env perl
use strict;
use warnings;
use Carp;
use Data::Dumper;
use lib '/proj/hoodlab/share/vcassen/rna-seq/scripts/lib';
use Options;

# Compute counts of ERCC seqs in bowtie output, taking into account original
# count as encoded in fasta title.  Essential op of this script is grouping
# together different alignments within the same ERCC seq.

BEGIN: {
  Options::use(qw(d h print_histo));
    Options::useDefaults();
    Options::get();
    die usage() if $options{h};
    $ENV{DEBUG}=1 if $options{d};
}

MAIN: {
    my $bowtie_output=$ARGV[0] or die "no bowtie output file\n";

    # collect ERCC's
    my %ercc2count;
    my $total_aligned_reads=0;
    my $nline=0;
    open (BOWTIE, $bowtie_output) or die "Can't open $bowtie_output: $!\n";
    while (<BOWTIE>) {
	chomp;
	my @stuff=split;

	my $title=$stuff[0];
	my ($seq,$count)=$title=~/^([ancgt]+)_(\d+)/gi;
	if (!defined $count) {
	    warn "$0: can't get count from '$title'??? (in $bowtie_output line $nline)\n";
	    exit 1;
	} 

	$total_aligned_reads+=$count;
	next unless $stuff[2]=~/ERCC/;

	$ercc2count{$stuff[2]}+=$count;
	$nline++;
    }
    close BOWTIE;

    # output results:
    if ($options{print_histo}) {
	foreach my $ercc (sort keys %ercc2count) {
	    my $count=$ercc2count{$ercc};
	    print "$ercc\t$count\n";
	}
    }

    my $total_aligned_reads_file="$bowtie_output.total_aligned_reads"; # jee-zus
    if (open (TARF,">$total_aligned_reads_file")) {
	print TARF "total_aligned_reads: $total_aligned_reads\n";
	close TARF;
	warn "$total_aligned_reads_file written\n";
    }
}
