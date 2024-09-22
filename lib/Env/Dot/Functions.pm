## no critic (ValuesAndExpressions::ProhibitConstantPragma)
package Env::Dot::Functions;
use strict;
use warnings;
use Data::Dumper;

use Cwd qw( abs_path );
use English qw( -no_match_vars );
use File::Spec;
use IO::File;

use Exporter 'import';
our @EXPORT_OK = qw(
    get_dotenv_vars
    interpret_dotenv_filepath_var
    get_envdot_filepaths_var_name
    extract_error_msg
    create_error_msg
);
our %EXPORT_TAGS = (
    'all' => [
        qw(
            get_dotenv_vars
            interpret_dotenv_filepath_var
            get_envdot_filepaths_var_name
            extract_error_msg
            create_error_msg
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

=for stopwords envdot env filepath filepaths

=head1 STATUS

This module is currently being developed so changes in the API are possible,
though not likely.


=head1 SYNOPSIS

    use Env::Dot::Functions qw( get_dotenv_vars interpret_dotenv_filepath_var );
    # or
    use Env::Dot::Functions ':all';

=head1 DESCRIPTION

This package just contains functions for use
in the main package L<Env::Dot> and in
the command line tool B<envdot>.

=head1 FUNCTIONS

No functions are automatically exported to the calling namespace.

=head2 get_dotenv_vars(@)

Return all variables from the F<.env> file
as a list of hashes (name/value pairs).
This list is created in the same order the variables
are read from the files and may therefore contain
the same variable several times.

The files, however, are read in reversed order, just like
paths in variable B<PATH> are used.

Arguments:

=over 8

=item * filepaths, list of dotenv filepaths.

=back

If a file does not exist, we break the execution.

=cut

sub get_dotenv_vars {
    my (@dotenv_filepaths) = @_;

    my @vars;
    foreach my $filepath ( reverse @dotenv_filepaths ) {
        if ( -f $filepath ) {
            push @vars, _read_dotenv_file_recursively($filepath);
        }
        else {
            my ($err) = "File not found: '$filepath'";
            croak create_error_msg($err);
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

=head2 get_envdot_filepaths_var_name

Return the name of the environment variable
which user can use to specify the paths of .env files.

=cut

sub get_envdot_filepaths_var_name {
    return q{ENVDOT_FILEPATHS};
}

# Private subroutines

sub _read_dotenv_file_recursively {
    my ($filepath) = @_;
    $filepath = abs_path($filepath);
    my @rows       = _read_dotenv_file($filepath);
    local $EVAL_ERROR = undef;
    my %r          = eval { _interpret_dotenv(@rows); };
    if($EVAL_ERROR) {
        my $e = $EVAL_ERROR;
        my ($err, $line) = extract_error_msg($e);
        croak create_error_msg($err, $line, $filepath);
    }
    my @these_vars = @{ $r{'vars'} };
    if ( $r{'opts'}->{ OPTION_READ_FROM_PARENT() } ) {
        my $parent_filepath = _get_parent_dotenv_filepath($filepath);
        if ($parent_filepath) {
            unshift @these_vars, _read_dotenv_file_recursively($parent_filepath);
        }
        elsif ( !$r{'opts'}->{ OPTION_READ_ALLOW_MISSING_PARENT() } ) {
            my ($err) = "No parent .env file found for child file '$filepath'";
            croak create_error_msg($err);
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
    my @vars;
    my $row_num = 1;
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
            local $EVAL_ERROR = undef;
            eval { _validate_opts($opts); 1; } or do {
                my $e = $EVAL_ERROR;
                my ($err) = extract_error_msg($e);
                croak create_error_msg($err, $row_num);
            };
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
            my $err = "Invalid line: '$_'";
            croak create_error_msg($err, $row_num);
        }
        $row_num++;
    }
    return opts => \%options, vars => \@vars;
}

sub _validate_opts {
    my ($opts) = @_;
    foreach my $key ( keys %{$opts} ) {
        if ( !exists $DOTENV_OPTIONS{$key} ) {
            croak create_error_msg( "Unknown envdot option: '$key'" );
        }
    }
    return;
}

sub _interpret_opts {
    my ($opts_str) = @_;
    my @opts = split qr{ [[:space:]]{0,} [,] [[:space:]]{0,} }msx, $opts_str;
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
    my $fh = IO::File->new();
    $fh->binmode(':encoding(UTF-8)');
    $fh->open(qq{< $filepath}) or croak "Error: Cannot open file '$filepath'";
    my @dotenv_rows = <$fh>;
    chomp @dotenv_rows;
    $fh->close or croak "Error: Cannot close file '$filepath'";
    return @dotenv_rows;
}

# Error messages:
# Message structure:
# <msg>! [line <num>] [file <filepath>]

=head2 extract_error_msg

Extract the elements of error message (exception): err, line and filepath.

=cut

sub extract_error_msg {
    my ($msg) = @_;
    if( ! $msg ) {
        croak 'Parameter error: missing parameter \'msg\'';
    }
    ## no critic (RegularExpressions::ProhibitComplexRegexes)
    my ($err, $line, $filepath) = $msg =~
        m/^ ([^!]{1,}) \! (?: \s line \s ([[:digit:]]{1,}) (?: \s file \s \'([^']{1,})\' )? )? .* $/msx;
    return $err, $line, $filepath;
}

=head2 create_error_msg

create an error message (exception) from the three elements: err, line and filepath.

=cut

sub create_error_msg {
    my ($err, $line, $filepath) = @_;
    if( ! $err ) {
        croak 'Parameter error: missing parameter \'err\'';
    }
    if( ! $line && $filepath ) {
        croak 'Parameter error: missing parameter \'line\'';
    }
    return "${err}!"
        . (defined $line ? " line ${line}" : q{})
        . (defined $filepath ? " file '${filepath}'" : q{});
}

1;
