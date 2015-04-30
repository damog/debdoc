package Debian::Debdoc;

use strict;
use warnings;

use Config '%Config';
use File::Basename qw(basename);
use vars qw!@Pagers $Bindir $VERSION!;
use Debian::Debdoc::GetOptsOO;

$VERSION = '0.1_01';

{
    my $pager = $Config{'pager'};
    push @Pagers, $pager if -x (split /\s+/, $pager)[0] or __PACKAGE__->is_vms;
}

sub run {
    my $class = shift;
    return $class->new(@_)->process() || 0;
}

sub new {
    my $class = shift;
    my $new = bless {@_}, (ref($class) || $class);
    $new->init();
    $new;
}

sub init {
    my $self = shift;

    # Make sure creat()s are neither too much nor too little
    eval { umask(0077) };   # doubtless someone has no mask

    $self->{'args'}              ||= \@ARGV;
    $self->{'found'}             ||= [];
    $self->{'temp_file_list'}    ||= [];


    $self->{'target'} = undef;

    $self->init_formatter_class_list;

    $self->{'pagers' } = [@Pagers] unless exists $self->{'pagers'};
    $self->{'bindir' } = $Bindir   unless exists $self->{'bindir'};
    $self->{'search_path'} = [ ]   unless exists $self->{'search_path'};

    push @{ $self->{'formatter_switches'} = [] }, (
        # Yeah, we could use a hashref, but maybe there's some class where options
        # have to be ordered; so we'll use an arrayref.

        [ '__bindir'  => $self->{'bindir' } ],
    );

    $self->{'translators'} = [];
    $self->{'extra_search_dirs'} = [];

    return;
}

sub init_formatter_class_list {
    my $self = shift;
    $self->{'formatter_classes'} ||= [];
    
    # XXX: profit

    return;
}

sub process {
    my $self = shift;

    return $self->usage_brief  unless  @{ $self->{'args'} };
    $self->options_reading;
    $self->pagers_guessing;
    $self->aside(sprintf "$0 => %s v%s\n", ref($self), $self->VERSION);
    $self->drop_privs_maybe unless $self->opt_U;
    $self->options_processing;

    # Hm, we have @pages and @found, but we only really act on one
    # file per call, with the exception of the opt_q hack, and with
    # -l things

    $self->aside("\n");

    my @pages;
    $self->{'pages'} = \@pages;
    if(    $self->opt_f) { @pages = qw(perlfunc perlop)        }
    elsif( $self->opt_q) { @pages = ("perlfaq1" .. "perlfaq9") }
    elsif( $self->opt_v) { @pages = ("perlvar")                }
    elsif( $self->opt_a) { @pages = ("perlapi")                }
    else                 { @pages = @{$self->{'args'}};
                           # @pages = __FILE__
                           #  if @pages == 1 and $pages[0] eq 'perldoc';
                         }

    return $self->usage_brief  unless  @pages;

    $self->find_good_formatter_class();
    $self->formatter_sanity_check();

    $self->maybe_extend_searchpath();
      # for when we're apparently in a module or extension directory

    my @found = $self->grand_search_init(\@pages);
    exit ($self->is_vms ? 98962 : 1) unless @found;

    if ($self->opt_l and not $self->opt_q ) {
        print join("\n", @found), "\n";
        return;
    }

    $self->tweak_found_pathnames(\@found);
    $self->assert_closing_stdout;
    return $self->page_module_file(@found)  if  $self->opt_m;

    return $self->render_and_page(\@found);
}

sub options_reading {
    my $self = shift;

    Debian::Debdoc::GetOptsOO::getopts( $self, $self->{'args'}, 'YES' )
     or return $self->usage;

    return $self->usage if $self->opt_h;

    return;
}

sub usage_brief {
    my $self = shift;
    my $program_name = $self->program_name;

    CORE::die( <<"EOUSAGE" );
Usage: $program_name [-h] package_name

Examples:

    $program_name -q faq_keywords
    $program_name package_name

The -h option prints more help.  Also try "$program_name debdoc" to get
acquainted with the system.                        [debdoc v$VERSION]

EOUSAGE

}

sub program_name {
    my( $self ) = @_;

    if( my $link = readlink( $0 ) ) {
        $self->debug( "The value in $0 is a symbolic link to $link\n" );
    }

    my $basename = basename( $0 );

    return $basename;

}

1;

