#!/bin/sh
set -eu
echo "OFA demo running with:"
find "$(dirname "$0")/../build/generated_resources" -maxdepth 1 -type f -print
