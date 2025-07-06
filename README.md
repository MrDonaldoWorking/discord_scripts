# Discord downloader

## Usage

1. Browse Discord with opened Developer Tools and crawl until all images will be in exported HAR.
2. `/usr/bin/python3 ~/discord_scripts/parse_links.py --har-file <har file> --links-file <links file>`
3. `~/discord_scripts/discord_download_fast.sh <links file>` will download all images that was in chat.
4. `/usr/bin/python3 ~/discord_scripts/parse_discord_files.py --har-file <har file> --images-dir ./discord_download/images`. If downloaded by discord cli, then use `--discord-plus` flag.
5. [Optional] `~/discord_scripts/files_analyzer.sh ./discord_download/images` to check grouping images in previous step
6. [Optional] `/usr/bin/python3 ~/discord_scripts/clean_duplicate_directories.py --dir ./discord_download/images (--remove) (--merge)`: sometimes browser cannot collect all images. Several HAR files can produce duplicated (that is needed to remove) and partially overlapping directories (that is needed to merge).
7. [Optional] `~/discord_scripts/create_pdfs.sh ./discord_download/images ./discord_download/pdfs` to create pdfs. PDFs directory passed by **2nd** parameter can contain `blacklist.txt`.
