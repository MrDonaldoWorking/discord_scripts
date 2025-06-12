import json
import argparse


def main():
    parser = argparse.ArgumentParser(description='Try to group images into neighbouring "is" value')
    parser.add_argument('--har-file', type=str, required=True,
                       help='HAR file in which exist images url (required)')
    parser.add_argument('--links-file', type=str, required=True,
                       help='Links file that will be processed (required)')
    args = parser.parse_args()

    with open(args.har_file, 'r') as har:
        dd = json.loads(har.read())

    with open(args.links_file, 'w') as out:
        for entity in dd['log']['entries']:
            if 'request' in entity and 'url' in entity['request']:
                print(entity['request']['url'], file=out)


if __name__ == "__main__":
    main()
