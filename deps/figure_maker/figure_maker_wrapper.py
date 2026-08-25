#! /usr/bin/env python3

"""
Figure Maker Wrapper
Greg Conan: conan@ohsu.edu
Created 2019-12-18
Updated 2020-04-20
"""

###########################################################
#
# Wrapper for figure maker script: make_dscalar_pics_v*.sh
#
###########################################################


#########################################
# Imported packages and global constants
#########################################

# Imports
import argparse
import datetime
import os
import socket
import subprocess
import sys

# Get script's own location for relative paths
try:
    PWD = os.path.dirname(os.path.abspath(sys.argv[0]))
except OSError:
    sys.exit("{} could not find its own location".format(sys.argv[0]))
CURRENT_FIGURE_MAKER_SCRIPT = os.path.join(PWD, "make_dscalar_pics_v9.2.sh")
DEFAULT_OUTPUT = os.path.join(PWD, "figure")

# Hardcoded paths to Exacloud locations 
EXA_PATH = "/home/exacloud/lustre1/fnl_lab"
FOLDER_FOR_TEMPLATES = os.path.join(
    EXA_PATH, "code/internal/analyses/compare_matrices/ABCD_percentage_maps/"
)

# Hardcoded paths to template files, depending on --label flag
LABEL_NAME = "placeholder_template_scene"
LABEL_SCENE = os.path.join("/home/exacloud/lustre1/fnl_lab/code/internal/"
                            "utilities/make_dscalar_pics/template_"
                            "veryinflated_label.scene")
LABEL_TEMPLATE = "/place_holder_path/placeholder.dlabel.nii"
NO_LABEL_NAME = "MSC01_template_scene"
NO_LABEL_SCENE = os.path.join(PWD, "template_very_inflated.scene")
NO_LABEL_TEMPLATE = os.path.join(FOLDER_FOR_TEMPLATES,
                                 ("ABCD_10min_GRP1_singlenet_percentage_"
                                  "n2988_Aud_network_percentage.dscalar.nii"))

# Options for color palettes and for image extensions
PALETTES = ["ROY-BIG-BL", "videen_style", "Gray_Interp_Positive", "fidl", 
            "Gray_Interp", "PSYCH", "RBGYR20", "RBGYR20P", "Orange-Yellow",
            "POS_NEG_ZERO", "red-yellow", "blue-lightblue", "FSL",
            "power_surf", "fsl_red", "fsl_green", "fsl_blue", "fsl_yellow", 
            "JET256", "PSYCH", "PSYCH-NO-NONE", "ROY-BIG", "clear_brain", 
            "raich4_clrmid", "raich6_clrmid", "HSB8_clrmid", "POS_NEG"]
VALID_IMAGE_EXTENSIONS = ("bmp", "pbm", "pgm", "png", "ppm", "xbm")

# Hardcoded paths to workbench files
WB_EXACLOUD = os.path.join(EXA_PATH, (
    "code/external/utilities/workbench-1.3.2/bin_rh_linux64/wb_command"
))
WB_RUSHMORE = "/mnt/max/software/workbench/bin_linux64/wb_command"


##############################################
# Main functions to start running this script
##############################################


def main():

    # Store and print the date and time when this script started running
    print("Running {} while in directory {}".format(sys.argv[0], PWD))
    starting_timestamp = get_and_print_timestamp_when(sys.argv[0], "started")

    # Run the script
    call_figure_maker(get_cli_args())

    # Print the date and time when this script started and finished running
    print(starting_timestamp)
    get_and_print_timestamp_when(sys.argv[0], "finished")


def get_cli_args():
    """
    Get and validate all args from command line using argparse.
    :return: Dictionary mapping strings naming all command-line arguments to
             the validated values of those arguments
    """
    # Default numerical values
    default_dpcm = "118"
    default_width = "8"  # Default width in cm

    # Strings used multiple times in help messages
    decimal_fmt_msg = (" Format this number like -33.3 or 1.0 or 0.0, as a "
                       "number with a decimal point.")
    default_val_msg = "The default value for {}. "
    will_replace_msg = "This will be replaced with the new value."

    # Parser object
    parser = argparse.ArgumentParser(
        description=("Wrapper for figure maker script, which was designed to "
                     "read a dscalar, load it onto a very inflated surface "
                     "model, and automatically output a .png file.")
    )

    # Basic usage
    parser.add_argument(
        "-scalar",
        "-subject",
        "--subject-scalar",
        type=valid_subject_file,
        required=True,
        help="Full valid path to subject .dscalar or .dlabel file."
    )
    parser.add_argument(
        "-out",
        "--output",
        "--output-filename",
        dest="output",
        default=DEFAULT_OUTPUT,
        type=valid_output_file,
        help="Path to output image file. By default it will be a .png file."
    )
    parser.add_argument(
        "-label-low",
        "--label-lower",
        type=float,
        help="Lower scale limit number for color palette."
    )
    parser.add_argument(
        "-label-up",
        "--label-upper",
        type=float,
        help="Upper scale limit number for color palette."
    )
    parser.add_argument(
        "-colors",
        "--palette-name",
        default=PALETTES[0],
        choices=PALETTES,
        help=("Supply the name of the color palette. The options are: {}"
              .format(PALETTES))
    )
    parser.add_argument(
        "-thresh-img",
        "--threshold-image",
        action="store_const",
        const="TRUE",
        default="FALSE",
        dest="threshold",
        help=("Include this flag if you want to exclude data outside/inside "
              "thresholds, the palette is assumed to be Power Colors. If this "
              "flag is included, then the scene file will use RBG colors.")
    )
    parser.add_argument(
        "-thresh-low",
        "--threshold-lower",
        type=float,
        help="Lower threshold number for color palette."
    )
    parser.add_argument(
        "-thresh-up",
        "--threshold-upper",
        type=float,
        help="Upper threshold number for color palette."
    )
    parser.add_argument(
        "-thresh-in",
        "--threshold-inside",
        action="store_const",
        const="THRESHOLD_TEST_SHOW_INSIDE",
        default="THRESHOLD_TEST_SHOW_OUTSIDE",
        help="Set threshold to 'inside'. By default, it will be 'outside'."
    )
    parser.add_argument(
        "-quad",
        "--make-quad",
        action="store_const",
        const="TRUE",
        default="FALSE",
        help="Make DV view."
    )
    parser.add_argument(
        "-sub",
        "--make-subcorticals",
        action="store_const",
        const="TRUE",
        default="FALSE",
        help=("Creates new images that show PA (parasaggital), CO (coronal), "
              "and AX (axial) views.")
    )
    parser.add_argument(
        "-width",
        "--width-in-cm",
        default=default_width,
        type=valid_whole_number_as_string,
        help=("Provide the width in centimeters of the final image. By "
              "default, the image will be {}cm wide.".format(default_width))
    )
    parser.add_argument(
        "-dpcm",
        "--dots-per-cm",
        "--dots-per-centimeter",
        default=default_dpcm,
        dest="dpcm",
        type=valid_whole_number_as_string,
        help=("Dots per centimeter in the final image. The default value, {}, "
              "will give 300 dots per inch (dpi).".format(default_dpcm))
    )
    parser.add_argument(
        "-save",
        "--save-scene-file",
        action="store_const",
        const="TRUE",
        default="FALSE",
        help=("Include this flag to save the scene file. Helpful for "
              "debugging.")
    )
    parser.add_argument(
        "-wb",
        "--wb-command",
        type=valid_readable_file,
        help="Path to workbench command file called 'wb_command'."
    )

    # Advanced Usage (optional arguments, not all need to be specified)
    parser.add_argument(
        "-temp-scene",
        "--template-scene",
        type=valid_scene_file,
        help=("The path to the template scene file to use as a default for "
              "making a new scene file.")
    )
    parser.add_argument(
        "-temp-file",
        "--template-file",
        type=valid_subject_file,
        help=default_val_msg.format(
            "The first dscalar file found in a scene. The new value will be "
            "a dscalar or dlabel file specified by the user"
        ) + will_replace_msg
    )
    parser.add_argument(
        "-temp-old",
        "--old-template-file",
        type=valid_subject_file,
        default=os.path.join(FOLDER_FOR_TEMPLATES, "n1800_old",
                             ("ABCD_10min_GRP1_overlap_percentage_n1800_"
                              "Aud_network_percentage.dscalar.nii")),
        help=("The path to the second template dscalar file specified in the "
              "template scene file.")
    )
    parser.add_argument(
        "-temp-name",
        "--template-scene-name",
        help=default_val_msg.format("the scene name found within the template "
                                    "scene file") + will_replace_msg
    )
    parser.add_argument(
        "-label-low-def",
        "--label-lower-default",
        type=valid_decimal_str,
        help=default_val_msg.format("the color palette lower scale limit"
                                    ) + will_replace_msg + decimal_fmt_msg
    )   
    parser.add_argument(
        "-label-up-def",
        "--label-upper-default",
        type=valid_decimal_str,
        help=default_val_msg.format("the color palette upper scale limit"
                                    ) + will_replace_msg + decimal_fmt_msg
    )
    parser.add_argument(
        "-thresh-img-def",
        "--threshold-image-default",
        default="THRESHOLD_TYPE_NORMAL",
        help=default_val_msg.format("whether the threshold will be visualized"
                                    ) + will_replace_msg
    )
    parser.add_argument(
        "-thresh-low-def",
        "--threshold-lower-default",
        type=valid_decimal_str,
        default="55.555000",
        help=default_val_msg.format("the color palette lower threshold"
                                    ) + will_replace_msg + decimal_fmt_msg
    )
    parser.add_argument(
        "-thresh-up-def",
        "--threshold-upper-default",
        type=valid_decimal_str,
        default="66.666000",
        help=default_val_msg.format("the color palette upper threshold"
                                    ) + will_replace_msg + decimal_fmt_msg
    )
    parser.add_argument(
        "-thresh-in-def",
        "--threshold-inout-default",
        default="THRESHOLD_TEST_SHOW_OUTSIDE",
        help=default_val_msg.format("the binary in/out threshold"
                                    ) + will_replace_msg
    )
    parser.add_argument(
        "-default-colors",
        "--default-palette-name",
        default=PALETTES[0],
        choices=PALETTES,
        help=default_val_msg.format("the color palette name") + will_replace_msg
    )
    parser.add_argument(
        "-con-small-neg",
        "--continuous-smaller-negative",
        default="-33.333000",
        type=valid_decimal_str,
        help=default_val_msg.format("the smaller negative on the continuous "
                                    "scale") + decimal_fmt_msg
    )
    parser.add_argument(
        "-con-small-pos",
        "--continuous-smaller-positive",
        default="11.111000",
        type=valid_decimal_str,
        help=default_val_msg.format("the smaller positive on the continuous "
                                    "scale") + decimal_fmt_msg
    )

    return validate_cli_args(vars(parser.parse_args()), parser) 


###############################################
# Functions to Define Valid Types for argparse
###############################################


def validate(user_input, is_real, make_valid, err_msg, prepare=None):
    """
    Parent/base function used by different type validation functions. Raises an
    argparse.ArgumentTypeError if the user_input is somehow invalid.
    :param user_input: String from the user, to be validated
    :param is_real: Function which returns True only if user_input is valid
    :param make_valid: Function which returns a fully validated user_input
    :param err_msg: String to show to user to tell them what is invalid
    :param prepare: Function to prepare user_input for validation
    :return: user_input, but fully validated
    """
    try:
        if prepare:
            prepare(user_input)
        assert is_real(user_input)
        return make_valid(user_input)
    except (OSError, TypeError, AssertionError, ValueError, 
            argparse.ArgumentTypeError):
        raise argparse.ArgumentTypeError(err_msg.format(user_input))


def none_or_valid_float_value_as_string(to_check):
    """
    Unless a string is "none", tries to convert it to a float and back to check
    that it represents a valid float value. Throws ValueError if type
    conversion fails. This function is only needed because the MATLAB scripts
    take some arguments either as a float value in string form or as "none".
    :param to_check: string to validate
    :return: string which is either "none" or represents a valid float value
    """
    return (to_check if isinstance(to_check, str) and to_check.lower() == "none"
            else str(float(to_check)))


def valid_scene_file(path):
    """
    Throw argparse exception unless parameter is a valid path to a .scene file
    :param path: String to check if it represents a valid .scene file path
    :return: String which is a valid path to a readable .scene file
    """
    return validate(path, lambda x: os.path.splitext(x)[1] == ".scene",
                    valid_readable_file, "{} is not a valid .scene file")


def valid_subject_file(path):
    """
    Throw argparse exception unless parameter is a valid dscalar file path
    :param path: String to check if it represents a valid dscalar file path
    :return: String representing a valid path to a readable .dscalar.nii file
    """
    return validate(path, lambda x: get_2_exts_of(x) in
                    (".dscalar.nii", ".dlabel.nii"), valid_readable_file,
                    "{} is not a valid subject file")


def get_2_exts_of(path):
    """
    :param path: String representing a file path with two extensions
    :return: String with just those two extensions (like ".dscalar.nii")
    """
    splitext = os.path.splitext(path)
    return os.path.splitext(splitext[0])[-1] + splitext[-1]


def valid_decimal_str(numstr):
    """
    Throw an argparse error unless numstr is a decimal number as a string
    :param numstr: Object to check if it is a string representing a number
    :return: numstr
    """
    return validate(numstr, lambda x: (isinstance(x, str) and "." in x),
                    lambda y: y, "{} is not a valid decimal number value.",
                    float)


def valid_whole_number_as_string(numstr):
    """
    Throw an argparse error unless numstr is an integer as a string
    :param numstr: Object to check if it is a string representing an integer
    :return: numstr
    """
    return validate(numstr, lambda x: isinstance(x, str) and int(x) >= 0,
                    lambda y: y, "{} is not a valid integer value.")


def valid_output_file(path):
    """
    Try to create a directory to write files into at the given path, and throw 
    argparse exception if that fails
    :param path: String which is a valid (not necessarily real) file path
    :return: String which is a valid absolute path to a file to write later
    """
    
    def is_valid_image_file(imgfile):
        """
        :param imgfile: String which is a file path
        :return: True if imgfile is in a real writeable directory; else False
        """
        return (os.access(os.path.dirname(imgfile), os.W_OK))

    def validate_img_file(img):
        """
        :param img: String which is a valid file path
        :return: String which is an absolute path to a file with a valid image
                 file extension (e.g. .png)
        """
        imgfile_ext = os.path.splitext(img)[1][1:]
        if imgfile_ext not in VALID_IMAGE_EXTENSIONS:
            assert imgfile_ext == ""
            img += ".png"
        return os.path.abspath(img)

    return validate(path, is_valid_image_file, validate_img_file, 
                    "Cannot write {} as an image file.", 
                    lambda x: os.makedirs(os.path.dirname(x), exist_ok=True))


def valid_readable_file(path):
    """
    Throw exception unless parameter is a valid readable filename string. This
    is used instead of argparse.FileType("r") because the latter leaves an open
    file handle, which has caused problems.
    :param path: Parameter to check if it represents a valid filename
    :return: String representing a valid filename
    """
    return validate(path, lambda x: os.access(x, os.R_OK), os.path.abspath,
                    "Cannot read file at {}")


##############################################
# Functions for Post-argparse Type Validation
##############################################


def validate_cli_args(cli_args, parser):
    """
    :param cli_args: Dictionary mapping strings naming argparse arguments to 
                     those arguments' values given via the command line
    :param parser: argparse.ArgumentParser to raise error if anything's invalid
    :return: cli_args, but with all of its values validated
    """
    # Check if input file is dlabel or dscalar
    cli_args["label"] = {
        ".dlabel.nii": "TRUE",
        ".dscalar.nii": "FALSE"
    }[get_2_exts_of(cli_args["subject_scalar"])]
    label = cli_args["label"] == "TRUE"

    # Check that threshold and label arguments include bounds
    require_bounds("label", cli_args, parser)
    require_bounds("threshold", cli_args, parser)

    # Change the default args depending on whether user gave a DLABEL file
    label_up_def, label_low_def = get_default_label_def(cli_args, parser)
    get_default = {
        "label_lower_default": label_low_def,
        "label_upper_default": label_up_def,
        "template_file": LABEL_TEMPLATE if label else NO_LABEL_TEMPLATE,
        "template_scene": LABEL_SCENE if label else NO_LABEL_SCENE,
        "template_scene_name": LABEL_NAME if label else NO_LABEL_NAME,
        "threshold_upper_default": "55.555000",
        "threshold_lower_default": "66.666000",
        "wb_command": get_valid_wb_command()
    }
    for arg in get_default.keys():
        if cli_args[arg] is None:
            cli_args[arg] = get_default[arg]

    # Verify that lower threshold is less than upper threshold
    for thr in ((cli_args["threshold_upper"], cli_args["threshold_lower"]),
                (cli_args["label_upper"], cli_args["label_lower"]),
                (cli_args["label_upper_default"],
                 cli_args["label_lower_default"])):
        if (None not in thr and "None" not in thr 
                and float(thr[0]) <= float(thr[1])):
            parser.error("Lower threshold ({}) must be lower than upper "
                         "threshold ({}).".format(thr[0], thr[1]))

    return cli_args


def require_bounds(bound, cli_args, parser):
    """
    Throw argparse error if user included a bound argument but not its lower
    or upper bounds, e.g. including --threshold but not --threshold-lower
    :param bound: String naming the cli_args arguments to check
    :param cli_args: Dictionary mapping strings naming argparse arguments to 
                     those arguments' values given via the command line
    :param parser: argparse.ArgumentParser to raise error if anything's invalid
    :return: N/A
    """
    if cli_args[bound] == "TRUE" and None in (cli_args[bound + "_upper"],
                                              cli_args[bound + "_lower"]):
        parser.error("Since {0} flag is TRUE, you must include the "
                     "--{0}-upper and --{0}-lower arguments.".format(bound))


def get_default_label_def(cli_args, parser):
    """
    :param cli_args: Dictionary mapping strings naming argparse arguments to 
                     those arguments' values given via the command line
    :param parser: argparse.ArgumentParser to raise error if anything's invalid
    :return: Tuple of 2 strings with the default upper and lower bound values
    """
    if cli_args["label"] == "TRUE":
        up = "44.444000" if cli_args["label_upper"] > 0 else "-33.333000"
        dn = "11.111000" if cli_args["label_lower"] >= 0 else "-22.222000"
    else:
        up = "44.444000"
        dn = "11.111000"
    return up, dn


def get_and_print_timestamp_when(script, did_what):
    """
    Print and return a string showing the exact date and time when the current 
    running script reached a certain part of its process
    :param script: String which is name of script that started/finished
    :param did_what: String which is a past tense verb describing what script 
                     did at the timestamp, like "started" or "finished"
    :return: String with an easily human-readable message showing when a script
             either started or finished
    """
    timestamp = "\n{} {} at {}.".format(
        script, did_what,
        datetime.datetime.now().strftime("%H:%M:%S on %b %d, %Y")
    )
    print(timestamp)
    return timestamp
    

def get_valid_wb_command():
    """
    Try to find a valid workbench command file by checking the BASH path, by
    checking default locations on known servers, or finally by asking the user
    :return: String representing a valid path to the wb_command file
    """
    # If wb_command is already in BASH $PATH, then get it and format it properly
    try:
        wb_command = str(subprocess.check_output(("which", "wb_command"
                                                  )).decode("utf-8").strip())

    # Otherwise, use hardcoded wb_command depending on host server, or get
    # wb_command from user if host server is not known
    except (subprocess.CalledProcessError, OSError):

        # If host server is RUSHMORE or EXACLOUD, then get its wb_command
        host = socket.gethostname()
        if host == "rushmore":
            wb_command = WB_RUSHMORE
        elif "exa" in host:
            wb_command = WB_EXACLOUD

        # If on an unknown host, either quit if user says to, or get wb_command
        # from user and validate it
        else:
            print("No workbench command found on {}.".format(host))
            while not os.access(wb_command, os.R_OK):
                wb_command = input("Please enter a valid path to a workbench "
                                   "command, or 'q' to end the program: ")
                if wb_command == "q":
                    sys.exit(1)

    return valid_readable_file(wb_command)


###########################################
# Calling the External Figure Maker Script
###########################################


def call_figure_maker(cli_args):
    """
    Run the figure maker script by passing all needed parameters into it
    :param cli_args: Dictionary mapping strings naming cli_args arguments to 
                     those arguments' values given via the command line
    :return: N/A
    """
    # Split some of the cli_args paths into their root and basename components
    outputfolder, filename = os.path.split(cli_args["output"])
    shortfilename, image_extension = os.path.splitext(filename)
    templatefolder, templatefile = os.path.split(cli_args["template_file"])
    old_temp_dir, old_temp_file = os.path.split(cli_args["old_template_file"])
    old_temp_dir += "/"
    templatefolder += "/"

    # Call figure maker script with all input arguments in the right order
    cmd = ((CURRENT_FIGURE_MAKER_SCRIPT,
            cli_args["subject_scalar"],
            shortfilename, outputfolder,
            cli_args["label"],
            str(cli_args["label_lower"]),
            str(cli_args["label_upper"]),
            cli_args["palette_name"],
            cli_args["threshold"],
            str(cli_args["threshold_lower"]),
            str(cli_args["threshold_upper"]),
            cli_args["threshold_inside"],
            cli_args["make_quad"],
            cli_args["make_subcorticals"],
            image_extension[1:],
            cli_args["width_in_cm"],
            cli_args["dpcm"],
            cli_args["save_scene_file"],  
            cli_args["wb_command"],
            cli_args["template_scene"],
            templatefile, templatefolder,
            old_temp_dir, old_temp_file,
            cli_args["template_scene_name"],
            cli_args["label_upper_default"],
            cli_args["label_lower_default"],
            cli_args["threshold_image_default"],
            cli_args["threshold_lower_default"],
            cli_args["threshold_upper_default"],
            cli_args["threshold_inout_default"],
            cli_args["default_palette_name"],
            cli_args["continuous_smaller_negative"],
            cli_args["continuous_smaller_positive"]))
    print(cmd)
    subprocess.check_call(cmd)
 

if __name__ == "__main__":
    main()
