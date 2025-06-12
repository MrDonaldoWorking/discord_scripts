import json
import os.path
import sys
import argparse
from os import makedirs as os_makedirs
from shutil import copy as shutil_copy


def collect_is_values(dd):
    ises = []
    for entity in dd['log']['entries']:
        if 'request' in entity and 'queryString' in entity['request']:
            for query in entity['request']['queryString']:
                if 'name' in query and 'value' in query and query['name'] == 'is':
                    ises.append(int(query['value'], 16))
    return ises


def group_is_values(ises):
    is_map = {}
    for isi in sorted(set(ises)):
        if (isi - 1) in is_map:
            is_map[isi] = is_map[isi - 1]
        elif (isi - 2) in is_map:
            is_map[isi] = is_map[isi - 2]
        else:
            is_map[isi] = isi
    return is_map


def group_images(images_dir, dd, is_map):
    name_map = {}
    for entity in dd['log']['entries']:
        if 'request' in entity and 'url' in entity['request'] and 'queryString' in entity['request']:
            filename = entity['request']['url']
            if '?' not in filename:
                continue
            filename = filename[:filename.index('?')]
            if '/' not in filename:
                continue
            filename = filename[filename.rfind('/')+1:]
            if os.path.isfile(f'{images_dir}/{filename}'):
                for query in entity['request']['queryString']:
                    if 'name' in query and 'value' in query and query['name'] == 'is':
                        is_int_value = int(query['value'], 16)
                        is_int_value_map_index = is_map[is_int_value]
                        if is_int_value_map_index not in name_map:
                            name_map[is_int_value_map_index] = []
                        name_map[is_int_value_map_index].append(filename)
    return name_map


def main():
    parser = argparse.ArgumentParser(description='Try to group images into neighbouring "is" value')
    parser.add_argument('--har-file', type=str, required=True,
                       help='HAR file with which we can group image files (required)')
    parser.add_argument('--images-dir', type=str, default='.',
                       help='Images directory to analyze (default: current directory)')
    parser.add_argument('--debug-run', action='store_true',
                       help='Print debugging logs (default: False)')
    args = parser.parse_args()

    if not os.path.isdir(args.images_dir):
        print(f"Error: Directory '{args.images_dir}' does not exist")
        sys.exit(1)

    with open(args.har_file) as har:
        dd = json.loads(har.read())

    ises = collect_is_values(dd)

    is_map = group_is_values(ises)

    if args.debug_run:
        print('Write out grouping by "is" values to ~/discord_scripts/is_map.json')
        with open('~/discord_scripts/is_map.json', 'w') as fp:
            json.dump(is_map, fp)

    name_map = group_images(args.images_dir, dd, is_map)

    print()
    copied = 0
    for k, v in name_map.items():
        print(k, '->', len(v))
        images_dir = f'{args.images_dir}/{k}'
        if not os.path.exists(images_dir):
            print(f'There is no path "{images_dir}", so create it')
            os_makedirs(images_dir)
        for vv in v:
            if args.debug_run:
                print(vv, '->', k)
            shutil_copy(f'{args.images_dir}/{vv}', images_dir)
            copied += 1

    files_in_dir = len([name for name in os.listdir(args.images_dir) if os.path.isfile(os.path.join(args.images_dir, name))])
    print('\nProcessed', copied, 'files among of', files_in_dir)


if __name__ == "__main__":
    main()
