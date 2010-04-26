package Class::AutoClass;
use strict;
our $VERSION = '1.0';
use vars qw($AUTOCLASS $AUTODB @ISA %CACHE @EXPORT);
$AUTOCLASS = __PACKAGE__;
use Class::AutoClass::Root;
use Class::AutoClass::Args;
use Storable qw(dclone);
use Carp;
@ISA = qw(Class::AutoClass::Root);

sub new {
 my ( $class, @args ) = @_;
 $class = ( ref $class ) || $class;
 declare($class) unless $class->DECLARED; # NG 06-02-03: in case not declared at compile-time
 my $classes = $class->ANCESTORS || [];    # NG 04-12-03. In case declare not called
 my $can_new = $class->CAN_NEW;
 if ( !@$classes ) {    # compute on the fly for backwards compatibility
  # enumerate internal super-classes and find a class to create object
  ( $classes, $can_new ) = _enumerate($class);
 }
 my $self = $can_new ? $can_new->new(@args) : {};
 bless $self, $class;    # Rebless what comes from new just in case
 my $args     = new Class::AutoClass::Args(@args);
 my $defaults = new Class::AutoClass::Args( $args->defaults );

 # set arg defaults into args
 while ( my ( $keyword, $value ) = each %$defaults ) {
  $args->{$keyword} = $value unless exists $args->{$keyword};
 }

################################################################################
# NG 05-12-08: initialization strategy changed. instead of init'ing class by class
#              down the hierarchy, it's now done all at once.
 $self->_init($class,$args);	# init attributes from args and defaults

# $defaults=new Class::AutoClass::Args; # NG 05-12-07: reset $defaults. 
#				       # will accumulate instance defaults during initialization
# my $default2code={};

 for my $class (@$classes) {
   my $init_self = $class->can('_init_self');
   $self->$init_self( $class, $args ) if $init_self;
   #  $self->_init( $class, $args, $defaults, $default2code );
 }
################################################################################

   if($self->{__NULLIFY__}) {
   	return undef;
   } elsif ($self->{__OVERRIDE__}) { # override self with the passed object
      $self=$self->{__OVERRIDE__};
      return $self;
   } else {
     return $self;
   }
}

################################################################################
# NG 05-12-08: initialization strategy changed. instead of init'ing class by class
#              down the hierarchy, it's now done all at once.
sub _init {
  my($self,$class,$args)=@_;
  my @attributes=ATTRIBUTES_RECURSIVE($class);
  my $defaults=DEFAULTS_RECURSIVE($class); # Args object
  my %fixed_attributes=FIXED_ATTRIBUTES_RECURSIVE($class);
  my %synonyms=SYNONYMS_RECURSIVE($class);
  my %reverse=SYNONYMS_REVERSE($class);    # reverse of SYNONYMS_RECURSIVE
  my %cattributes=CATTRIBUTES_RECURSIVE($class);
  my @cattributes=keys %cattributes;
  my %iattributes=IATTRIBUTES_RECURSIVE($class);
  my @iattributes=keys %iattributes;
  for my $func (@cattributes) {	# class attributes
    my $fixed_func=$fixed_attributes{$func};
    next unless exists $args->{$fixed_func};
#     no strict 'refs';
#     next unless ref $self eq $class;
    $class->$func($args->{$fixed_func});
  }
  for my $func (@iattributes) {	# instance attributes
    my $fixed_func=$fixed_attributes{$func};
    if (exists $args->{$fixed_func}) {
      $self->$func( $args->{$fixed_func} );
    } elsif (exists $defaults->{$fixed_func}) { 
      # because of synonyms, this is more complicated than it might appear.
      # there are 4 cases: consider syn=>real 
      # 1) args sets syn,  defaults sets syn
      # 2) args sets real, defaults sets syn
      # 3) args sets syn,  defaults sets real
      # 4) args sets real, defaults sets real
      next if exists $args->{$fixed_func}; # handles cases 1,4 plus case of not synonym
      my $real=$synonyms{$func};
      next if $real && exists $args->{$fixed_attributes{$real}}; # case 2
      my $syn_list=$reverse{$func};
      next if $syn_list && 
	grep {exists $args->{$fixed_attributes{$_}}} @$syn_list; # case 3
      # okay to set default!!
      my $value=$defaults->{$fixed_func};
      $value=ref $value? dclone($value): $value; # deep copy refs so each instance has own copy
      $self->$func($value);
    }
  }
}

########################################

#sub _init {
# my ( $self, $class, $args, $defaults, $default2code ) = @_;
# my %synonyms = SYNONYMS($class);
# my $attributes = ATTRIBUTES($class);
# # only object methods here
# $self->set_instance_defaults( $args, $defaults, $default2code, $class );       # NG 05-12-07
# $self->set_attributes( $attributes, $args, $defaults, $default2code, $class ); # NG 05-12-07
# my $init_self = $class->can('_init_self');
# $self->$init_self( $class, $args ) if $init_self;
#}

sub set {
 my $self = shift;
 my $args = new Class::AutoClass::Args(@_);
 while ( my ( $key, $value ) = each %$args ) {
  my $func = $self->can($key);
  $self->$func($value) if $func;
 }
}

sub get {
 my $self = shift;
 my @keys = Class::AutoClass::Args::fix_keyword(@_);
 my @results;
 for my $key (@keys) {
  my $func = $self->can($key);
  my $result = $func ? $self->$func() : undef;
  push( @results, $result );
 }
 wantarray ? @results : $results[0];
}

########################################
# NG 05-12-09: changed to always call method. previous version just stored
#              value for class attributes.
# note: this is user level method -- not just internal!!!
sub set_attributes {
  my ( $self, $attributes, $args ) = @_;
  my $class=$self->class;
  $self->throw('Atrribute list must be an array ref') unless ref $attributes eq 'ARRAY';
  my @attributes=Class::AutoClass::Args::fix_keyword(@$attributes);
  for my $func (@attributes) {
    next unless exists $args->{$func} && $class->can($func);
    $self->$func( $args->{$func} );
  }
}

 ## NG 05-12-07: process defaults.  $defaults contains defaults seen so far in the
# #  recursive initialization process that are NOT in $args. As we descend, also
# #  have to check synonyms: 
# @keywords=$class->ATTRIBUTES_RECURSIVE;
# for my $func (@keywords) {
#   next unless exists $defaults->{$func};
#   my $code=$class->can($func);
#   next if $default2code->{$func} == $code;
#   $self->$func($defaults->{$func});
#   $default2code->{$func}=$code;
# }
## for my $func (keys %$defaults) {
##   next if !$class->can($func);
##   $self->$func($defaults->{$func});
##   delete $defaults->{$func};
## }
#}

## sets default attributes on a newly created instance
## NG 05-12-07: changed to accumulate defaults in $defaults.  setting done in set_attributes.
##              previous version set values directly into object HASH.  this is wrong, since 
##              it skips the important step of running the attribute's 'set' method.
#sub set_instance_defaults {
# my ( $self, $args, $defaults, $default2code, $class ) = @_;
# my %class_funcs;
# my $class_defaults = DEFAULTS($class);
# map { $class_funcs{$_}++ } CLASS_ATTRIBUTES($class);
# while ( my ( $key, $value ) = each %$class_defaults ) {
#   next if exists $class_funcs{$key} || exists $args->{$key};
#   $defaults->{$key} = ref $value? dclone($value): $value; # deep copy refs;
#   delete $default2code->{$key};	# NG 05-12-07: so new default will be set
# }
#}

########################################
# NG 05-12-09: rewrote to use CATTRIBUTES_RECURSIVE. also changed to always call 
#              method. previous version just stored values
# sets class defaults at "declare time"
sub set_class_defaults {
 my ( $class ) = @_;
 my $defaults = DEFAULTS_RECURSIVE($class); # Args object
 my %fixed_attributes=FIXED_ATTRIBUTES_RECURSIVE($class);
 my %cattributes=CATTRIBUTES_RECURSIVE($class);
 my @cattributes=keys %cattributes;
 for my $func (@cattributes) {	# class attributes
   my $fixed_func=$fixed_attributes{$func};
   next unless exists $defaults->{$fixed_func};
   my $value=$defaults->{$fixed_func};
   $value=ref $value? dclone($value): $value; # deep copy refs so each instance has own copy
   $class->$func($value);
 }
}
########################################
sub class { ref $_[0]; }

sub ISA {
 my ($class) = @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @{ $class . '::ISA' };
}

sub AUTO_ATTRIBUTES {
 my ($class) = @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @{ $class . '::AUTO_ATTRIBUTES' };
}

sub OTHER_ATTRIBUTES {
 my ($class) = @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @{ $class . '::OTHER_ATTRIBUTES' };
}

sub CLASS_ATTRIBUTES {
 my ($class) = @_;
 no strict 'refs';
 no warnings;                             # supress unitialized var warning
 @{ $class . '::CLASS_ATTRIBUTES' };
}

sub SYNONYMS {
 my ($class) = @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 %{ $class . '::SYNONYMS' };
}
sub SYNONYMS_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %synonyms;
 if (@_) {
   %synonyms=%{ $class . '::SYNONYMS_RECURSIVE' } = @_;
   my %reverse;
   while(my($syn,$real)=each %synonyms) {
     my $list=$reverse{$real} || ($reverse{$real}=[]);
     push(@$list,$syn);
   }
   SYNONYMS_REVERSE($class, %reverse);
 } else {
   %synonyms=%{ $class . '::SYNONYMS_RECURSIVE' };
 }
 wantarray? %synonyms: \%synonyms;
}
sub SYNONYMS_REVERSE {		# reverse of SYNONYMS_RECURSIVE. used to set instance defaults
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %synonyms=@_ ? %{ $class . '::SYNONYMS_REVERSE' } = @_: 
   %{ $class . '::SYNONYMS_REVERSE' };
 wantarray? %synonyms: \%synonyms;
}
# ATTRIBUTES -- all attributes
sub ATTRIBUTES {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my @attributes=@_ ? @{ $class . '::ATTRIBUTES' } = @_ : @{ $class . '::ATTRIBUTES' };
 wantarray? @attributes: \@attributes;
}
sub ATTRIBUTES_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 sub _uniq {my %h; @h{@_}=@_; values %h;}
 my @attributes=@_ ? @{ $class . '::ATTRIBUTES_RECURSIVE' } = _uniq(@_): 
   @{ $class . '::ATTRIBUTES_RECURSIVE' };
 wantarray? @attributes: \@attributes;
}
# maps attributes to fixed (ie, de-cased) attributes. use when initializing attributes
# to args or defauls
sub FIXED_ATTRIBUTES_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %attributes=@_ ? %{ $class . '::FIXED_ATTRIBUTES_RECURSIVE' } = @_:
   %{ $class . '::FIXED_ATTRIBUTES_RECURSIVE' };
 wantarray? %attributes: \%attributes;
}
# IATTRIBUTES -- instance attributes -- hash
sub IATTRIBUTES {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %attributes=@_ ? %{ $class . '::IATTRIBUTES' } = @_ : %{ $class . '::IATTRIBUTES' };
 wantarray? %attributes: \%attributes;
}
sub IATTRIBUTES_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %attributes=@_ ? %{ $class . '::IATTRIBUTES_RECURSIVE' } = @_:
   %{ $class . '::IATTRIBUTES_RECURSIVE' };
 wantarray? %attributes: \%attributes;
}
# CATTRIBUTES -- class attributes -- hash

# NG 05-12-08: commented out. DEFAULTS_ARGS renamed to DEFAULTS
#sub DEFAULTS {
# my ($class) = @_;
# $class = $class->class if ref $class;    # get class if called as object method
# no strict 'refs';
# %{ $class . '::DEFAULTS' };
#}
sub CATTRIBUTES {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %attributes=@_ ? %{ $class . '::CATTRIBUTES' } = @_ : %{ $class . '::CATTRIBUTES' };
 wantarray? %attributes: \%attributes;
}
sub CATTRIBUTES_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my %attributes=@_ ? %{ $class . '::CATTRIBUTES_RECURSIVE' } = @_:
   %{ $class . '::CATTRIBUTES_RECURSIVE' };
 wantarray? %attributes: \%attributes;
}
# NG 05-12-08: DEFAULTS_ARGS renamed to DEFAULTS.  
#              incorporates logic to convert %DEFAULTS to Args object
sub DEFAULTS {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 ${ $class . '::DEFAULTS_ARGS' } or
  ${ $class . '::DEFAULTS_ARGS' } = new Class::AutoClass::Args(%{ $class . '::DEFAULTS' }); # convert DEFAULTS hash into AutoArgs
}
sub DEFAULTS_RECURSIVE {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 my $defaults=@_ ? ${ $class . '::DEFAULTS_RECURSIVE' } = $_[0]: 
   ${ $class . '::DEFAULTS_RECURSIVE' };
wantarray? %$defaults: $defaults;
}

sub AUTODB {
 my ($class) = @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 %{ $class . '::AUTODB' };
}

sub ANCESTORS {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @_ ? ${ $class . '::ANCESTORS' } = $_[0] : ${ $class . '::ANCESTORS' };
}

sub CAN_NEW {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @_ ? ${ $class . '::CAN_NEW' } = $_[0] : ${ $class . '::CAN_NEW' };
}

sub FORCE_NEW {
 my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 ${ $class . '::FORCE_NEW' };
}
sub DECLARED {			# set to 1 by declare. tested in new
  my $class = shift @_;
 $class = $class->class if ref $class;    # get class if called as object method
 no strict 'refs';
 @_ ? ${ $class . '::DECLARED' } = $_[0] : ${ $class . '::DECLARED' };
}

sub declare {
 my ( $class, $case ) = @_;

 ########################################
 # NG 05-12-08,09: added code to compute RECURSIVE values, IATTRIBUTES, CATTRIBUTES
 my @attributes_recursive;
 my %iattributes_recursive;
 my %cattributes_recursive;
 my %synonyms_recursive;
 my $defaults_recursive;
 # get info from superclasses.  recursively, this includes all ancestors
 for my $super (ISA($class)) {
   next if $super eq 'Class::AutoClass';
   ####################
   # NG 05-12-09: added check for super classes not yet used
   # Caution: this all works fine if people follow the Perl convention of
   #  placing module Foo in file Foo.pm.  Else, there's no easy way to
   #  translate a classname into a string that can be 'used'
   # The test 'unless %{$class.'::'}' cause the 'use' to be skipped if
   #  the class is already loaded.  This should reduce the opportunities
   #  for messing up the class-to-file translation.
   # Note that %{$super.'::'} is the symbol table for the class
   { no strict 'refs';
     unless (%{$super.'::'}) {
       eval "use $super";
       confess "'use $super' failed while declaring class $class. Note that class $super is listed in \@ISA for class $class, but is not explicitly used in the code.  We suggest, as a matter of coding style, that classes listed in \@ISA be explicitly used" if $@;
     }}
   next unless UNIVERSAL::isa($super,'Class::AutoClass');
   
   push(@attributes_recursive,ATTRIBUTES_RECURSIVE($super));
   my %h;
   %h=IATTRIBUTES_RECURSIVE($super);
   @iattributes_recursive{keys %h}=values %h;
   undef %h;
   %h=CATTRIBUTES_RECURSIVE($super);
   @cattributes_recursive{keys %h}=values %h;
   undef %h;
   %h=SYNONYMS_RECURSIVE($super);
   @synonyms_recursive{keys %h}=values %h;
   my $d=DEFAULTS_RECURSIVE($super);
   @$defaults_recursive{keys %$d}=values %$d;
 }

 # add info from self. do this after parents so our defaults, synonyms override parents
 # for IATTRIBUTES, don't add in any that are already defined, since this just creates 
#  redundant methods
 my %synonyms   = SYNONYMS($class);
 my %iattributes;
 my %cattributes;
 # init cattributes to declared CLASS_ATTRIBUTES
 map {$cattributes{$_}=$class} CLASS_ATTRIBUTES($class);
 # iattributes = all attributes that are not cattributes
 map {$iattributes{$_}=$class unless $iattributes_recursive{$_} || $cattributes{$_}}
   (AUTO_ATTRIBUTES($class),OTHER_ATTRIBUTES($class));
 # add in synonyms
 while(my($syn,$real)=each %synonyms) {
   confess "Inconsistent declaration for attribute $syn: both synonym and real attribute"
     if $cattributes{$syn} && $iattributes{$syn};
   $cattributes{$syn}=$class if $cattributes{$real} || $cattributes_recursive{$real};
   $iattributes{$syn}=$class if $iattributes{$real} || $iattributes_recursive{$real};
 }
 IATTRIBUTES($class,%iattributes);
 CATTRIBUTES($class,%cattributes);
 ATTRIBUTES($class,keys %iattributes,keys %cattributes);

 # store our attributes into recursives
 @iattributes_recursive{keys %iattributes}=values %iattributes;
 @cattributes_recursive{keys %cattributes}=values %cattributes;
 push(@attributes_recursive,keys %iattributes,keys %cattributes);
 # are all these declarations consistent?
 if (my @inconsistents=grep {exists $cattributes_recursive{$_}} keys %iattributes_recursive) {
   # inconsistent class vs. instance declarations
   my @errstr=("Inconsistent declarations for attribute(s) @inconsistents");
   map {
     push(@errstr,
	  "\tAttribute $_: declared instance attribute in $iattributes_recursive{$_}, class attribute in $cattributes_recursive{$_}");
   } @inconsistents;
   confess join("\n",@errstr);
 }
 # store our synonyms into recursive
 @synonyms_recursive{keys %synonyms}=values %synonyms;
 # store our defaults into recursive

 my $d=DEFAULTS($class);
 @$defaults_recursive{keys %$d}=values %$d;
 # store computed values into class
 ATTRIBUTES_RECURSIVE($class,@attributes_recursive);
 IATTRIBUTES_RECURSIVE($class,%iattributes_recursive);
 CATTRIBUTES_RECURSIVE($class,%cattributes_recursive);
 SYNONYMS_RECURSIVE($class,%synonyms_recursive);
 DEFAULTS_RECURSIVE($class,$defaults_recursive);

 # note that attributes are case sensitive, while defaults and args are not.
 # (this may be a crock, but it's documented this way). to deal with this, we build
 # a map from de-cased attributes to attributes. really, the map takes use from
 # id's as fixed by Args to attributes as they exist here
 my %fixed_attributes;
 my @fixed_attributes=Class::AutoClass::Args::fix_keywords(@attributes_recursive);
 @fixed_attributes{@attributes_recursive}=@fixed_attributes;
 FIXED_ATTRIBUTES_RECURSIVE($class,%fixed_attributes);

 ########################################

 # enumerate internal super-classes and find an external class to create object
 my %autodb     = AUTODB($class);
 if (%autodb) {    # hack ISA before setting ancestors
  no strict 'refs';

  # add AutoDB::Object to @ISA if necessary
  unless ( grep /^Class::AutoDB::Object/, @{ $class . '::ISA' } ) {
   unshift @{ $class . '::ISA' }, 'Class::AutoDB::Object';
  }
  require 'Class/AutoDB/Object.pm';
  require 'Class/AutoDB.pm';    # AutoDB.pm is needed for calling auto_register
 }
 my ( $ancestors, $can_new ) = _enumerate($class);
 ANCESTORS( $class, $ancestors );
 CAN_NEW( $class, $can_new );
# DEFAULTS_ARGS( $class, new Class::AutoClass::Args( DEFAULTS($class) ) ); # convert DEFAULTS hash into AutoArgs. NG 05-12-08: commented out since logic moved to DEFAULTS sub

 # NG 05-12-02: auto-register subclasses which do not set %AUTODB
 # if (%autodb) {               # register after setting ANCESTORS
 if (UNIVERSAL::isa($class,'Class::AutoDB::Object')) { # register after setting ANCESTORS
   require 'Class/AutoDB.pm';    # AutoDB.pm is needed for calling auto_register
   my $args = Class::AutoClass::Args->new( %autodb, -class => $class ); # TODO - spec says %AUTODB=(1) should work
  Class::AutoDB::auto_register($args);
 }

 ########################################
 # NG 05-12-09: changed loops to iterate separately over instance and class attributes.
 #              commented out code for AutoDB dispatch -- could never have run anyway
 #              since %keys never set.  also not longer compatible with new
 #              Registration format.
 # generate the methods
 
 my @auto_attributes=AUTO_ATTRIBUTES($class);
 undef %iattributes;
 %iattributes=IATTRIBUTES($class);
 my @iattributes=grep {$iattributes{$_} && !exists $synonyms{$_}} @auto_attributes;
 my @class_attributes=(@auto_attributes,CLASS_ATTRIBUTES($class));
 my @cattributes=grep {$cattributes{$_} && !exists $synonyms{$_}} @class_attributes;

 for my $func (@iattributes) {
  my $fixed_func = Class::AutoClass::Args::fix_keyword($func);
  my $sub = '*' . $class . '::' . $func . "=sub{\@_>1?
             \$_[0]->{\'$fixed_func\'}=\$_[1]:
             \$_[0]->{\'$fixed_func\'};}";
  eval $sub;
  }
 for my $func (@cattributes) {
  my $fixed_func = Class::AutoClass::Args::fix_keyword($func);
  my $sub = '*' . $class . '::' . $func . "=sub{\@_>1?
             \${$class\:\:$fixed_func\}=\$_[1]: 
             \${$class\:\:$fixed_func\};}";
  eval $sub;
  }
# NG 05-12-08: commented out.  $args was never set anyway...  This renders moot the
#              'then' clause of the 'if' below.  I left it in just in case I have to
#              revert the change :)
# TODO: eliminate 'then' clause if not needed
#  if ( $args and $args->{keys} ) {
#   %keys = map { split } split /,/, $args->{keys};
#  }
#  if ( $keys{$func} ) {         # AutoDB dispatch
#   $sub = '*' . $class . '::' . $func . "=sub{\@_>1?
#        \$_[0] . '::AUTOLOAD'->{\'$fixed_func\'}=\$_[1]: 
#        \$_[0] . '::AUTOLOAD'->{\'$fixed_func\'};}";
#  } else {
#   if ( exists $cattributes{$func} ) {
#    $sub = '*' . $class . '::' . $func . "=sub{\@_>1?
#              \${$class\:\:$fixed_func\}=\$_[1]: 
#              \${$class\:\:$fixed_func\};}";
#   } else {
#    $sub = '*' . $class . '::' . $func . "=sub{\@_>1?
#             \$_[0]->{\'$fixed_func\'}=\$_[1]:
#             \$_[0]->{\'$fixed_func\'};}";
#   }
#  }
#  eval $sub;
# }
 while ( my ( $func, $old_func ) = each %synonyms ) {
  next if $func eq $old_func;	# avoid redundant def if old same as new
#  my $class_defined=$iattributes_recursive{$old_func} || $cattributes_recursive{$old_func};
#  my $sub=
#    '*' . $class . '::' . $func . '=\& ' . $class_defined . '::' . $old_func;
  my $sub =
    '*' . $class . '::' . $func . "=sub {\$_[0]->$old_func(\@_[1..\$\#_])}";
  eval $sub;
 }
 if ( defined $case && $case =~ /lower|lc/i )
 {                # create lowercase versions of each method, too
  for my $func (@iattributes,@cattributes) {
   my $lc_func = lc $func;
   next
     if $lc_func eq $func;  # avoid redundant def if func already lowercase
  my $sub=
    '*' . $class . '::' . $lc_func . '=\& '. $class . '::' . $func;
#   my $sub =
#     '*' . $class . '::' . $lc_func . "=sub {\$_[0]->$func(\@_[1..\$\#_])}";
   eval $sub;
  }
 }
 if ( defined $case && $case =~ /upper|uc/i )
 {                          # create uppercase versions of each method, too
  for my $func (@iattributes,@cattributes) {
   my $uc_func = uc $func;
   next
     if $uc_func eq $func;  # avoid redundant def if func already uppercase
  my $sub=
    '*' . $class . '::' . $uc_func . '=\& '. $class . '::' . $func;
#   my $sub =
#     '*' . $class . '::' . $uc_func . "=sub {\$_[0]->$func(\@_[1..\$\#_])}";
   eval $sub;
  }
 }
 # NG 05-12-08: removed $args from parameter list
 # NG 05-12-09: converted call from method ($class->...) to function. removed eval that 
 #              wrappped call. provided regression test for class that does not inherit 
 #              from AutoClass
 set_class_defaults($class);
 DECLARED($class,1);		# NG 06-02-03: so 'new' can know when to call declare
}

sub _enumerate {
 my ($class) = @_;
 my $classes = [];
 my $types   = {};
 my $can_new;
 __enumerate( $classes, $types, \$can_new, $class );
 return ( $classes, $can_new );
}

sub __enumerate {
 no warnings;
 my ( $classes, $types, $can_new, $class ) = @_;
 die "Circular inheritance structure. \$class=$class"
   if ( $types->{$class} eq 'pending' );
 return $types->{$class} if defined $types->{$class};
 $types->{$class} = 'pending';
 my @isa;
 {
  no strict "refs";
  @isa = @{ $class . '::ISA' };
 }
 my $type = 'external';
 for my $super (@isa) {
  $type = 'internal', next if $super eq $AUTOCLASS;
  my $super_type = __enumerate( $classes, $types, $can_new, $super );
  $type = $super_type unless $type eq 'internal';
 }
 if ( !FORCE_NEW($class) && !$$can_new && $type eq 'internal' ) {
  for my $super (@isa) {
   next unless $types->{$super} eq 'external';
   $$can_new = $super, last if $super->can('new');
  }
 }
 push( @$classes, $class ) if $type eq 'internal';
 $types->{$class} = $type;
 return $types->{$class};
}

sub _is_positional {
 @_ % 2 || $_[0] !~ /^-/;
}
1;
__END__

# Pod documentation

    =head1 NAME

Class::AutoClass - Automatically define simple get and set methods and
    automatically initialize objects in a (possibly mulitple) inheritance
    structure

    =head1 SYNOPSIS

    package SubClass;
use Class::AutoClass;
use SomeOtherClass;
@ISA=qw(AutoClass SomeOtherClass);

@AUTO_ATTRIBUTES=qw(name sex address dob);
@OTHER_ATTRIBUTES=qw(age);
%SYNONYMS=(gender=>'sex');
%DEFAULTS=(name=>'unknown');
$CASE='upper';
Class::AutoClass::declare(__PACKAGE__);

sub age {print "Calculate age from dob. NOT YET IMPLEMENTED\n"; undef}

sub _init_self {
    my($self,$class,$args)=@_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
    print __PACKAGE__.'::_init_self: ',"$class\n";
}

=head1 DESCRIPTION

    1) get and set methods for simple attributes can be automatically
    generated

    2) argument lists are handled as described below

    3) the protocol for object creation and initialization is close to
    the 'textbook' approach generally suggested for object-oriented Perl
    (see below)

    4) object initialization is handled correctly in the presence of multiple inheritance

    @AUTO_ATTRIBUTES is a list of 'attribute' names: get and set methods
    are created for each attribute.  By default, the name of the method
    is identical to the attribute (but see $CASE below).  Values of
    attributes can be set via the 'new' constructor, %DEFAULTS, or the 
    'set' method as discussed below.

    @CLASS_ATTRIBUTES is a list of class attributes: get and set methods
    are created for each attribute. By default, the name of the method
    is identical to the attribute (but see $CASE below). Values of
    attributes can be set via the 'new' constructor, %DEFAULTS (initialized 
    at "declare time" (when the declare function is called) versus instance
    attributes, which are of course initialized at runtime), standard 
    class variable access syntax ($PackageName::AttributeName), or the 
    'set' method as discussed below. Normal inheritance rules apply to
    class attributes (but of course, instances of the same class share
	the same class variable).

    @OTHER_ATTRIBUTES is a list of attributes for which get and set
    methods are NOT generated, but whose values can be set via the 'new'
    constructor or the 'set' method as discussed below.

    %SYNONYMS is a hash that defines synonyms for attribues. Each entry
    is of the form 'new_attribute_name'=>'old_attribute_name'. get and
    set methods are generated for the new names; these methods simply
    call the method for the old name.
    
    %DEFAULTS is a hash that defines default values for attributes. Each 
    entry is of the form 'attribute_name'=>'default_value'. get and
    set methods are generated for each attributes.

    $CASE controls whether additional methods are generated with all
    upper or all lower case names.  It should be a string containing the
    strings 'upper' or 'lower' (case insenstive) if the desired case is
    desired.

    The declare function actually generates the method.
    This should be called once and no where else.

    AutoClass must be the first class in @ISA !! As usual, you create
    objects by calling 'new'. Since AutoClass is the first class in @ISA,
    it's 'new' method is the one that's called.  AutoClass's 'new'
examines the rest of @ISA and searches for a superclass that is
capable of creating the object.  If no such superclass is found,
AutoClass creates the object itself.  Once the object is created,
AutoClass arranges to have all subclasses run their initialization
methods (_init_self) in a top-down order.

=head2 Argument Processing

We support positional and keyword argument lists, but we strongly urge 
that each method pick one form or the other, as the combination is inherently ambiguous (see below).

Consider a method, foo, that takes two arguments, a first name and a
last_name name.  The positional form might be

  $object->foo('Nat', 'Goodman')

while the keyword form might be

  $object->foo(first_name=>'Nat', last_name=>'Goodman')

In keyword form, keywords are insensitive to case and leading
dashes: the keywords

  first_name, -first_name, -FIRST_NAME, --FIRST_NAME, First_Name, -First_Name

are all equivalent.  Internally, for those who care, our convention is
to use uppercase, un-dashed keys for the attributes of an object.

We convert repeated keyword arguments into an ARRAY ref of the values. Thus:

  $object->foo(first_name=>'Nat', first_name=>'Nathan')

is equivalent to

  $object->foo(first_name=>['Nat', 'Nathan'])

Keyword arguments can be specified via ARRAY or HASH
refs which are dereferenced back to their elements, e.g.,

  $object->foo([first_name=>'Nat', last_name=>'Goodman'])

  $object->foo({first_name=>'Nat', last_name=>'Goodman'})

are both equivalent to 

  $object->foo(first_name=>'Nat', last_name=>'Goodman')

We can get away with this, because we encourage method writers to
choose between positional and keyword argument lists.  If a method
uses positional arguments, it will interpret

  $object->foo($array)

as a call that is setting the first_name parameter to $array, while if
it uses keyword arguments, it will dereference the array to a list of
keyword, value pairs.

We also allow the argument list to be an object.  This is often used
in new to accomplish what a C++ programmer would call a cast.  In
simple cases, the object is just treated as a HASH ref and its
attributes are passed to a the method as keyword, value pairs.

=head2 Why the Combination of Positional and Keyword Forms is Ambiguous

The keyword => value notation is just a Perl shorthand for stating two
list members with the first one quoted.  Thus,

  $object->foo(first_name=>'Nat', last_name=>'Goodman')

is completely equivalent to 

  $object->foo('first_name', 'Nat', 'last_name', 'Goodman')

The ambiguity of allowing both positional and keyword forms should now
be apparent. In this example,

  $object->foo('first_name', 'Nat')

there is s no way to tell whether the program is calling foo with the
first_name parameter set to the value 'first_name' and the last_name
parameter set to 'Nat', vs. calling foo with the first_name parameter
set to 'Nat' and the last_name parameter left undefined.

If a program wishes to permit both forms, we suggest that keywords be 
required to start with '-' (and that values do not start with '-').  
Obviously, this is not fully general. We provide a method, _is_positional, 
that checks this convention. Subclasses are free to ignore this.

=head2 Protocol for Object Creation and Initializaton

We expect objects to be created by invoking new on its class.  For example

  $object = new SomeClass(first=>'Nat', last=>'Goodman')

To correctly initialize objects that participate in multiple inheritance, 
we use a technqiue described in Chapter 10 of Paul Fenwick's excellent 
    tutorial on Object Oriented Perl (see http://perltraining.com.au/notes/perloo.pdf).  
(We experimented with Damian Conway's interesting NEXT
pseudo-pseudo-class discussed in Chapter 11 of Fenwick's tutorial
 available in CPAN at http://search.cpan.org/author/DCONWAY/NEXT-0.50/lib/NEXT.pm, 
 but could not get it to traverse the inheritance structure in the correct,
 top-down order.)

    AutoClass class provides a 'new' method that expects a keyword argument
    list.  This method processes the argument list as discussed in
    L<Argument Processing>: it figures out the syntactic form (list of
							       keyword, value pairs, vs. ARRAY ref vs. HASH ref, etc.).  It then
    converts the argument list into a canonical form, which is a list of
    keyword, value pairs with all keywords uppercased and de-dashed.  Once
    the argument list is in this form, subsequent code treats it as a HASH
    ref.

AutoClass::new initializes the object's class structure from top to
bottom, and is careful to initialize each class exactly once even in
the presence of multiple inheritance.  The net effect is that objects
are initialized top-down as expected; a subclass object can assume
that all superior classes are initialized by the time subclass
initialization occurs.

AutoClass automatically initializes attributes and synonyms declared
when the class is defined.  If additional initialization is required,
the class writer can provide an _init_self method.  _init_self is
called after all superclasses are initialized and after the automatic
initialization for the class has been done.

AutoClass initializes attributes and synonyms by calling the set methods
for these elements with the like-named parameter -- it does not simply
slam the parameter into a slot in the object''s HASH.  This allows the
class writer implement non-standard initialization within the set
method.

The main case where a subclass needs its own 'new' method is if it
wishes to allow positional arguments. In this case, the subclass 'new'
is responsible for is responsible for recognizing that positional
arguments are being used (if the class permits keyword arguments
also), and converting the positional arguments into keyword, value
form.  At this point, the method can simply call AutoClass::new with
the converted argument list.

The subclass should not generally call SUPER::new as this would force
redundant argument processing in any super-class that also has its own
new.  It would also force the super-class new to be smart enough to
handle positional as well as keyword parameters, which as we've noted
    is inherently ambiguous.

    =head1 KNOWN BUGS AND CAVEATS

    This is still a work in progress.  

    =head2 Bugs, Caveats, and ToDos

    1) There is no way to manipulate the arguments that are sent to the
    real base class. There should be a way to specify a subroutine that
    reformats these if needed.

    2) DESTROY not handled

    3) Autogeneration of methods is hand crafted.  It may be better to
    use Class::MakeMethods or Damian Conway's Multimethod class for
  doing signature-based method dispatch
  
  4) Caveat: In order to specify that a class that uses AutoClass should return
  undef (versus an uninitialized (but blessed) object), one need to set:
  $self->{__NULLIFY__}=1;

=head1 AUTHOR - Nat Goodman

Email natg@shore.net

=head1 MAINTAINER - Christopher Cavnor

Email ccavnor@systemsbiology.net

=head1 COPYRIGHT

Copyright (c) 2003 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.  Note that
internal methods are preceded with _

=head2 new

 Title   : new
 Usage   : $object=new Foo(first_name=>'Nat', last_name=>'Goodman')
           where Foo is a subclass of AutoClass
 Function: Create and initialize object
 Returns : New object of class $class
 Args    : Any arguments needed by subclasses
         -->> Arguments must be in keyword form.  See DESCRIPTION for more.
 Notes   : Tries to invoke superclass to actually create the object


=head2 _init

 Title   : _init
 Usage   : $self->_init($class,$args)
 Function: Initialize new object
 Returns : nothing useful
 Args    : $class -- lexical (static) class being initialized, not the
           actual (dynamic) class of $self
           $arg -- argument list in canonical keyword form
 Notes   : Adapted from Chapter 10 of Paul Fenwick''s excellent tutorial on 
           Object Oriented Perl (see http://perltraining.com.au/notes/perloo.pdf).

=head2 set

 Title   : set
 Usage   : $self->set(-first_name=>'Nat',-last_name=>'Goodman')
 Function: Set multiple attributes in existing object
 Args    : Parameter list in same format as for new
 Returns : nothing

=head2 set_attributes

 Title   : set_attributes
 Usage   : $self->set_attributes([qw(first_name last_name)],$args)
 Function: Set multiple attributes from a Class::AutoClass::Args object
           Any attribute value that is present in $args is set
 Args    : ARRAY ref of attributes
           Class::AutoClass::Args object
 Returns : nothing

=head2 get

 Title   : get
 Usage   : ($first,$last)=$self->get(qw(-first_name,-last_name))
 Function: Get values for multiple attributes
 Args    : Attribute names
 Returns : List of attribute values

=head2 AUTO_ATTRIBUTES

 Title   : AUTO_ATTRIBUTES
 Usage   : @auto_attributes=AUTO_ATTRIBUTES('SubClass')
           @auto_attributes=$self->AUTO_ATTRIBUTES();
 Function: Get @AUTO_ATTRIBUTES for lexical class.
           @AUTO_ATTRIBUTES is defined by class writer. These are attributes for which get and set methods
           are automatically generated.  _init automatically
           initializes these attributes from like-named parameters in
           the argument list
 Args : class

=head2 OTHER_ATTRIBUTES

 Title   : OTHER_ATTRIBUTES
 Usage   : @other_attributes=OTHER_ATTRIBUTES('SubClass')
           @other_attributes=$self->OTHER_ATTRIBUTES();
 Function: Get @OTHER_ATTRIBUTES for lexical class.
           @OTHER_ATTRIBUTES is defined by class writer. These are attributes for which get and set methods
           are not automatically generated.  _init automatically
           initializes these attributes from like-named parameters in
           the argument list
 Args : class

=head2 SYNONYMS

 Title   : SYNONYMS
 Usage   : %synonyms=SYNONYMS('SubClass')
           %synonyms=$self->SYNONYMS();
 Function: Get %SYNONYMS for lexical class.
           %SYNONYMS is defined by class writer. These are alternate names for attributes generally
           defined in superclasses.  get and set methods are
           automatically generated.  _init automatically initializes
           these attributes from like-named parameters in the argument
           list
 Args : class

=head2 declare

 Title   : declare
 Usage   : @AUTO_ATTRIBUTES=qw(sex address dob);
           @OTHER_ATTRIBUTES=qw(age);
           %SYNONYMS=(name=>'id');
	       AutoClass::declare(__PACKAGE__,'lower|upper');
 Function: Generate get and set methods for simple attributes and synonyms.
           Method names are identical to the attribute names including case
 Returns : nothing
 Args    : lexical class being created -- should always be __PACKAGE__
           ARRAY ref of attributes
           HASH ref of synonyms. Keys are new names, values are old
           code that indicates whether method should also be generated
            with all lower or upper case names
            
=head2 _enumerate

 Title   : _enumerate
 Usage   : _enumerate($class);
 Function: locates classes that have a callable constructor
 Args    : a class reference
 Returns : list of internal classes, a class with a callable constructor 


=head2 _fix_args

 Title   : _fix_args
 Usage   : $args=_fix_args(-name=>'Nat',-name=>Goodman,address=>'Seattle')
           $args=$self->_fix_args(@args)

 Function: Convert argument list into canonical form.  This is a HASH ref in 
           which keys are uppercase with no leading dash, and repeated
           keyword arguments are merged into an ARRAY ref.  In the
           example above, the argument list would be converted to this
           hash
              (NAME=>['Nat', 'Goodman'],ADDRESS=>'Seattle')
 Returns : argument list in canonical form
 Args    : argument list in any keyword form

=head2 _fix_keyword

 Title   : _fix_keyword
 Usage   : $keyword=_fix_keyword('-name')
           @keywords=_fix_keyword('-name','-address');
 Function: Convert a keyword or list of keywords into canonical form. This
           is uppercase with no leading dash.  In the example above,
           '-name' would be converted to 'NAME'. Non-scalars are left
           unchanged.
 Returns : keyword or list of keywords in canonical form 
 Args : keyword or list of keywords

=head2 _set_attributes

 Title   : _set_attributes
 Usage   :   my %synonyms=SYNONYMS($class);
             my $attributes=[AUTO_ATTRIBUTES($class),
			     OTHER_ATTRIBUTES($class),
			     keys %synonyms];
             $self->_set_attributes($attributes,$args);
 Function: Set a list of simple attributes from a canonical argument list
 Returns : nothing
 Args    : $attributes -- ARRAY ref of attributes to be set
           $args -- argument list in canonical keyword (hash) form 
 Notes   : The function calls the set method for each attribute passing 
           it the like-named parameter from the argument list

=head2 _is_positional

 Title   : _is_positional
 Usage  : if (_is_positional(@args)) {
             ($arg1,$arg2,$arg3)=@args; 
	   }
 Function: Checks whether an argument list conforms to our convention 
           for positional arguments. The function returns true if 
           (1) the argument list has an odd number of elements, or
           (2) the first argument starts with a dash ('-').
           Obviously, this is not fully general.
 Returns : boolean
 Args    : argument list
 Notes   : As explained in DESCRIPTION, we recommend that methods not 
           support both positional and keyford argument lists, as this 
           is inherently ambiguous.
 BUGS    : NOT YET TESTED in this version
 
=head2 set_class_defaults

 Title   : set_class_defaults
 Usage   : $self->set_class_defaults($attributes,$class,$args);
 Function: Set default values for class argument
 Args    : reference to the class and a Class::AutoClass::Args object
           which contains the arguments to set
 Returns : nothing

=cut

