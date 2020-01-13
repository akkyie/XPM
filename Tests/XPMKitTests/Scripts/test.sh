#!/bin/sh

if [[ $# != 2 ]]; then
    echo "Usage:" >&2
    echo "  $(basename $0) \"message\" 1   # to emit to stdout" >&2
    echo "  $(basename $0) \"message\" 2   # to emit to stderr" >&2
    exit 1
fi

if [[ $2 = 1 ]]; then
    echo $1
else
    echo $1 >&2
fi