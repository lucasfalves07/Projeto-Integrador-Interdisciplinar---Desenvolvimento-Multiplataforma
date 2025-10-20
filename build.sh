#!/bin/bash

base="lib"

# ------------------------------------------------------------
# 1) Gerar index.dart em cada subpasta de components
# ------------------------------------------------------------
for folder in "$base"/components/*/; do
  indexFile="$folder/index.dart"

  # Limpa e gera os exports
  > "$indexFile"
  for file in "$folder"*.dart; do
    filename=$(basename "$file")
    if [ "$filename" != "index.dart" ]; then
      echo "export '$filename';" >> "$indexFile"
    fi
  done

  echo "✅ Gerado $indexFile"
done

# ------------------------------------------------------------
# 2) Gerar lib/index.dart global exportando tudo
# ------------------------------------------------------------
indexFile="$base/index.dart"
> "$indexFile"

find "$base" -type f -name "*.dart" ! -name "index.dart" | while read file; do
  relativePath="${file#$base/}"
  echo "export '$relativePath';" >> "$indexFile"
done

echo "✅ Gerado $indexFile (global)"
