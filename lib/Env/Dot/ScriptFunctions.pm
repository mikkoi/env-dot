## no critic (ValuesAndExpressions::ProhibitConstantPragma)
package Env::Dot::ScriptFunctions;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(
  convert_variables_into_commands
);
our %EXPORT_TAGS = ( 'all' => [qw( convert_variables_into_commands )], );

use English qw( -no_match_vars );    # Avoids regex performance penalty in perl 5.18 and earlier
use Carp;

# ABSTRACT: Read environment variables from .env file

our $VERSION = '0.019';

use constant {
    OPTION_FILE_TYPE         => q{file:type},
    OPTION_FILE_TYPE_PLAIN   => q{plain},
    OPTION_FILE_TYPE_SHELL   => q{shell},
    DEFAULT_OPTION_FILE_TYPE => q{shell},
};

my %DOTENV_OPTIONS = (
    'file:type'             => 1,
    'var:allow_interpolate' => 1,
);

my %VAR_OUTPUT = (
    q{sh}   => \&_convert_var_to_sh,
    q{csh}  => \&_convert_var_to_csh,
    q{fish} => \&_convert_var_to_fish,
);

=pod

=for stopwords envdot env

=head1 STATUS

This module is currently being developed so changes in the API are possible,
though not likely.


=head1 SYNOPSIS

    use Env::Dot::ScriptFunctions qw( convert_variables_into_commands );

=head1 DESCRIPTION

This package just contains functions for use
in the main package L<Env::Dot> and in
the command line tool B<envdot>.

=head1 FUNCTIONS

No functions are automatically exported to the calling namespace.

=head2 convert_variables_into_commands()

# Return all variables from the F<.env> file
# as a list of hashes (name/value pairs).
# This list is created in the same order the variables
# are read from the files and may therefore contain
# the same variable several times.

=cut

sub convert_variables_into_commands {
    my ( $shell, @vars ) = @_;
    my $out = q{};
    foreach my $var (@vars) {
        $out .= _convert_variable( $shell, $var );
        $out .= "\n";
    }
    return $out;
}

# Private subroutines

sub _convert_variable {
    my ( $shell, $var ) = @_;
    if ( exists $VAR_OUTPUT{$shell} ) {
        return &{ $VAR_OUTPUT{$shell} }($var);
    }
    else {
        croak "Unknown shell: $shell";
    }
}

sub _convert_var_to_sh {
    my ($var) = @_;
    my ( $name, $value, $want_export, $allow_interpolate ) =
      ( $var->{'name'}, $var->{'value'}, $var->{'opts'}->{'export'}, $var->{'opts'}->{'allow_interpolate'}, );
    my $quote = $allow_interpolate ? q{"} : q{'};
    if ($want_export) {
        return sprintf "%s=$quote%s$quote; export %s", $name, $value, $name;
    }
    else {
        return sprintf "%s=$quote%s$quote", $name, $value;
    }
}

sub _convert_var_to_csh {
    my ($var) = @_;
    my ( $name, $value, $want_export, $allow_interpolate ) =
      ( $var->{'name'}, $var->{'value'}, $var->{'opts'}->{'export'}, $var->{'opts'}->{'allow_interpolate'}, );
    my $quote = $allow_interpolate ? q{"} : q{'};
    if ($want_export) {
        return sprintf "setenv %s $quote%s$quote", $name, $value;
    }
    else {
        return sprintf "set %s $quote%s$quote", $name, $value;
    }
}

sub _convert_var_to_fish {
    my ($var) = @_;
    my ( $name, $value, $want_export, $allow_interpolate ) =
      ( $var->{'name'}, $var->{'value'}, $var->{'opts'}->{'export'}, $var->{'opts'}->{'allow_interpolate'}, );
    my $quote = $allow_interpolate ? q{"} : q{'};
    return sprintf "set -e %s; set -x -U %s $quote%s$quote", $name, $name, $value;
}

1;
