#!/bin/bash

# This is a bit clunky, because mix needs to be in the correct directory (where mix.exs is),
# but the input files are passed in with a relative path.
# So this needs some fiddling to be compatible with how the craftinginterpreters tests work,
# with passing in a custom interpreter.
#
# Ideally this is fixed in the craftinginterpreters repo, to allow passing in a directory where
# the custom interpreter can ben run, and passing in absolute paths to the input lox files.

CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "$SCRIPT_DIR" >/dev/null
mix lox "$CURRENT_DIR/$1"
popd >/dev/null
