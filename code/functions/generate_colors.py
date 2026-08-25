#!/usr/bin/env python3
import sys

def generate_gradient(start_hex, end_hex, num_bins):
    start_rgb = tuple(int(start_hex[i:i+2], 16) for i in (1, 3, 5))
    end_rgb = tuple(int(end_hex[i:i+2], 16) for i in (1, 3, 5))

    r_step = (end_rgb[0] - start_rgb[0]) / (num_bins - 1)
    g_step = (end_rgb[1] - start_rgb[1]) / (num_bins - 1)
    b_step = (end_rgb[2] - start_rgb[2]) / (num_bins - 1)

    gradient = [
        f"#{round(start_rgb[0] + r_step * i):02X}"
        f"{round(start_rgb[1] + g_step * i):02X}"
        f"{round(start_rgb[2] + b_step * i):02X}"
        for i in range(num_bins)
    ]

    print(" ".join(gradient))  # No extra quotes!

# Read arguments from the command line
if __name__ == "__main__":
    start_hex = sys.argv[1]
    end_hex = sys.argv[2]
    num_bins = int(sys.argv[3])
    generate_gradient(start_hex, end_hex, num_bins)


# import sys

# def generate_gradient(start_hex, end_hex, num_bins):
#     start_rgb = tuple(int(start_hex[i:i+2], 16) for i in (1, 3, 5))
#     end_rgb = tuple(int(end_hex[i:i+2], 16) for i in (1, 3, 5))

#     r_step = (end_rgb[0] - start_rgb[0]) / (num_bins - 1)
#     g_step = (end_rgb[1] - start_rgb[1]) / (num_bins - 1)
#     b_step = (end_rgb[2] - start_rgb[2]) / (num_bins - 1)

#     gradient = [
#         f"#{round(start_rgb[0] + r_step * i):02X}"
#         f"{round(start_rgb[1] + g_step * i):02X}"
#         f"{round(start_rgb[2] + b_step * i):02X}"
#         for i in range(num_bins)
#     ]
    
#     print(" ".join(f'"{color}"' for color in gradient))  # Print formatted for Bash use

# # Read arguments from command line
# if __name__ == "__main__":
#     start_hex = sys.argv[1]
#     end_hex = sys.argv[2]
#     num_bins = int(sys.argv[3])
#     generate_gradient(start_hex, end_hex, num_bins)