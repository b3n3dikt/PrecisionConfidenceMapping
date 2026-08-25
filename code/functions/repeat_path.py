import sys
import argparse

def repeat_path_in_file(n, file_path, out_path):
    try:
        with open(out_path, 'w') as f:
            for _ in range(n):
                f.write(f"{file_path}\n")
        print(f"Successfully wrote {file_path} {n} times to {out_path}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Repeat a file path in an output file.')
    parser.add_argument('number', type=int, help='The number of times to repeat the file path.')
    parser.add_argument('file_path', type=str, help='The file path to repeat.')
    parser.add_argument('out_path', type=str, help='The output file path (with desired extension).')

    args = parser.parse_args()
    
    repeat_path_in_file(args.number, args.file_path, args.out_path)