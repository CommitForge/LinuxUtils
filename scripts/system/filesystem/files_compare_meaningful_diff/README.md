# files_compare_meaningful_diff

Compares two folders recursively and prints a compact, human-readable summary.

## What It Reports

- `DIFF`: files that exist in both folders but have different content
- `ONLY`: files that exist in only one folder

## Usage

```bash
chmod +x files_compare_meaningful_diff.sh
./files_compare_meaningful_diff.sh /path/to/folder_a /path/to/folder_b
```

## Example

```bash
./files_compare_meaningful_diff.sh /home/alice/source_a /home/alice/source_b
```
