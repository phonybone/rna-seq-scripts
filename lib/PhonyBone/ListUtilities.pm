#!/usr/bin/env perl
use strict;
use warnings;

package PhonyBone::ListUtilities;
use base qw(Exporter);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(unique_sorted unique all_unique delete_elements union intersection 
		subtract xor invert soft_copy shuffle 
		is_monotonic_asc is_monotonic_desc minmax range end reverse
		split_on_elem array_iterator hash_iterator
		);

use Data::Dumper;
use Carp;


# A few utility list utility routines

# remove redundant elements from a SORTED list:
sub unique_sorted {
    my @answer;
    my $last = shift @_ or return ();
    push @answer, $last;	# now put it back

    for (@_) {
	push @answer, $_ unless $_ eq $last;
	$last = $_;
    }
    @answer;
}

# remove redundant elements from a list:
# takes either list of listref; returns either list or listref
sub unique {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my %hash=map{($_,$_)} @$list;
    wantarray? values %hash : [values %hash];
}

# return 1 if every element in the list is different, 0 otherwise
sub all_unique {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my %hash;
    foreach my $e (@$list) {
	return 0 if $hash{$e};
	$hash{$e}=$e;
    }
    return 1;
}

# remove elements from a list
# call as "delete_elements(\@list, @to_remove)"
sub delete_elements {
    my $list_ref = shift;
    my @new_list;
    foreach my $item (@$list_ref) {
	push @new_list, $item unless grep { $_ eq $item} @_;
    }
    @$list_ref = @new_list;
}

# takes 2 listrefs; returns list or list ref
sub union {
    my ($list1, $list2) = @_;
    my %hash;
    map { $hash{$_}=1 } @$list1;
    map { $hash{$_}=1 } @$list2;
    my @keys = keys %hash;
    wantarray? @keys : \@keys;
}

# takes 2 listrefs; returns list or list ref
sub intersection {
    my ($list1, $list2) = @_;
    my (%hash1, %hash2);

    map { $hash1{$_}=1 } @$list1; # gather list 1:
    map { $hash2{$_}=1 if $hash1{$_} } @$list2; # gather intersection(list1, list2)

    my @keys = keys %hash2;
    wantarray? @keys : \@keys;
}

# takes 2 listrefs; returns list or list ref
# returns $list1-$list2
sub subtract {
    my ($list1, $list2) = @_;
    my %hash=();
    map { $hash{$_}=$_ } @$list1; # gather list 1
    map { delete $hash{$_} if $_} @$list2 if @$list2; # remove list 2
    
    my @values = values %hash;
    wantarray? @values : \@values;
}

# return all genes in one list, but not both
# takes 2 listrefs; returns list or list ref
sub xor {
    my ($list1, $list2) = @_;
    my %hash;
    do {push @{$hash{$_}}, $_} foreach @$list1;
    do {push @{$hash{$_}}, $_} foreach @$list2;
    while (my ($k,$v)=each %hash) {
	delete $hash{$k} unless @{$hash{$_}}==1;
    }
    my @values = values %hash;
    wantarray? @values : \@values;
}

# invert a hash (ie, foreach k=>v, return a hash with v=>k)
# if there are duplicate values, they get randomly overwritten
# if there are undefined values, they get abandoned
sub invert {
    my %input=(@_==1 && ref $_[0] eq 'HASH')?%{$_[0]}:@_;
    my %output;
    while (my ($k,$v)=each %input) {
	defined $v and $output{$v}=$k;
    }
    wantarray? %output:\%output;
}

# take two hashrefs; copy k,v from h2 into h1 so long as h1->{k} doesn't exist:
sub soft_copy {
    my ($h1,$h2)=@_;
    while (my ($k,$v)=each %$h2) {
	$h1->{$k}=$v unless exists $h1->{$k};
    }
}


# randomize a list by swapping elements $n times
sub shuffle {
    my ($list,$n)=@_;
    my $l=@$list;
    while ($n--) {
	my $i1=int(rand($l));
	my $i2=int(rand($l));
	my $tmp=$list->[$i1];
	$list->[$i1]=$list->[$i2];
	$list->[$i2]=$tmp;
    } 
}

sub is_monotonic_asc {
    my ($list)=@_;
    my $n=@$list or return 0;
    my $e=shift @$list;

    foreach my $f (@$list) {
	do {unshift @$list,$e; return 0} if $e<$f;
    }
    unshift @$list,$e;
    return 1;
}

sub is_monotonic_desc {
    my ($list)=@_;
    my $n=@$list or return 0;
    my $e=shift @$list;

    foreach my $f (@$list) {
	do {unshift @$list,$e; return 0} if $e>$f;
    }
    unshift @$list,$e;
    return 1;
}

sub minmax {
    my ($list)=@_;
    return (undef,undef) if @$list==0;
    my ($min,$max)=($list->[0],$list->[0]);
    foreach my $e (@$list) {
	$min=$e if $e<$min;
	$max=$e if $e>$max;
    }
    ($min,$max);
}

sub range {
    my ($list)=@_;
    my ($min,$max)=minmax($list);
    return $max-$min;
}

sub end {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my $last=(scalar @$list)-1;
    $list->[$last];
}

sub reverse {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my @rev;
    foreach my $e (@$list) {
	unshift @rev,$e;
    }
    wantarray? @rev:\@rev;
}

# split one list into two, around an indicated element.  O(n)
# returns two listrefs, shortest first
sub split_on_elem {
    my $elem=shift;
    confess "missing arg: list[ref]" unless defined $_[0];
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my $i;
    for ($i=0; $list->[$i]!=$elem; $i++) { }
    my @l1=@$list[0..$i];
    my $last=scalar @$list-1;
    my @l2=@$list[$i+1..$last];
    @l1<@l2? (\@l1,\@l2):(\@l2,\@l1);
}


sub array_iterator {
    my ($listref,$subref)=@_;
    foreach my $e (@$listref) { $subref->($e) }
}

sub hash_iterator {
    my ($hashref,$subref)=@_;
    while (my ($k,$v)=each %$hashref) { $subref->($k,$v) }
}



1;
