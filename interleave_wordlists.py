import argparse


def interleave_wordlists(wordlists, output_wordlist):
    # Check if the input files exist and are not empty
    for wordlist in wordlists:
        try:
            with open(wordlist) as f:
                first_line = f.readline().strip()
                if not first_line:
                    raise ValueError(f"Input file '{wordlist}' is empty.")
        except FileNotFoundError:
            raise ValueError(f"Input file '{wordlist}' does not exist.")

    # Check if the output file exists and if we have permission to write to it
    if output_wordlist and not output_wordlist.isspace():
        try:
            with open(output_wordlist, 'x'):
                pass
        except FileExistsError:
            raise ValueError(f"Output file '{output_wordlist}' already exists.")
    else:
        raise ValueError(f"Invalid output file name: '{output_wordlist}'")

    # Open all wordlists files
    files = [open(wordlist) for wordlist in wordlists]

    # Read the first word from each file
    words = [f.readline().strip() for f in files]
    unique_words = set()

    # Open output wordlist file for writing
    with open(output_wordlist, 'w') as output_file:
        # Interleave the words while preserving the original order
        while any(words):
            current_words = [word for word in words if word not in unique_words]

            unique_words.update(current_words)

            for word in current_words:
                output_file.write(word + '\n')

            # Read the next word from each file
            words = [f.readline().strip() for f in files]

            # Gets rid of empty strings
            words = list(filter(None, words))

    # Close all files
    for f in files:
        f.close()


if __name__ == '__main__':
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-w', '--wordlists', required=True, nargs='+', help='List of wordlists to interleave and deduplicate')
    parser.add_argument('-o', '--output', required=True, help='Output wordlist file')
    args = parser.parse_args()

    # Interleave the wordlists and save the result to the output file
    interleave_wordlists(args.wordlists, args.output)

