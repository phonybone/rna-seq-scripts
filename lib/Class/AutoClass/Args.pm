package Class::AutoClass::Args;
use strict;
use Carp;

sub new {
  my($class,@args)=@_;
  $class=(ref $class)||$class;
  my $self=bless _fix_args(@args), $class;
}
sub get_args {
  my($self,@args)=@_;
  @args=@{$args[0]} if @args==1 && 'ARRAY' eq ref $args[0];
  @args=fix_keyword(@args);
  my @results=map {$self->{$_}} @args;
  wantarray? @results: $results[0];
}
sub getall_args {
  my $self = shift;
  wantarray? %$self: {%$self};
}
sub set_args {
  my($self,@args)=@_;
  my $args=_fix_args(@args);
  while(my($key,$value)=each %$args) {
    $self->$key($value);
  }
}
sub fix_keyword {
  my @keywords=@_;		# copies input, so update-in-place doesn't munge it
  for my $keyword (@keywords) {
    next unless defined $keyword;
    $keyword=~s/^-*(.*)$/\L$1/ unless ref $keyword; # updates in place
  }
  wantarray? @keywords: $keywords[0];
}
sub fix_keywords {fix_keyword(@_);}
sub is_keyword {!(@_%2) && $_[0]=~/^-/;}
sub is_positional {@_%2 || $_[0]!~/^-/;}

sub _fix_args {
  no warnings;
  my(@args)=@_;
  @args=@{$args[0]} if @args==1 && 'ARRAY' eq ref $args[0];
  @args=%{$args[0]} if @args==1 && 'HASH' eq ref $args[0];
  @args=%{$args[0]} if @args==1 && $args[0]=~/HASH/; # treat object like HASH
  confess("Malformed keyword argument list (odd number of elements): @args") if @args%2;
  my $args={};
  my %counts;
  while(@args) {
    my($keyword,$value)=(fix_keyword(shift @args),shift @args);
    $args->{$keyword}=$value if $counts{$keyword}==0;
    $args->{$keyword}=[$args->{$keyword},$value] if $counts{$keyword}==1;
    push(@{$args->{$keyword}},$value) if $counts{$keyword}>1;
    $counts{$keyword}++;
  }
  $args;
}
use vars qw($AUTOLOAD);
sub AUTOLOAD {
  my $self=shift;
  $AUTOLOAD=~s/^.*:://;		    # strip class qualification
  return if $AUTOLOAD eq 'DESTROY'; # the books say you should do this
  my $keyword=fix_keyword($AUTOLOAD);
  return if @_==0 && !exists $self->{$keyword};
  my $result;
  return $self->{$keyword} if @_==0;
  return $self->{$keyword}=$_[0] if @_==1;
  return $self->{$keyword}=[@_] if @_>1;
}

1;

__END__
=head1 NAME

AutoArgs - Argument list processing

=head1 SYNOPSIS

  use Class::AutoClass::Args;
  my $args=new Class::AutoClass::Args(name=>'Joe',-sex=>'male',
                                      HOBBIES=>'hiking',hobbies=>'cooking');

  # access argument values as HASH slots
  my $name=$args->{name};
  my $sex=$args->{sex};
  my $hobbies=$args->{hobbies};

  # access argument values via methods
  my $name=$args->name;
  my $sex=$args->sex;
  my $hobbies=$args->hobbies;

  # set local variables from argument values -- two equivalent ways
  my($name,$sex,$hobbies)=$args->get_args(qw(name sex hobbies));
  my($name,$sex,$hobbies)=@$args{qw(name sex hobbies)}

=head1 DESCRIPTION

This class simplifies the handling of keyword argument lists.

The 'new' method accepts an array, ARRAY, or HASH of keyword=>value
pairs. It normalizes the keywords to ignore case and leading dashes
('-').  In other words, the following keywords are all equivalent:

  first_name, -first_name, -FIRST_NAME, --FIRST_NAME, First_Name,
  -First_Name

Internally  we convert keywords to lowercase with no leading dash.

Repeated keyword arguments are converted into an ARRAY of the values.
Thus

 new Class::AutoClass::Args(first_name=>'Joe', first_name=>'Joseph')

is equivalent to

  new Class::AutoClass::Args(first_name=>['Joe', 'Joseph'])

Since argument lists can be provided as ARRAYs or HASHes, the following

   new Class::AutoClass::Args([first_name=>'John', last_name=>'Doe'])
   new Class::AutoClass::Args({first_name=>'John', last_name=>'Doe'})

are both equivalent to 

   new Class::AutoClass::Args(first_name=>'John', last_name=>'Doe')

=head1 KNOWN BUGS AND CAVEATS

This is still a work in progress.  

=head2 Bugs, Caveats, and ToDos

See caveats about accessing arguments via AUTOLOADed methods.

=head1 AUTHOR - Nat Goodman, Chris Cavnor

Email natg@shore.net

=head1 COPYRIGHT

Copyright (c) 2004 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.  Note that
internal methods are preceded with _

=head2 Constructors

 Title   : new
 Usage   : $args=new Class::AutoClass::Args
              (name=>'Joe',-sex=>'male',HOBBIES=>'hiking',hobbies=>'cooking')
           -- OR --
          $args=new Class::AutoClass::Args
              ([name=>'Joe',-sex=>'male',HOBBIES=>'hiking',hobbies=>'cooking'])
           -- OR --
          $args=new Class::AutoClass::Args
              ({name=>'Joe',-sex=>'male',HOBBIES=>'hiking',hobbies=>'cooking'})
 Function: Create a normalized argument list
 Returns : Class::AutoClass::Args object that represents the given arguments
 Args    : Argument list in keyword=>value form
           This can be an array (as in form 1 above).  This is the ususal case.
           Or it can be a single ARRAY or HASH as in forms 2 and 3

=head2 Getting and setting argument values from object

One simple way to get and set argument values is to treat the object
as a HASH and access the argument as a hash entry, eg,

$name=$args->{name};
$args->{name}='Joseph'.

While this approach is generally frowned upon in object-oriented
programming (because it breaks object encapsulation), we deem it to be
acceptable here since AutoArgs is such a lightweight class and its
very purpose is to _simplify_ access to argument lists.  Bear in mind
that the hash key you use must be normalized per our rules: lowercase
with no leading dashes.  The fix_keyword method is provided to
accomplish this if you need it.

A second simple approach is to invoke a method with the name of the
keyword.  Eg,

$args->name;
$args->name('Joseph');   # sets name to 'Joseph'

The method name is normalized exactly as in 'new'.

CAVEAT: The second approach uses AUTOLOAD to simulate the existence of
a method with the same name as the keyword.  This will not work if
AutoArgs contains a method with that name.  For example 'new'.  One
solution is to use uppercase names for methods.  Or you can use the
first approach and just access the data directly.

The class also provides two methods for wholesale manipulation of arguments.

 Title   : get_args
 Usage   : ($first,$last)=$args->get_args(qw(-first_name last_name))
 Function: Get values for multiple keywords
 Args    : array or ARRAY of keywords. These are normalized exactly as in 'new'
 Returns : array or ARRAY of attribute values

 Title   : set_args
 Usage   : $args->set_args(-first_name=>'John',-last_name=>'Doe')
 Function: Set multiple attributes in existing object
 Args    : Parameter list in same format as for 'new'
 Returns : nothing
 
  Title   : getall_args
 Usage   : %args=$args->get_args;
 Function: Get a list of all key,values
 Args    : none
 Returns : hash or HASH of key, value pairs.

 Title   : set_args
 Usage   : $args->set_args(-first_name=>'John',-last_name=>'Doe')
 Function: Set multiple attributes in existing object
 Args    : Parameter list in same format as for 'new'
 Returns : nothing

=head2 Methods to normalize keywords.  These are class methods

These methods normalize keywords as explained in the DESCRIPTION.  

 Title   : fix_keyword
 Usage   : $keyword=Class::AutoClass::Args::fix_keyword('-NaMe')
           -- OR --
           @keywords=Class::AutoClass::Args::fix_keyword('-NaMe','---sex');
 Function: Normalizes each keyword to lowercase with no leading dashes.
 Args    : array of one or more strings
 Returns : array of normalized strings

 Title   : fix_keywords
 Usage   : $keyword=Class::AutoClass::Args::fix_keywords('-NaMe')
           -- OR --
           @keywords=Class::AutoClass::Args::fix_keywords('-NaMe','---sex');
 Function: Synonym for fix_keyword
 Args    : array of one or more strings
 Returns : array of normalized strings

=head2 Methods to check format of argument list. These are class methods.

These following methods can be used in a class (typically it's 'new'
method) that wishes to support both keyword and positional argument
lists.  We strongly discourage this for the reasons discussed below.

 Title   : is_keyword
 Usage   : if (Class::AutoClass::Args::is_keyword(@args)) {
             $args=new Class::AutoClass::Args::is_keyword(@args);
	   }
 Function: Checks whether an argument list looks like it is in keyword form.
           The function returns true if 
           (1) the argument list has an even number of elements, and
           (2) the first argument starts with a dash ('-').
           Obviously, this is not fully general.
 Returns : boolean
 Args    : argument list as given

 Title   : is_positional
 Usage  : if (Class::AutoClass::Argsis_positional(@args)) {
             ($arg1,$arg2,$arg3)=@args; 
	   }
 Function: Checks whether an argument list looks like it is in positional form.
           The function returns true if 
           (1) the argument list has an odd number of elements, or
           (2) the first argument starts with a dash ('-').
           Obviously, this is not fully general.
 Returns : boolean
 Args    : argument list as given

=head2 Why the Combination of Positional and Keyword Forms is Ambiguous

The keyword => value notation is just a Perl shorthand for stating two
list members with the first one quoted.  Thus,

  @list=(first_name=>'John', last_name=>'Doe')

is completely equivalent to 

  @list=('first_name', 'John', 'last_name', 'Doe')

The ambiguity of allowing both positional and keyword forms should now
be apparent. In this example,

  new Class::AutoClass::Args ('first_name', 'John')

there is s no way to tell whether the program is specifying a keyword
argument list with the parameter 'first_name' set to the value "John'
or a positional argument list with the values ''first_name' and 'John'
being passed to the first two parameters.

If a program wishes to permit both forms, we suggest the convention
used in BioPerl that keywords be required to start with '-' (and that
values do not start with '-').  Obviously, this is not fully general.

The methods 'is_keyword' and 'is_positional' check  this convention.

=cut
