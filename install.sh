#!/usr/bin/env bash
set -euo pipefail
catalog_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
catalog_jar=${1:-"$catalog_root/build/libs/GenericClientScripts.jar"}
scripts_directory=${2:-"$HOME/.runelite/genericclient/scripts"}
if [[ ! -f "$catalog_jar" ]]; then
    echo 'Build the catalog first: ./gradlew jar -PgenericClientDir=../GenericClient' >&2
    exit 1
fi
mkdir -p -- "$scripts_directory"
install -m 644 -- "$catalog_jar" "$scripts_directory/GenericClientScripts.jar"
cmp -- "$catalog_jar" "$scripts_directory/GenericClientScripts.jar"
find "$scripts_directory" -type f -name '*.lua' -delete
rm -f -- "$scripts_directory/manifest.json"
printf 'Installed %s/GenericClientScripts.jar. Reload the script catalog in GenericClient.\n' "$scripts_directory"
