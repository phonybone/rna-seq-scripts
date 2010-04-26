use strict;
use warnings;

package PhonyBone::FileUtilities;

# $Id: FileUtilities.pm,v 1.7 2009/07/13 20:56:46 vcassen Exp $

use Carp;

use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(slurpFile spitString appendFile directory_crawl 
		parse3 dir basename suffix filename dir_files
		directory_iterator file_iterator);


sub slurpFile {
    my $filename = shift or confess "no filename";
    open (FILE, "$filename") or confess "Can't open $filename: $!";

    my $oldFilehandle = select FILE;
    my $oldRecordSep = $/;
    undef $/;
    my $contents = <FILE>;	# slurp!
    $/ = $oldRecordSep;
    select $oldFilehandle;
    close FILE;
    return $contents;
}



sub spitString {
    my $string = shift;
    my $filename = shift;
    my $lockFlag = shift || '';

    open (FILE, ">$filename.tmp") or
	confess "Unable to open $filename.tmp for writing: $!\n";

    if ($lockFlag) {
	use Fcntl ':flock';
	flock(FILE, LOCK_EX);
	seek(FILE, 0, 2);
    }
    print FILE $string or
	confess "Unable to write to $filename: $!\n";

    flock(FILE, LOCK_UN) if $lockFlag;
    close FILE or confess "Unable to close $filename: $!\n";

    rename "$filename.tmp", "$filename" or confess "Unable to rename '$filename.tmp' to '$filename': $!\n";

    return 1;
}


sub appendFile {
    my $record = shift;
    my $filename = shift;

    open (FILE, ">>$filename") or
	confess "Unable to open $filename for appending: $!\n";

    print FILE $record or
	confess "Unable to write to $filename: $!\n";

    close FILE or confess "Unable to close $filename: $!\n";
    return 1;
}


sub prependFile {
    my $record = shift;
    my $filename = shift;

    my $contents = slurpFile($filename);
    open (FILE, ">$filename") or
	confess "Can't open $filename for writing: $!\n";
    print FILE $record;
    print FILE $contents;
    close FILE;
    1;
}

sub dir_files {
    my ($dir,$filter)=@_;
    opendir (DIR,$dir) or confess "Can't open '$dir': $!";
    $filter||='.';
    my @files=grep /$filter/, readdir DIR;
    closedir DIR;
    wantarray? @files:\@files;
}


sub directory_crawl {
    my $dir = shift or confess "no dir";
    my $dir_hook = shift || sub { };
    my $dir_args = shift;
    my $file_hook = shift || sub { };
    my $file_args = shift;
    my $level = shift || 0;

    opendir(DIR, $dir) or confess "Can't open $dir: $!";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;

    my @subdirs;
    foreach my $entry (@entries) {
	my $path = "$dir/$entry";
	if (-d $path) {
	    push @subdirs, "$entry";
	    &$dir_hook($path, $level, $dir_args) if ref $dir_hook eq 'CODE';
	} else {
	    &$file_hook($path, $level, $file_args) if ref $file_hook eq 'CODE';
	}
    }

    foreach my $subdir (@subdirs) {
	directory_crawl("$dir/$subdir", $dir_hook, $dir_args, $file_hook, $file_args, $level+1);
    }
}


sub parse3 {
    my $path=shift or confess "no path";

    # I don't think there is a lexigraphical way to differentiate /dir from /file:
    return wantarray? ($path,'',''):[$path,'',''] if -d $path;

    my ($d,$f,$b,$s);

    if ($path =~ m|/|) {
	# split into dir and file.suffix:
	($d,$f) = $path =~ m|(.*)/(.*)|g;
    } else {
	$d = '';
	$f = $path;
    }
    ($b,$s) = $f =~ /([^.]*)\.?(.*)/;
    wantarray? ($d,$b,$s):[$d,$b,$s];
}



sub dir { (parse3($_[0]))[0]; }
sub basename { (parse3($_[0]))[1]; }
sub suffix { (parse3($_[0]))[2]; }
sub filename { my @p=parse3($_[0]);join('.',$p[1],$p[2])}

########################################################################

sub directory_iterator {
    my ($directory,$subref,$fuse)=@_;

    $fuse=-1 unless defined $fuse;
    opendir (DIR, $directory) or die "Can't open $directory: $!\n";
    while ($_=readdir DIR) {
	chomp;
	$subref->($_);
	last if --$fuse==0;
    }
    close DIR;
}


sub file_iterator {
    my ($filename,$subref,$fuse)=@_;

    $fuse=-1 unless defined $fuse;
    open (FILE, $filename) or die "Can't open $filename: $!\n";
    while (<FILE>) {
	chomp;
	$subref->($_);
	last if --$fuse==0;
    }
    close FILE;
}

1;
