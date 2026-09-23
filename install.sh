#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_path=${1:-"$root/build/libs"}
destination=${2:-"$HOME/.runelite/genericclient/scripts"}
files=()
hashes=()

digest() {
    if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d ' ' -f 1
    else shasum -a 256 "$1" | cut -d ' ' -f 1; fi
}
fail() { printf '%s\n' "$1" >&2; exit 1; }
validate() {
    local file=$1 hash=$2 name id
    name=$(basename -- "$file")
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*\.jar$ ]] || fail "Invalid script JAR name: $name"
    [[ -f "$file" && $(digest "$file") == "$hash" ]] || fail "Missing or changed artifact: $file"
    id=$(unzip -p "$file" META-INF/MANIFEST.MF | tr -d '\r' | sed -n 's/^GenericClient-Script-Id: //p')
    [[ "$id.jar" == "$name" ]] || fail "Not a single-script artifact: $file"
}

full_catalog=false
if [[ -d "$source_path" ]]; then
    full_catalog=true
    [[ -f "$source_path/scripts.sha256" ]] || fail 'Build the scripts first: ./gradlew build'
    while read -r hash name extra; do
        [[ "$hash" =~ ^[a-f0-9]{64}$ && "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*\.jar$ && -z "$extra" ]] || fail 'Invalid scripts.sha256'
        for previous in "${files[@]}"; do [[ $(basename -- "$previous") != "$name" ]] || fail "Duplicate artifact: $name"; done
        validate "$source_path/$name" "$hash"
        files+=("$source_path/$name"); hashes+=("$hash")
    done < "$source_path/scripts.sha256"
    [[ ${#files[@]} -gt 0 ]] || fail 'The script catalog is empty'
    actual=0
    for file in "$source_path"/*.jar; do [[ ! -f "$file" ]] || actual=$((actual+1)); done
    [[ $actual -eq ${#files[@]} ]] || fail 'Unlisted JARs in build output; rebuild before installing'
elif [[ -f "$source_path" ]]; then
    hash=$(digest "$source_path")
    validate "$source_path" "$hash"
    files+=("$source_path"); hashes+=("$hash")
else
    fail "Artifact or build directory not found: $source_path"
fi

legacy="$destination/GenericClientScripts.jar"
if [[ -f "$legacy" && "$full_catalog" == false ]]; then
    fail 'The old combined catalog is installed. Run the full-directory installer once before updating individual scripts.'
fi
for file in "${files[@]}"; do
    target="$destination/$(basename -- "$file")"
    [[ ! -e "$target" || -f "$target" ]] || fail "Destination is not a regular file: $target"
done

# Operator precondition: stop scripts before replacing their JARs.
mkdir -p -- "$destination" "$(dirname -- "$destination")/backups"
staging=$(mktemp -d "$destination/.script-install.XXXXXX")
backup=$(mktemp -d "$(dirname -- "$destination")/backups/script-jars.XXXXXX")
installed=()
success=false
cleanup() {
    if [[ "$success" == false ]]; then
        for file in "${installed[@]}"; do rm -f -- "$file"; done
        for file in "$backup"/*.jar; do [[ ! -f "$file" ]] || cp -p -- "$file" "$destination/"; done
    fi
    rm -rf -- "$staging"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for ((index=0; index<${#files[@]}; index++)); do
    file=${files[$index]}; name=$(basename -- "$file")
    cp -- "$file" "$staging/$name"
    [[ $(digest "$staging/$name") == "${hashes[$index]}" ]] || fail "Staged copy mismatch: $name"
done
for file in "${files[@]}"; do
    name=$(basename -- "$file")
    [[ ! -f "$destination/$name" ]] || cp -p -- "$destination/$name" "$backup/$name"
    installed+=("$destination/$name")
    mv -f -- "$staging/$name" "$destination/$name"
    [[ $(digest "$destination/$name") == $(digest "$file") ]] || fail "Installed copy mismatch: $name"
done
[[ ! -f "$legacy" ]] || mv -- "$legacy" "$backup/GenericClientScripts.jar"
success=true
printf 'Installed %s script JAR(s) in %s. Backup: %s\nUse Scripts > Reload list in GenericClient.\n' "${#files[@]}" "$destination" "$backup"
