[![License: Artistic-2.0](https://img.shields.io/badge/License-Perl-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)
[![CPAN Version](https://img.shields.io/cpan/v/Env-Dot)](https://metacpan.org/dist/Env-Dot)
[![kwalitee](https://cpants.cpanauthors.org/dist/Env-Dot.svg)](https://cpants.cpanauthors.org/dist/Env-Dot)
[![Coverage Status](https://coveralls.io/repos/github/mikkoi/env-dot/badge.svg?branch=main)](https://coveralls.io/github/mikkoi/env-dot?branch=main)
[![codecov](https://codecov.io/gh/mikkoi/env-dot/graph/badge.svg?token=KH15ROS3GZ)](https://codecov.io/gh/mikkoi/env-dot)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/mikkoi/env-dot)
[![GH Actions: Linux Build](https://github.com/mikkoi/env-dot/actions/workflows/linux.yml/badge.svg?event=push&branch=main)](https://github.com/mikkoi/env-dot/actions/workflows/linux.yml)
[![GH Actions: Windows Build](https://github.com/mikkoi/env-dot/actions/workflows/windows.yml/badge.svg?event=push&branch=main)](https://github.com/mikkoi/env-dot/actions/workflows/windows.yml)

# Env-Dot

Read .env file and turn its content into environment variables for different shells. Module and executable.


# VERSION

0.023


# SYNOPSIS

    # If your dotenv file is `.env`:
    use Env::Dot;
    # or
    use Env::Dot 'read';

    print $ENV{'VAR_DEFINED_IN_DOTENV_FILE'};

    # If you have a dotenv file in a different filepath:
    use Env::Dot read => {
        dotenv_file => '/other/path/my_environment.env',
    };

    # When you absolutely require `.env` file:
    use Env::Dot read => {
        required => 1,
    };


# DESCRIPTION

**envdot** reads your `.env` file and converts it
into environment variable commands suitable for
different shells (shell families): **sh**, **csh** and **fish**.

`.env` files can be written in different flavors.
**envdot** supports the often used **sh** compatible flavor and
the **docker** flavor which are not compatible with each other.

If you have several `.env` files, you can read them in at one go
with the help of the environment variable **ENVDOT\_FILEPATHS**.
Separate the full paths with '**:**' character.

Env::Dot will load the files in the **reverse order**,
starting from the last. This is the same ordering as used in **PATH** variable:
the first overrules the following ones, that is, when reading from the last path
to the first path, if same variable is present in more than one file, the later
one replaces the one already read.

If you have set the variable ENVDOT\_FILEPATHS, then **envdot** will use that.
Otherwise, it uses the command line parameter.
If no parameter, then default value is used. Default is the file
`.env` in the current directory.


## INSTALLATION

### Packaging

[![Packaging status](https://repology.org/badge/vertical-allrepos/env-dot.svg)](https://repology.org/project/env-dot/versions)

### CLI interface without dependencies

The **envdot** command is also available
as self contained executable.
You can download it and run it as it is without
additional installation of CPAN packages.
Of course, you still need Perl, but Perl comes with any
normal Linux installation.

This can be convenient if you want to, for instance,
include **envdot** in a docker container build.

    curl -LSs -o envdot https://raw.githubusercontent.com/mikkoi/env-dot/main/envdot.self-contained
    chmod +x ./envdot


# LICENSE

This software is copyright (c) 2026 by Mikko Koivunalho <mikkoi@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

Terms of the Perl programming language system itself:

a) the GNU General Public License as published by the Free
   Software Foundation; either version 1, or (at your option) any
   later version, or
b) the "Artistic License"

The complete licenses are in the files LICENSE-Artistic-2.0 and LICENSE-GPL-3
within this repository. If these files are missing, they can be downloaded
from the following urls:

    * https://www.gnu.org/licenses/
    * https://www.perlfoundation.org/artistic-license-20.html
