# Universal Archive Extractor (`extract`)

## Purpose
Provides a single unified command `extract` that automatically detects archive formats by extension and unpacks them using the optimal underlying decompression tool (`tar`, `unzip`, `7z`, `zstd`, `bunzip2`, `gunzip`).

Supported formats:
* `.tar.gz` / `.tgz`
* `.tar.bz2` / `.tbz2`
* `.tar.xz` / `.txz`
* `.tar.zst`
* `.tar`
* `.zip` / `.jar` / `.war`
* `.7z`
* `.rar`
* `.gz`
* `.bz2`
* `.zst`

## Implementation Details

### Configuration File Modified
* [~/.zshrc](file:///home/sanjith/.zshrc)

### Code Added
```zsh
# Universal archive extractor
extract() {
    if [ $# -eq 0 ]; then
        echo "Usage: extract <archive_file(s)>" >&2
        return 1
    fi
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "extract: '$file' is not a valid file" >&2
            continue
        fi
        case "${file:l}" in
            *.tar.bz2|*.tbz2)   tar xvjf "$file" ;;
            *.tar.gz|*.tgz)     tar xvzf "$file" ;;
            *.tar.xz|*.txz)     tar xvJf "$file" ;;
            *.tar.zst)          tar --zstd -xvf "$file" ;;
            *.tar)              tar xvf "$file" ;;
            *.bz2)              bunzip2 "$file" ;;
            *.rar)              if command -v unrar &>/dev/null; then unrar x "$file"; else 7z x "$file"; fi ;;
            *.gz)               gunzip "$file" ;;
            *.zip|*.jar|*.war)  unzip "$file" ;;
            *.7z)               7z x "$file" ;;
            *.zst)              zstd -d "$file" ;;
            *)                  echo "extract: unsupported format for '$file'" >&2 ;;
        esac
    done
}
```

## Usage
* Extract any archive without worrying about compression flags:
  ```sh
  extract project.tar.gz
  extract archive.zip
  extract package.tar.zst
  ```
* Batch extract multiple files at once:
  ```sh
  extract bundle.zip logs.tar.gz docs.7z
  ```
