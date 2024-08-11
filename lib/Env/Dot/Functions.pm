## no critic (ValuesAndExpressions::ProhibitConstantPragma)
package Env::Dot::Functions;
use strict;
use warnings;
use Data::Dumper;

use Cwd qw( abs_path );
use File::Spec;

use Exporter 'import';
our @EXPORT_OK = qw(
    get_dotenv_vars
    interpret_dotenv_filepath_var
    get_envdot_filepaths_var_name
);
our %EXPORT_TAGS = (
    'all' => [
        qw(
            get_dotenv_vars
            interpret_dotenv_filepath_var
            get_envdot_filepaths_var_name
        )
    ],
);

use English qw( -no_match_vars );    # Avoids regex performance penalty in perl 5.18 and earlier
use Carp;

# ABSTRACT: Read environment variables from .env file

# VERSION: generated by DZP::OurPkgVersion

use constant {
    OPTION_FILE_TYPE                         => q{file:type},
    OPTION_FILE_TYPE_PLAIN                   => q{plain},
    OPTION_FILE_TYPE_SHELL                   => q{shell},
    DEFAULT_OPTION_FILE_TYPE                 => q{shell},
    OPTION_READ_FROM_PARENT                  => q{read:from_parent},
    DEFAULT_OPTION_READ_FROM_PARENT          => 0,
    OPTION_READ_ALLOW_MISSING_PARENT         => q{read:allow_missing_parent},
    DEFAULT_OPTION_READ_ALLOW_MISSING_PARENT => 0,
};

my %DOTENV_OPTIONS = (
    OPTION_READ_FROM_PARENT()          => 1,
    OPTION_READ_ALLOW_MISSING_PARENT() => 1,
    'file:type'                        => 1,
    'var:allow_interpolate'            => 1,
);

=pod

=for stopwords envdot env

=head1 STATUS

Package L<Env::Dot> is currently being developed so changes in the API are possible,
though not likely.


=head1 SYNOPSIS

    use Env::Dot::Functions qw( get_dotenv_vars interpret_dotenv_filepath_var );

=head1 DESCRIPTION

This package just contains functions for use
in the main package L<Env::Dot> and in
the command line tool B<envdot>.

=head1 FUNCTIONS

No functions are automatically exported to the calling namespace.

=head2 get_dotenv_vars()

Return all variables from the F<.env> file
as a list of hashes (name/value pairs).
This list is created in the same order the variables
are read from the files and may therefore contain
the same variable several times.

The files, however, are read in reversed order, just like
paths in variable B<PATH> are used.

=cut

sub get_dotenv_vars {
    my @dotenv_filepaths = @_;

    my @vars;
    foreach my $filepath ( reverse @dotenv_filepaths ) {
        if ( -f $filepath ) {
            push @vars, _read_dotenv_file_recursively($filepath);
        }
        else {
            carp "No file found: '$filepath'";
        }
    }
    return @vars;
}

=head2 interpret_dotenv_filepath_var( $filepaths )

Return a list of file paths.

=cut

sub interpret_dotenv_filepath_var {    ## no critic (Subroutines::RequireArgUnpacking)
    return split qr{:}msx, $_[0];
}

# Private subroutines

sub _read_dotenv_file_recursively {
    my ($filepath) = @_;
    $filepath = abs_path($filepath);
    my @rows       = _read_dotenv_file($filepath);
    my %r          = _interpret_dotenv(@rows);
    my @these_vars = @{ $r{'vars'} };
    if ( $r{'opts'}->{ OPTION_READ_FROM_PARENT() } ) {
        my $parent_filepath = _get_parent_dotenv_filepath($filepath);
        if ($parent_filepath) {
            unshift @these_vars, _read_dotenv_file_recursively($parent_filepath);
        }
        elsif ( !$r{'opts'}->{ OPTION_READ_ALLOW_MISSING_PARENT() } ) {
            croak "Error: No parent .env file. Child .env: $filepath";
        }
    }
    return @these_vars;
}

# Follow directory hierarchy upwards until you find a .env file.
# If you don't, return undef.
# Otherwise return the path.
sub _get_parent_dotenv_filepath {
    my ($current_filepath) = @_;

    my ( $volume, $directories, $file ) = File::Spec->splitpath($current_filepath);
    my ($parent_path)     = abs_path( File::Spec->catdir( $directories, File::Spec->updir ) );
    my ($parent_filepath) = abs_path( File::Spec->catdir( $parent_path, '.env' ) );
    while ( !-f $parent_filepath ) {
        return if ( $parent_path eq File::Spec->rootdir );
        ( $volume, $directories, $file ) = File::Spec->splitpath($parent_filepath);
        $parent_path     = abs_path( File::Spec->catdir( $directories, File::Spec->updir ) );
        $parent_filepath = abs_path( File::Spec->catdir( $parent_path, '.env' ) );
    }
    return $parent_filepath;
}

sub _interpret_dotenv {
    my (@rows) = @_;
    my %options = (
        OPTION_READ_FROM_PARENT()          => DEFAULT_OPTION_READ_FROM_PARENT,
        OPTION_READ_ALLOW_MISSING_PARENT() => DEFAULT_OPTION_READ_ALLOW_MISSING_PARENT,
        'file:type'                        => DEFAULT_OPTION_FILE_TYPE,
        'var:allow_interpolate'            => 0,
    );    # Options related to reading the file. Applied as they are read.
          # my %vars;
    my @vars;
    foreach (@rows) {
        ## no critic (ControlStructures::ProhibitCascadingIfElse)
        ## no critic (RegularExpressions::ProhibitComplexRegexes)
        if (
            # This is envdot meta command
            # The var:<value> options can only apply to one subsequent var row.
            m{
            ^ [[:space:]]{0,} [#]{1}
            [[:space:]]{1,} envdot [[:space:]]{1,}
            [(] (?<opts> [^)]{0,}) [)]
            [[:space:]]{0,} $
            }msx
          )
        {
            my $opts = _interpret_opts( $LAST_PAREN_MATCH{opts} );
            _validate_opts($opts);
            $options{'var:allow_interpolate'} = 0;
            foreach ( keys %{$opts} ) {
                $options{$_} = $opts->{$_};
            }
        }
        elsif (
            # This is comment row
            m{
                ^ [[:space:]]{0,} [#]{1} .* $
            }msx
          )
        {
            1;
        }
        elsif (
            # This is empty row
            m{
                ^ [[:space:]]{0,} $
            }msx
          )
        {
            1;
        }
        elsif (
            # This is env var description
            m{
                ^ (?<name> [^=]{1,}) = (?<value> .*) $
            }msx
          )
        {
            my ( $name, $value ) = ( $LAST_PAREN_MATCH{name}, $LAST_PAREN_MATCH{value} );
            if ( $options{'file:type'} eq OPTION_FILE_TYPE_SHELL ) {
                if (
                    $value =~ m{
                    ^
                    ['"]{1} (?<value> .*) ["']{1}  # Get value from between quotes
                    (?: [;] [[:space:]]{0,} export [[:space:]]{1,} $name)?  # optional
                    [[:space:]]{0,}  # optional whitespace at the end
                    $
                }msx
                  )
                {
                    ($value) = $LAST_PAREN_MATCH{value};
                }

                # "export" can also be at the start. Only for TYPE_SHELL
                if ( $name =~ m{^ [[:space:]]{0,} export [[:space:]]{1,} }msx ) {
                    $name =~ m{
                        ^
                        [[:space:]]{0,} export [[:space:]]{1,} (?<name> .*)
                        $
                    }msx;
                    $name = $LAST_PAREN_MATCH{name};
                }
            }
            elsif ( $options{'file:type'} eq OPTION_FILE_TYPE_PLAIN ) {
                1;
            }
            my %opts = ( allow_interpolate => $options{'var:allow_interpolate'}, );
            push @vars, { name => $name, value => $value, opts => \%opts, };
            $options{'var:allow_interpolate'} = 0;
        }
        else {
            carp "Uninterpretable row: $_";
        }
    }
    return opts => \%options, vars => \@vars;
}

sub _validate_opts {
    my ($opts) = @_;
    foreach my $key ( keys %{$opts} ) {
        if ( !exists $DOTENV_OPTIONS{$key} ) {
            croak "Unknown envdot option: $key";
        }
    }
    return;
}

sub _interpret_opts {
    my ($opts_str) = @_;
    my @opts = split qr{
        [[:space:]]{0,} [,] [[:space:]]{0,}
        }msx, $opts_str;
    my %opts;
    foreach (@opts) {
        ## no critic (ControlStructures::ProhibitPostfixControls)
        my ( $key, $val ) = split qr/=/msx;
        $val        = $val // 1;
        $val        = 1 if ( $val eq 'true'  || $val eq 'True' );
        $val        = 0 if ( $val eq 'false' || $val eq 'False' );
        $opts{$key} = $val;
    }
    return \%opts;
}

sub _read_dotenv_file {
    my ($filepath) = @_;
    open my $fh, q{<}, $filepath or croak "Cannot open file '$filepath'";
    my @dotenv_rows;
    while (<$fh>) { chomp; push @dotenv_rows, $_; }
    close $fh or croak "Cannot close file '$filepath'";
    return @dotenv_rows;
}

=head2 get_envdot_filepaths_var_name

Return the name of the environment variable
which user can use to specify the paths of .env files.

=cut

sub get_envdot_filepaths_var_name {
    return q{ENVDOT_FILEPATHS};
}

1;
