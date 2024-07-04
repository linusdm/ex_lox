#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "$CI_PATH" >/dev/null
dart tool/bin/test.dart "$1" --interpreter "$SCRIPT_DIR/run.sh"
popd >/dev/null
