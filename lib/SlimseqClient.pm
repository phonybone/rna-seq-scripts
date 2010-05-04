package SlimseqClient;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use JSON qw(to_json from_json);

########################################################################
# Module for querying Slimseq
########################################################################


use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(base_url user pass urls);
@CLASS_ATTRIBUTES = qw(ua _base_url);
%DEFAULTS = (_base_url=>'http://slimbot:l7Zh8t8WsO4LAFsFYgaw@db/slimarray_staging',
	     );

%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
    $self->base_url($self->_base_url) unless $self->base_url;
#    warn "self->base_url is ",$self->base_url;
    $self->_set_urls;
}

sub _set_urls {
    # set urls:
    my ($self,$base_url)=@_;
    $base_url||=$self->base_url;
    confess "no base_url" unless $base_url;
    my %urls=(
	       summary=>"$base_url/samples",
	       flow_cell_lane=>"$base_url/flow_cell_lanes",
	       flow_cell=>"$base_url/flow_cells",
	       naming_scheme=>"$base_url/naming_schemes",
	       project=>"$base_url/projects",
	       base_url=>$base_url,
	       );
    # do some synonyms:
    $urls{sample}=$urls{summary};
    $urls{lane}=$urls{flow_cell_lane};
    $urls{cell}=$urls{flow_cell};
    $urls{scheme}=$urls{naming_scheme};
    $self->urls(\%urls);
}

sub _class_init {
    my $class=shift;
    $class->ua(LWP::UserAgent->new);
}

# workhorse routine: makes the actual request to slimseq
# returns undef on error
# otherwise returns an object (hashref) based on the JSON reponse
sub get_uri {
    my ($self,$url)=@_;
    $url=$self->add_user($url);

    warn "fetching $url...\n" if $ENV{DEBUG};
    my $req=HTTP::Request->new(GET=>$url);
    $req->header(Accept=>'application/json');
    my $res=$self->ua->request($req);
    unless ($res->is_success) {
	warn "$url: ",$res->status_line;
	return undef;
    }

    my $content=$res->content;
    my $obj;
    eval { $obj=from_json($content) };
    die "Can't get json from '$content'\n($@)\n" if $@;
#    warn "obj is ",Dumper($obj);
    $obj;
}

sub add_user {
    my ($self,$uri)=@_;
    my $user=$self->user;
    my $pass=$self->pass;
    return $uri unless $user && $pass;
    return $uri if $uri=~/$user:$pass/;
    return $uri if $uri=~qr(https?://\w+:\w+\@\w+/);
    my @pieces=split('/',$uri);
    $pieces[2]="$user:$pass\@$pieces[2]";
    join('/',@pieces);
}

sub get_slimseq_json {
    my ($self,$type,$id)=@_;	# id could be undef
    confess "no type" unless $type;

#    my $url=$self->urls->{$type} or die "unknown type: '$type' (",join(', ',keys %urls),")\n";
    my $url=$self->urls->{$type} || $self->base_url."/$type";
    $url.="/$id" if defined $id;
    $self->get_uri($url);
}



# given a project name, return a hash containing the following info:
# reference genome organism
# reference genome name
# restriction enzyme name
# experiement_id (manufactured by us based on project name)
# export file directory
# export file index string ( m/1?2?3?4?5?6?7?8?/ )
# The hash will also contain other information about the project as gleaned from slimseq
#
# This is a SolexaTrans routine!  Probably not useful for general purpose use.

sub gather_project_info {
    my ($self,$project_name)=@_;

    # find project id by searching all projects for this name:
    my $all_projects=$self->get_slimseq_json('project');
    my @project_objs=grep {$_ && ($_->{name} eq $project_name)} @$all_projects;
#    warn "project objects for $project_name: ",Dumper(\@project_objs);
    die "no project /name='$project_name'" unless @project_objs>0;
    die "more than one project w/name='$project_name'" if @project_objs>1;
    my $project_id=$project_objs[0]->{id};
    
    # get project using project_id:
    die "no id for project '$project_name'???" unless defined $project_id;
    my $project=$self->get_slimseq_json('project',$project_id);
    die "project $project_id unavailable\n" unless $project;

    # extract info from each of project's samples:
    my $sample_uris=$project->{sample_uris};
    die "no samples for project '$project_id': ",Dumper($project)
	unless ref $sample_uris eq 'ARRAY' && @$sample_uris>0;
    foreach my $s_uri (@$sample_uris) {
	$s_uri=~s|http://osiris|http://test:test\@osiris|;
	$s_uri=~/\d+$/;
	my $sample_id=$&;

	my $sample=$self->get_uri($s_uri) or 
	    die "no sample for uri='$s_uri'???";
	warn "sample is ",Dumper($sample) if $ENV{DEBUG};

	# check status for 'completed':
	warn "$s_uri: status not 'completed': '", $sample->{status},"'" 
	    unless lc $sample->{status} eq 'completed';

	# get restriction enzyme and make sure is the same:
	my $res_en=$sample->{sample_prep_kit_restriction_enzyme};
	$project->{restriction_enzyme}||=$res_en;
	die "multiple restriction enzymes" 
	    unless $res_en eq $project->{restriction_enzyme};
	
	# get genome info:
	my $genome_org=$sample->{reference_genome}->{organism};
	my $genome_name=$sample->{reference_genome}->{name};
	my $ref_genome="$genome_org|$genome_name";
	$project->{ref_genome}||=$ref_genome;
	die "multiple ref genomes" unless $project->{ref_genome} eq $ref_genome;

	# get tag_length:
	my $tag_length=$sample->{alignment_end_position}-$sample->{alignment_start_position}+1;
	$project->{tag_length}||=$tag_length;
	die "multiple tag_lengths" unless $project->{tag_length}==$tag_length;

	# get all flowcell info for this sample:
	my $flowcell_uris=$sample->{flow_cell_lane_uris};
	foreach my $f_uri (@$flowcell_uris) {
	    my $flowcell=$self->get_uri($f_uri);
	    do {warn "$f_uri: not completed";next} unless $flowcell->{status} eq 'completed';
	    push @{$project->{export_files}}, $flowcell->{eland_output_file};
	    push @{$project->{lanes}}, $flowcell->{lane_number};
	    $project->{lane2sample_id}->{$flowcell->{lane_number}}=$sample_id;
	}
    }

    my $export_file=$project->{export_files}->[0] or die "no export_files???";
    $export_file=~s|/[^/]*$||;	# chop filename from path
    $project->{export_dir}=$export_file;
    $project->{export_index}=join('',sort {$a<=>$b} @{$project->{lanes}});
    $project;
}


sub gather_sample_info {
    my ($self,$ssid)=@_;
    confess "no ssid unless $ssid";
}


# make a post request to slimseq; USE WITH CAUTION!
# params must be an arrayref of key/value pairs corresponding to the proper fields of $type's table.
# returns content of HTTP Response if success, throws exception containing status line on error.
sub post {
    my ($self,%argHash)=@_;
    my ($type,$id,$params)=@argHash{qw(type id params)};
    confess "missing type" unless $type;
    confess "missing params" unless $params;
    confess "params: not a HASH ref" unless ref $params eq 'HASH';

    my $METHOD=defined $id? 'PUT':'POST';
    my $method=defined $id? 'update':'create';

    my $url=join('/',$self->base_url,$type,$method);
    $url.="/$id" if defined $id;
    $url=$self->add_user($url);
    warn "${METHOD}ing to $url" if $ENV{DEBUG};

    my $headers=HTTP::Headers->new;

    my $type1=$type;
    $type1=~s/s$//;
    my $params_array=[];
    while (my ($k,$v)=each %$params) {
	$k="$type1\[$k]";
	push @$params_array,$k,$v;
    }
#    warn "params is $params_array:\n",Dumper($params_array);

    my $res=$self->ua->post($url,$params_array,$params_array);
    die(sprintf "$url: %s",$res->status_line) if $res->is_error;
    return $res->content;
}

sub hashref2arrayref {
    my @a=%{$_[0]};
    \@a;
}

__PACKAGE__->_class_init;

1;
