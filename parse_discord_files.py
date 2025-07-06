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


def extract_filename_from_url(url):
    filename = url
    if '?' not in filename:
        return ''
    filename = filename[:filename.index('?')]
    if '/' not in filename:
        return ''
    return filename[filename.rfind('/')+1:]


def extract_is_from_url(url):
    """
    Extracts the 'is' query parameter from a URL.
    Handles basic URL cases without external imports.
    """
    try:
        # Split URL at '?' and take the query part
        query = url.split('?')[1] if '?' in url else ''
        
        # Split parameters and find 'id'
        for param in query.split('&'):
            if '=' in param:
                key, value = param.split('=', 1)
                if key == 'is':
                    return value
        return ''
    except:
        return ''

def group_images(images_dir, dd, is_map):
    name_map = {}
    for entity in dd['log']['entries']:
        if 'request' in entity and 'url' in entity['request'] and 'queryString' in entity['request']:
            filename = extract_filename_from_url(entity['request']['url'])
            if len(filename) <= 0:
                continue

            if os.path.isfile(f'{images_dir}/{filename}'):
                is_value = extract_is_from_url(entity['request']['url'])
                if len(is_value) > 0:
                    is_int_value = int(is_value, 16)
                    is_int_value_map_index = is_map[is_int_value]
                    if is_int_value_map_index not in name_map:
                        name_map[is_int_value_map_index] = []
                    name_map[is_int_value_map_index].append(filename)
    return name_map


def group_images_by_filename(images_dir, dd, is_map): # sidecar for another downloading source
    # Extract id mappings from HAR file
    is_mappings = {}
    entries = dd.get('log', {}).get('entries', [])

    for entry in entries:
        url = entry.get('request', {}).get('url', '')
        is_value = extract_is_from_url(url)

        if len(is_value) > 0:
            # Get the filename from the URL path
            filename = extract_filename_from_url(url)
            is_mappings[filename] = int(is_value, 16)  # filename -> 'is' number

    # Process directory files
    name_map = {}
    for filename in os.listdir(images_dir):
        full_path = os.path.join(images_dir, filename)
        if os.path.isfile(full_path):
            # Get the base name without extensions
            splitext = os.path.splitext(filename)
            base_name = splitext[0]
            extension = splitext[1]

            # Try to find matching prefixes in id_mappings
            parts = base_name.split('-')

            # Try progressively shorter prefixes
            for i in range(len(parts), 0, -1):
                test_prefix = '-'.join(parts[:i])
                test_name = f'{test_prefix}{extension}'
                if test_name in is_mappings:
                    # name_map[filename] = is_mappings[test_name]
                    is_int_value = is_mappings[test_name]
                    is_int_value_map_index = is_map[is_int_value]
                    if is_int_value_map_index not in name_map:
                        name_map[is_int_value_map_index] = []
                    name_map[is_int_value_map_index].append(filename)
                    break
    return name_map

    

def main():
    parser = argparse.ArgumentParser(description='Try to group images into neighbouring "is" value')
    parser.add_argument('--har-file', type=str, required=True,
                       help='HAR file with which we can group image files (required)')
    parser.add_argument('--images-dir', type=str, default='.',
                       help='Images directory to analyze (default: current directory)')
    parser.add_argument('--debug-run', action='store_true',
                       help='Print debugging logs (default: False)')
    parser.add_argument('--discord-plus', action='store_true', help='Is files downloaded by discord cli util')
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

    if args.discord_plus:
        name_map = group_images_by_filename(args.images_dir, dd, is_map)
    else:
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
