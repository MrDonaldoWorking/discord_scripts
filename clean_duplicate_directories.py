#!/usr/bin/env python3.9
import os
import sys
import argparse
import shutil
from pathlib import Path
from typing import Dict, List, Set, Tuple

def get_directory_signature(directory: Path) -> Tuple[str, List[str]]:
    """Get signature (sorted filenames) for a directory."""
    files = sorted(f.name for f in directory.iterdir() if f.is_file() and not f.name.startswith('.'))
    return (' '.join(files), files)

def merge_directories(source: Path, target: Path) -> None:
    """Merge files from source directory into target directory."""
    for item in source.iterdir():
        if item.is_file():
            dest = target / item.name
            if not dest.exists():
                shutil.move(str(item), str(target))
            # else:
                # Handle filename conflicts by adding suffix
                # counter = 1
                # while True:
                #     new_name = f"{item.stem}_{counter}{item.suffix}"
                #     dest = target / new_name
                #     if not dest.exists():
                #         shutil.move(str(item), str(dest))
                #         break
                #     counter += 1

def analyze_directories(root_dir: Path, remove_duplicates: bool, merge: bool, print_unique: bool) -> None:
    """Analyze directory structure and handle duplicates/merges."""
    dir_signatures: Dict[Path, Tuple[str, List[str]]] = {}
    sig_to_keep: Dict[str, Path] = {}
    duplicate_info: List[Tuple[Path, Path]] = []  # (duplicate, original)
    conflict_info: List[Tuple[Path, Path, Set[str]]] = []
    merge_candidates: Dict[Path, List[Path]] = {}

    # First pass: collect all directory signatures
    for directory in sorted(root_dir.iterdir()):
        if directory.is_dir():
            signature, files = get_directory_signature(directory)
            dir_signatures[directory] = (signature, files)

    # Second pass: identify duplicates and potential merges
    for directory, (signature, files) in dir_signatures.items():
        if signature not in sig_to_keep:
            sig_to_keep[signature] = directory
        else:
            # Compare lex order with the one we're keeping
            existing_dir = sig_to_keep[signature]
            if str(directory) < str(existing_dir):
                duplicate_info.append((existing_dir, directory))
                sig_to_keep[signature] = directory
            else:
                duplicate_info.append((directory, existing_dir))

    # Third pass: identify partial conflicts and merge candidates
    kept_dirs = list(sig_to_keep.values())
    for i, dir1 in enumerate(kept_dirs):
        for dir2 in kept_dirs[i+1:]:
            files1 = set(dir_signatures[dir1][1])
            files2 = set(dir_signatures[dir2][1])
            common_files = files1 & files2
            if common_files:
                conflict_info.append((dir1, dir2, common_files))
                if merge:
                    # Determine which directory comes first lexicographically
                    if str(dir1) < str(dir2):
                        target, source = dir1, dir2
                    else:
                        target, source = dir2, dir1
                    if target not in merge_candidates:
                        merge_candidates[target] = []
                    merge_candidates[target].append(source)

    # Output results
    print(f"\nAnalyzing directory structure of: {root_dir}")
    print("-------------------------------------------")

    print("\nDuplicate directories:")
    if not duplicate_info:
        print("  (none found)")
    else:
        for duplicate, original in duplicate_info:
            print(f"  {duplicate.name} -> {original.name}")

        if remove_duplicates:
            print("\nRemoving duplicate directories:")
            for duplicate, _ in duplicate_info:
                print(f"  Deleting {duplicate}")
                shutil.rmtree(duplicate)

    print("\nDirectories with partial file conflicts:")
    if not conflict_info:
        print("  (none found)")
    else:
        for dir1, dir2, common_files in conflict_info:
            print(f"\n  WARNING: {dir1.name} vs {dir2.name}")
            print(f"  Common files ({len(common_files)}):")
            for file in sorted(common_files):
                print(f"    - {file}")

    # Handle merging if requested
    if merge and merge_candidates:
        print("\nMerging directories with overlapping files:")
        for target, sources in merge_candidates.items():
            for source in sources:
                print(f"  Merging {source.name} into {target.name}")
                merge_directories(source, target)
                print(f"  Deleting {source.name}")
                shutil.rmtree(source)

    if print_unique:
        print("\nKeeping these unique directories:")
        for directory in sig_to_keep.values():
            print(f"  {directory.name}")

    print("\nOperation complete")

def main():
    parser = argparse.ArgumentParser(description='Analyze and clean duplicate directories')
    parser.add_argument('--dir', type=str, default='.', 
                       help='Root directory to analyze (default: current directory)')
    parser.add_argument('--remove', action='store_true',
                       help='Remove duplicate directories (default: False)')
    parser.add_argument('--merge', action='store_true',
                       help='Merge directories with overlapping files (default: False)')
    parser.add_argument('--print-unique', action='store_true',
                       help='Print out which directories will be after remove duplicates (default: False)')

    args = parser.parse_args()

    root_dir = Path(args.dir).resolve()
    if not root_dir.is_dir():
        print(f"Error: Directory '{root_dir}' does not exist")
        sys.exit(1)

    analyze_directories(root_dir, args.remove, args.merge, args.print_unique)

if __name__ == "__main__":
    main()
