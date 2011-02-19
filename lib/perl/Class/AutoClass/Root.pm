package Class::AutoClass::Root;
use strict;

=head1 NAME

Class::AutoClass::Root

=head1 SYNOPSIS
  # Here's how to throw and catch an exception using the eval-based syntax.

  $obj->throw("This is an exception");

  eval {
      $obj->throw("This is catching an exception");
  };

  if( $@ ) {
      print "Caught exception";
  } else {
      print "no exception";
  }

=head1 DESCRIPTION
This class provides some basic functionality for Class::* classes.

This package is borrowed from bioperl project (http://bioperl.org/). Because of the 
formidable size of the bioperl library, Root.pm is included here with modifications.
These modifications were to pare its functioanlity down for its simple job here
(removing routines that are out of context and removing references to bioperl to avoid confusion).

Functions originally from Steve Chervitz of bioperl. Refactored by Ewan
Birney of bioperl. Re-refactored by Lincoln Stein of bioperl.

=head2 Throwing Exceptions

One of the functionalities that Class::AutoClass::Root provides is the
ability to throw() exceptions with pretty stack traces.

=head1 CONTACT

contact: Chris Cavnor -> ccavnor@systemsbiology.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

#'

use vars qw(@ISA $DEBUG $ID $Revision $VERSION $VERBOSITY $ERRORLOADED @EXPORT);
use strict;

BEGIN { 

    $ID        = 'Class::AutoClass::Root';
    $VERSION   = 1.0;
    $Revision  = '';
    $DEBUG     = 0;
    $VERBOSITY = 0;
    $ERRORLOADED = 0;
}



=head2 new

 Purpose   : generic instantiation function can be overridden if 
             special needs of a module cannot be done in _initialize

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, ref($class) || $class;

    if(@_ > 1) {
	# if the number of arguments is odd but at least 3, we'll give
	# it a try to find -verbose
	shift if @_ % 2;
	my %param = @_;
	$self->verbose($param{'-VERBOSE'} || $param{'-verbose'});
    }
    return $self;
}
		     
=head2 verbose

 Title   : verbose
 Usage   : $self->verbose(1)
 Function: Sets verbose level for how ->warn behaves
           -1 = no warning
            0 = standard, small warning
            1 = warning with stack trace
            2 = warning becomes throw
 Returns : The current verbosity setting (integer between -1 to 2)
 Args    : -1,0,1 or 2


=cut

sub verbose {
   my ($self,$value) = @_;
   # allow one to set global verbosity flag
   return $DEBUG  if $DEBUG;
   return $VERBOSITY unless ref $self;
   
    if (defined $value || ! defined $self->{'_root_verbose'}) {
       $self->{'_root_verbose'} = $value || 0;
    }
    return $self->{'_root_verbose'};
}

sub _register_for_cleanup {
  my ($self,$method) = @_;
  if($method) {
    if(! exists($self->{'_root_cleanup_methods'})) {
      $self->{'_root_cleanup_methods'} = [];
    }
    push(@{$self->{'_root_cleanup_methods'}},$method);
  }
}

sub _unregister_for_cleanup {
  my ($self,$method) = @_;
  my @methods = grep {$_ ne $method} $self->_cleanup_methods;
  $self->{'_root_cleanup_methods'} = \@methods;
}


sub _cleanup_methods {
  my $self = shift;
  return unless ref $self && $self->isa('HASH');
  my $methods = $self->{'_root_cleanup_methods'} or return;
  @$methods;

}

=head2 throw

 Title   : throw
 Usage   : $obj->throw("throwing exception message")
 Function: Throws an exception, which, if not caught with an eval brace
           will provide a nice stack trace to STDERR with the message
 Returns : nothing
 Args    : A string giving a descriptive error message


=cut

sub throw{
   my ($self,$string) = @_;

   my $std = $self->_stack_trace_dump();

   my $out = "\n-------------------- EXCEPTION --------------------\n".
       "MSG: ".$string."\n".$std."-------------------------------------------\n";
   die $out;

}

=head2 stack_trace

 Title   : stack_trace
 Usage   : @stack_array_ref= $self->stack_trace
 Function: gives an array to a reference of arrays with stack trace info
           each coming from the caller(stack_number) call
 Returns : array containing a reference of arrays
 Args    : none


=cut

sub stack_trace{
   my ($self) = @_;

   my $i = 0;
   my @out;
   my $prev;
   while( my @call = caller($i++)) {
       # major annoyance that caller puts caller context as
       # function name. Hence some monkeying around...
       $prev->[3] = $call[3];
       push(@out,$prev);
       $prev = \@call;
   }
   $prev->[3] = 'toplevel';
   push(@out,$prev);
   return @out;
}

=head2 _stack_trace_dump

 Title   : _stack_trace_dump
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _stack_trace_dump{
   my ($self) = @_;

   my @stack = $self->stack_trace();

   shift @stack;
   shift @stack;
   shift @stack;

   my $out;
   my ($module,$function,$file,$position);
   

   foreach my $stack ( @stack) {
       ($module,$file,$position,$function) = @{$stack};
       $out .= "STACK $function $file:$position\n";
   }

   return $out;
}


=head2 deprecated

 Title   : deprecated
 Usage   : $obj->deprecated("Method X is deprecated");
 Function: Prints a message about deprecation 
           unless verbose is < 0 (which means be quiet)
 Returns : none
 Args    : Message string to print to STDERR

=cut

sub deprecated{
   my ($self,$msg) = @_;
   if( $self->verbose >= 0 ) { 
       print STDERR $msg, "\n", $self->_stack_trace_dump;
   }
}

=head2 warn

 Title   : warn
 Usage   : $object->warn("Warning message");
 Function: Places a warning. What happens now is down to the
           verbosity of the object  (value of $obj->verbose) 
            verbosity 0 or not set => small warning
            verbosity -1 => no warning
            verbosity 1 => warning with stack trace
            verbosity 2 => converts warnings into throw
 Example :
 Returns : 
 Args    :

=cut

sub warn{
    my ($self,$string) = @_;
    
    my $verbose;
    if( $self->can('verbose') ) {
	$verbose = $self->verbose;
    } else {
	$verbose = 0;
    }

    if( $verbose == 2 ) {
	$self->throw($string);
    } elsif( $verbose == -1 ) {
	return;
    } elsif( $verbose == 1 ) {
	my $out = "\n-------------------- WARNING ---------------------\n".
		"MSG: ".$string."\n";
	$out .= $self->_stack_trace_dump;
	
	print STDERR $out;
	return;
    }    

    my $out = "\n-------------------- WARNING ---------------------\n".
       "MSG: ".$string."\n".
	   "---------------------------------------------------\n";
    print STDERR $out;
}

=head2 debug

 Title   : debug
 Usage   : $obj->debug("This is debugging output");
 Function: Prints a debugging message when verbose is > 0
 Returns : none
 Args    : message string(s) to print to STDERR

=cut

sub debug{
   my ($self,@msgs) = @_;
   
   if( $self->verbose > 0 ) { 
       print STDERR join("", @msgs);
   }   
}

sub DESTROY {
    my $self = shift;
    my @cleanup_methods = $self->_cleanup_methods or return;
    for my $method (@cleanup_methods) {
      $method->($self);
    }
}



1;

