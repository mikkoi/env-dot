#!perl
# no critic (ValuesAndExpressions::ProhibitMagicNumbers)

use strict;
use warnings;
use File::Spec;
use Test2::V0;
use Test::Script;

subtest 'Script runs --version' => sub {
    my $stdout;
    program_runs(['t/env-dot-override-example-synopsis.sh', ], { stdout => \$stdout, }, 'Verify output');
    like( (split qr/\n/msx, $stdout)[0], qr/^ VAR:Good \s value $/msx, 'Correct stdout');
    like( (split qr/\n/msx, $stdout)[1], qr/^ VAR:Better \s value $/msx, 'Correct stdout');

    done_testing;
};

done_testing;
