## no critic (ValuesAndExpressions::ProhibitConstantPragma)
package Env::Dot;
use strict;
use warnings;

# We define our own import routine because
# this is the point (when `use Env::Dot` is called)
# when we do our magic.

{
    no warnings 'redefine'; ## no critic [TestingAndDebugging::ProhibitNoWarnings]
    sub import {
        load_vars();
        return;
    }
}

use English qw( -no_match_vars ); # Avoids regex performance penalty in perl 5.18 and earlier
use Carp;

# ABSTRACT: Read environment variables from .env file

# VERSION: generated by DZP::OurPkgVersion

use Env::Dot::Functions qw( get_dotenv_vars interpret_dotenv_filepath_var );

use constant  {
    OPTION_FILE_TYPE => q{file:type},
    OPTION_FILE_TYPE_PLAIN => q{plain},
    OPTION_FILE_TYPE_SHELL => q{shell},
    DEFAULT_OPTION_FILE_TYPE => q{shell},
    DEFAULT_DOTENV_FILEPATH => q{.env},
    INDENT => q{    },
};

=pod

=begin stopwords

dotenv env envdot

=end stopwords

=head1 STATUS

Package L<Env::Dot> is currently being developed so changes in the API are possible,
though not likely.


=head1 SYNOPSIS

    use Env::Dot;

    print $ENV{'VAR_DEFINED_IN_DOTENV_FILE'};

=head1 DESCRIPTION

More flexibility in how you manage and use your F<.env> file.

B<Attn. Existing environment variables always take precedence to dotenv variables!>
A dotenv variable (variable from a file) does not overwrite
an existing environment variable. This is by design because
a dotenv file is to augment the environment, not to replace it.

Features:

=over 8

=item If no B<.env> file is present, then do nothing

By default, Env::Dot will do nothing if there is no
B<.env> file.
You can also configure Env::Dot to emit an alarm
or break execution, if you want.

=item Specify the other dotenv files with path

If your B<.env> file is located in another path,
not the current working directory,
you can use the environment variable
B<DOTENV_FILEPATHS> to tell where your dotenv file is located.
You can specify several file paths; just separate
them by B<:>. Dot::Env will load all the files in the order
you specify them.

=item Support different types of .env files

Unix Shell I<source> command compatible dotenv files use quotation marks
(B<">) to define a variable which has spaces. But, for instance,
Docker compatible F<.env> files do not use quotation marks. The variable's
value begins with B<=> sign and ends with linefeed.

You can specify in the dotenv file itself - by using meta commands -
which type of file it is.

=item Use executable B<envdot> to bring the variables into your shell

The executable is distributed together with Dot::Env package in directory I<script>.

    eval "$(envdot)"

=back

=head1 DEPENDENCIES

No external dependencies outside Perl's standard distribution.

=head1 FUNCTIONS

No functions are automatically exported to the calling namespace.

=head2 load_vars

Load variables from F<.env> file or files in environment variable
B<ENVDOT_FILEPATHS>.

=cut

sub load_vars {
    my $dotenv_filepath_var = q{ENVDOT_FILEPATHS};
    my @dotenv_filepaths;
    if( exists $ENV{ $dotenv_filepath_var } ) {
        @dotenv_filepaths = interpret_dotenv_filepath_var( $ENV{ $dotenv_filepath_var } );
    } else {
        if( -f DEFAULT_DOTENV_FILEPATH ) {
            @dotenv_filepaths = ( DEFAULT_DOTENV_FILEPATH ); # The CLI parameter
        }
    }

    my @vars = get_dotenv_vars( @dotenv_filepaths );
    my %new_env;

    # Populate new env with the dotenv variables.
    foreach my $var ( @vars ) {
        ### no critic [Variables::RequireLocalizedPunctuationVars]
        $new_env{ $var->{'name'} } = $var->{'value'};
    }
    foreach my $var_name ( sort keys %ENV ) {
        $new_env{ $var_name } = $ENV{$var_name};
    }

    # We need to replace the current %ENV, not change individual values.
    ## no critic [Variables::RequireLocalizedPunctuationVars]
    %ENV = %new_env;
    return \%ENV;
}

1;

__END__

=head1 SEE ALSO

L<Env::Assert> will verify that you certainly have those environmental
variables you need. It also has an executable which can perform the check
in the beginning of a B<docker> container run.

L<Dotenv> is another package which implements functionality to use
F<.env> files in Perl.

=cut
