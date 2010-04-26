#!/usr/bin/env perl 
use strict;
use warnings;
use Carp;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use Options;
use SlimseqClient;

# Post to slimseq

BEGIN: {
  Options::use(qw(d q v h type=s id=i field=s value=s 
		  base_url user pass));
    Options::required(qw(type id field value));
    Options::useDefaults(base_url=>'http://db/slimarray_staging',
			 user=>'slimbot',
			 pass=>'l7Zh8t8WsO4LAFsFYgaw',
			 );
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}

MAIN: {
    my @ss_args=qw(base_url user pass);
    my %ss_args;
    @ss_args{@ss_args}=@options{@ss_args};
    my $ss=SlimseqClient->new(%ss_args);

    my $content=$ss->post(type=>$options{type},id=>$options{id},params=>{$options{field}=>$options{value}});
    warn "content is ",Dumper($content) if $ENV{DEBUG};
}
