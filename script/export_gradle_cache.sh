#!/usr/bin/env bash

set -euo pipefail

CACHE_ROOT="${1:-$HOME/.gradle/caches/modules-2/files-2.1}"
OUTPUT_ROOT="${2:-build/local-gradle-maven}"

[[ -d "$CACHE_ROOT" ]] || {
  echo "Gradle 模块缓存不存在：$CACHE_ROOT" >&2
  exit 1
}

mkdir -p "$OUTPUT_ROOT"

while IFS= read -r -d '' source_file; do
  relative_path="${source_file#"$CACHE_ROOT"/}"
  IFS='/' read -r group module version hash file_name <<< "$relative_path"
  [[ -n "${file_name:-}" ]] || continue

  group_path="${group//./\/}"
  destination_dir="$OUTPUT_ROOT/$group_path/$module/$version"
  destination_file="$destination_dir/$file_name"
  mkdir -p "$destination_dir"

  if [[ ! -e "$destination_file" ]]; then
    ln "$source_file" "$destination_file" 2>/dev/null ||
      cp "$source_file" "$destination_file"
  fi
done < <(find "$CACHE_ROOT" -mindepth 5 -maxdepth 5 -type f -print0)

echo "已导出 Gradle 缓存：$OUTPUT_ROOT"
