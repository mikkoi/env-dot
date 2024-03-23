#!perl
# no critic (ValuesAndExpressions::ProhibitMagicNumbers)

use strict;
use warnings;
use Test2::V0;

use Carp qw( croak );
use English qw( -no_match_vars ) ;  # Avoids regex performance
use FileHandle ();
use File::Path qw( make_path );
use File::Spec;
use File::Temp ();
use Cwd qw( getcwd );


# $File::Temp::KEEP_ALL = 1;
# $File::Temp::DEBUG = 1;
sub create_subtest_files {
    my ($root_env, $dir_env, $subdir_env) = @_;
    my $dir = File::Temp->newdir(
        TEMPLATE => 'temp-envdot-test-XXXXX',
        CLEANUP => 1,
        DIR => File::Spec->tmpdir,
    );
    my $dir_path = $dir->{'DIRNAME'};
    diag "Created temp dir: $dir_path";
    make_path( File::Spec->catdir( $dir_path, 'root', 'dir', 'subdir' ) );

    if( $root_env ) {
        my $fh_root_env = FileHandle->new( File::Spec->catfile( $dir_path,
            'root', '.env' ), 'w' );
        print { $fh_root_env } $root_env || croak;
        $fh_root_env->close;
    }

    if( $dir_env ) {
        my $fh_dir_env = FileHandle->new( File::Spec->catfile( $dir_path,
            'root', 'dir', '.env' ), 'w' );
        print { $fh_dir_env } $dir_env || croak;
        $fh_dir_env->close;
    }

    if( $subdir_env ) {
        my $fh_subdir_env = FileHandle->new( File::Spec->catfile( $dir_path,
            'root', 'dir', 'subdir', '.env' ), 'w' );
        print { $fh_subdir_env } $subdir_env || croak;
        $fh_subdir_env->close;
    }

    return $dir, $dir_path;
}

my $CASE_ONE_ROOT_ENV = <<"END_OF_FILE";
ROOT_VAR="root"
COMMON_VAR="root"
DIR_COMMON_VAR="root"
END_OF_FILE

my $CASE_ONE_DIR_ENV = <<"END_OF_FILE";
# envdot (read:from_parent)
DIR_VAR="dir"
COMMON_VAR="dir"
DIR_COMMON_VAR="dir"
SUBDIR_COMMON_VAR="dir"
END_OF_FILE

my $CASE_ONE_SUBDIR_ENV = <<"END_OF_FILE";
# envdot (file:type=shell,read:from_parent)
SUBDIR_VAR="subdir"
COMMON_VAR="subdir"
SUBDIR_COMMON_VAR="subdir"
END_OF_FILE


subtest 'One dotenv, two parent files' => sub {
    my ($dir, $dir_path) = create_subtest_files(
        $CASE_ONE_ROOT_ENV,
        $CASE_ONE_DIR_ENV,
        $CASE_ONE_SUBDIR_ENV,
        );

    # Do not use __FILE__ because its value is not absolute and not updated
    # when chdir is done.
    my $this = getcwd;
    ($this) = $this =~ /(.+)/msx; # Make it non-tainted

    my $subdir_path = File::Spec->catdir( $dir_path, 'root', 'dir', 'subdir' );

    # CD to subdir, the bottom in the hierarcy.
    chdir $subdir_path || croak;
    diag 'Current dir:' . getcwd();

    my %new_env;
    ## no critic (ControlStructures::ProhibitPostfixControls)
    $new_env{$_} = $ENV{$_} foreach (keys %ENV);

    delete $new_env{'ENVDOT_FILEPATHS'} if exists $new_env{'ENVDOT_FILEPATHS'};

    # We need to replace the current %ENV, not change individual values.
    local %ENV = %new_env;

    my $r = eval 'use Env::Dot;'; ## no critic [BuiltinFunctions::ProhibitStringyEval]

    is( $ENV{'ROOT_VAR'}, 'root', 'Interface works' );
    is( $ENV{'DIR_VAR'}, 'dir', 'Interface works' );
    is( $ENV{'SUBDIR_VAR'}, 'subdir', 'Interface works' );
    is( $ENV{'COMMON_VAR'}, 'subdir', 'Interface works' );
    is( $ENV{'DIR_COMMON_VAR'}, 'dir', 'Interface works' );
    is( $ENV{'SUBDIR_COMMON_VAR'}, 'subdir', 'Interface works' );

    chdir $this;
    done_testing;
};

my $CASE_TWO_ROOT_ENV = <<"END_OF_FILE";
# envdot (read:from_parent)
ROOT_VAR="root"
COMMON_VAR="root"
DIR_COMMON_VAR="root"
END_OF_FILE

subtest 'Missing parent file' => sub {
    # N.B. This test will fail if there is a .env file in a parent dir of the tempdir.
    my ($dir, $dir_path) = create_subtest_files(
        $CASE_TWO_ROOT_ENV,
        );

    # Do not use __FILE__ because its value is not absolute and not updated
    # when chdir is done.
    my $this = getcwd;
    ($this) = $this =~ /(.+)/msx; # Make it non-tainted

    my $root_path = File::Spec->catdir( $dir_path, 'root' );

    # CD to subdir, the bottom in the hierarcy.
    chdir $root_path || croak;
    diag 'Current dir:' . getcwd();

    my %new_env;
    ## no critic (ControlStructures::ProhibitPostfixControls)
    $new_env{$_} = $ENV{$_} foreach (keys %ENV);

    delete $new_env{'ENVDOT_FILEPATHS'} if exists $new_env{'ENVDOT_FILEPATHS'};

    # We need to replace the current %ENV, not change individual values.
    local %ENV = %new_env;

    my $r = eval 'use Env::Dot;'; ## no critic [BuiltinFunctions::ProhibitStringyEval]

    is( $ENV{'ROOT_VAR'}, 'root', 'Interface works' );
    is( $ENV{'COMMON_VAR'}, 'root', 'Interface works' );
    is( $ENV{'DIR_COMMON_VAR'}, 'root', 'Interface works' );

    chdir $this;
    done_testing;
};

done_testing;
