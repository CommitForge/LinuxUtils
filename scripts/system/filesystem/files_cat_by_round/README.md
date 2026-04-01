# files_cat_by_round

Prints files from a folder in batches (rounds), then outputs each file's content.

## Why

Useful when a folder has many files and you want to review them in fixed-size chunks.

## Usage

```bash
chmod +x files_cat_by_round.sh
./files_cat_by_round.sh <path> <round> [per_round]
```

- `path`: folder containing files
- `round`: 1-based round number
- `per_round`: optional number of files per round (default: `12`)

## Example

```bash
./files_cat_by_round.sh ./myfolder 2 12
```
