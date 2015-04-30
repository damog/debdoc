package Debian::Debdoc::GetOptsOO;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.1_01';

sub getopts {
  my($target, $args, $truth) = @_;

  $args ||= \@ARGV;

  return unless @$args;

  $truth = 1 unless @_ > 2;

  my $error_count = 0;

  while( @$args  and  ($_ = $args->[0]) =~ m/^-(.)(.*)/s ) {
    my($first,$rest) = ($1,$2);
    if ($_ eq '--') {   # early exit if "--"
      shift @$args;
      last;
    }
    if ($first eq '-' and $rest) {      # GNU style long param names
      ($first, $rest) = split '=', $rest, 2;
    }
    my $method = "opt_${first}_with";
    if( $target->can($method) ) {  # it's argumental
      if($rest eq '') {   # like -f bar
        shift @$args;
        $target->warn( "Option $first needs a following argument!\n" ) unless @$args;
        $rest = shift @$args;
      } else {            # like -fbar  (== -f bar)
        shift @$args;
      }

      $target->$method( $rest );

    # Otherwise, it's not argumental...
    } else {

      if( $target->can( $method = "opt_$first" ) ) {
        $target->$method( $truth );

      # Otherwise it's an unknown option...

      } elsif( $target->can('handle_unknown_option') ) {

        $error_count += (
          $target->handle_unknown_option( $first ) || 0
        );

      } else {
        ++$error_count;
        $target->warn( "Unknown option: $first\n" );
      }

      if($rest eq '') {   # like -f
        shift @$args
      } else {            # like -fbar  (== -f -bar )
        $args->[0] = "-$rest";
      }
    }
  }

  $error_count == 0;
}

1;

