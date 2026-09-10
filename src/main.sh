#!/bin/sh
set -eu
echo "OFA demo running with:"
find "$(dirname "$0")/../build/generated_resources" -type f -maxdepth 1 -print

