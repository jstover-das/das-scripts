#!/bin/sh
set -e

# for bash completion
if [ $# -eq 1 ] && [ "$1" = "--list-targets" ]; then
    echo "local-etl local-das"
    exit
fi


if [ ! $# -ge 2 ]; then
    echo "Usage: $0 [TARGET] [COMMAND]"
    exit 1
fi

TARGET="$1"; shift

case "${TARGET}" in
    local-etl)
        dbmate \
            --migrations-dir ~/src/das/hull-scrubber/postgres/migrations \
            --url postgres://localhost:5433/das_etl \
            "$@" ;;

    local-das)
        dbmate \
            --migrations-dir ~/src/das/rural-platform/harrow/db/migrations \
            --url postgres://localhost:5433/das \
            --schema-file ~/src/das/rural-platform/harrow/db/schema.sql \
            "$@" ;;

    *)
        echo 'Unknown target. Valid targets are (local-etl, local-das)'; exit 1 ;;
esac

