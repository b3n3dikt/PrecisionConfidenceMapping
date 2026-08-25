# Figure Maker Wrapper

## Purpose

This script reads a `.dscalar.nii` or `.dlabel.nii` file, loads it onto a very inflated surface model, and automatically outputs an image file.

## Installation

Clone this repository and save it somewhere on the Linux/Unix system that you want to use it from.

## Dependencies

1. [Python 3.5.2](https://www.python.org/downloads/release/python-352) or greater

## Usage

This script uses Python's `argparse` package, so it should be run from the BASH command line and accept command-line arguments.

### Examples

Here is an example of a valid call to this script:
```
python3 ./figure_maker_wrapper.py --subject-scalar ./group1_dscalar_AVG.dlabel.nii --output ./output/figure.png --label-lower -1 --label-upper 1 --threshold-image --threshold-lower 0 --threshold-upper 10 
```

### Basic Usage Arguments

- These arguments can be given in any order.
- The `--subject-scalar` argument is the only argument that is always required.
- If the `--label` flag is included, its `lower` and `upper` bound arguments must also be included. Otherwise, the bound arguments are unneeded. The same applies to the required arguments with the word `threshold`.

| Flag | Default | Description of Argument |
|-:|:-:|:-|
| `--subject-scalar` | N/A | Required. Path to subject `dscalar` or `dlabel` file. |
|  `--output` | `./figure.png` | Path to output image file. By default, it will be a `.png` file.<sup>1</sup> |
| `--label-lower` | Depends on `dscalar` vs. `dlabel` | Lower scale limit for color pallet. |
| `--label-upper` | Depends on `dscalar` vs. `dlabel` | Upper scale limit for color pallet. |
| `--palette-name`    | `ROY-BIG-BL` | Supply the name of the color palette. All of the color palette options are listed below.<sup>2</sup> |
| `--threshold-image` | N/A (`FALSE`) | Include this flag if you want to exclude data inside or outside of a specific threshold.
| `--threshold-lower` | Depends on `dscalar` vs. `dlabel` | Lower threshold for color pallet. |
| `--threshold-upper` | Depends on `dscalar` vs. `dlabel` | Upper threshold for color pallet. |
| `--threshold-inside` | `THRESHOLD_TEST_SHOW_OUTSIDE` | Include this flag to set data exclusion threshold to `THRESHOLD_TEST_SHOW_INSIDE` instead of `THRESHOLD_TEST_SHOW_OUTSIDE`. |
| `--make-quad` | N/A (`FALSE`) | Include this flag to make DV view. By default, it won't. |
| `--make-subcorticals` | `FALSE` | Include this flag to create new images that show parasaggital, coronal, and axial views. |
| `--width-in-cm` | `8` | Width in centimeters of the final image. |
| `--dots-per-cm` | `118` | Dots per centimeter (dpcm) in the final image. The default value, 118, will give 300 dots per inch (dpi). |
| `--save-scene-file` | N/A (`FALSE`) | Include this flag to save the scene file. Helpful for debugging. |
| `--wb-command` | (Depends on server) | Path to workbench command file (`wb_command`). Default depends on which server the script is run from. |

#### Notes

<sup>1</sup> Output file must be in one of the accepted image formats listed below:
```
.bmp  .pbm  .pgm  .png  .ppm  .xbm
```

<sup>2</sup> Color palette options include all of the following:
```
ROY-BIG-BL, videen_style, Gray_Interp_Positive, fidl, Gray_Interp, PSYCH, RGBYR20, RGBYR20P, Orange-Yellow, POS_NEG_ZERO, red-yellow, blue-lightblue, FSL, power_surf, fsl_red, fsl_green, fsl_blue, fsl_yellow, JET256, PSYCH, PSYCH-NO-NONE, ROY-BIG, clear_brain, raich4_clrmid, raich6_clrmid, HSB8_clrmid, POS_NEG
```

### Advanced Usage Arguments

| Optional Flag | Default Value or File Name if Flag is Excluded | Description of Argument |
|-:|:-:|:-|
| `--template-scene` | `MSC01_template_quad_scaled_v3_legend.scene` | Path to the template scene file to use as a default for making a new scene file. |
| `--template-file` | `ABCD_10min_GRP1_singlenet_percentage_` `n2988_Aud_network_percentage.dscalar.nii` | First dscalar file found in a scene. The new value will be a user-chosen dscalar file. |
| `--old-template-file` | `ABCD_10min_GRP1_overlap_percentage_` `n1800_Aud_network_percentage.dscalar.nii` | Path to the second template dscalar file specified in the template scene file. |
| `--template-scene-name` | `MSC01_templace_scene` | Default value for the scene name in the template scene file, to be replaced by a new value. |
| `--label-lower-default` | `-22.222000` | Default value for the color pallet lower scale limit, to be replaced by a new value. |
| `--label-upper-default` | `44.444000` | Default value for the color pallet upper scale limit, to be replaced by a new value. |
| `--threshold-image-default` | `THRESHOLD_TYPE_NORMAL` | Default value for whether the threshold will be normalized. | 
| `--threshold-lower-default` | `55.555000` | Default value for the color pallet lower threshold, to be replaced by a new value. | 
| `--threshold-upper-default` | `66.666000` | Default value for the color pallet upper threshold, to be replaced by a new value. | 
| `--threshold-inout-default` | `THRESHOLD_TEST_SHOW_OUTSIDE` | Default value for the binary in/out threshold, to be replaced by a new value. |
| `--default-palette-name`    | `ROY-BIG-BL` | Default value for the color palette name, to be replaced by a new value. |
| `--continuous-smaller-negative` | `-33.333000` | Default value for the smaller negative on the continuous scale. |
| `--continuous-smaller-positive` | `11.111000` | Default value for the smaller positive on the continuous scale. |

## Metadata

### Credits for figure maker script

- Original BASH script written by Robert Hermosillo
- Original BASH script modified by Eric Feczko
- Python wrapper written by Greg Conan

### Information about this `README` file

- Created by Greg Conan, 2019-12-26
- Updated by Greg Conan, 2020-04-20
