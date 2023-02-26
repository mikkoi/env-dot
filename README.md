# envdot

Read .env file and turn its content into
environment variables for different shells.

# DESCRIPTION

**envdot** reads your `.env` file and converts it
into environment variable commands suitable for
different shells (shell families): **sh**, **csh** and **fish**.

`.env` files can be written in different flavors.
**envdot** supports the often used **sh** compatible flavor and
the **docker** flavor which are not compatible with each other.

If you have several `.env` files, you can read them in at one go
with the help of the environment variable **ENVDOT_FILEPATHS**.
Separate the full paths with **:** character.

If you have set the variable **DOTENV_FILEPATH**, then **envdot** will use that.
Otherwise, it respects the command line parameter.
If no parameter, then default value is used. Default is the file
`.env` in the current directory.

# SYNOPSIS

envdot [options]

    eval `envdot`

    eval `envdot --no-export --shell csh --dotenv subdir/.env`

    ENVDOT_FILEPATHS=../.env:subdir/.env:.env eval `envdot`

Options:
    --help
    --man
    --export --no-export
    --shell -s
    --dotenv -e

## CLI interface without dependencies

The **envdot** command is also available
as self contained executable.
You can download it and run it as it is without
additional installation of CPAN packages.
Of course, you still need Perl, but Perl comes with any
normal Linux installation.

This can be convenient if you want to, for instance,
include **envdot** in a docker container build.

    curl -LSs -o envdot https://raw.githubusercontent.com/mikkoi/env-dot/master/envdot.self-contained
    chmod +x ./envdot

### How to Create a FatPacker Executable

    PERL5LIB=lib fatpack pack script/envdot >envdot.self-contained
