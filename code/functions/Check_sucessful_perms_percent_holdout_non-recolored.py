import os
import sys

print(f"Received arguments: {sys.argv}")
print(f"Number of arguments received: {len(sys.argv)}")

# Check if the correct number of arguments are provided
if len(sys.argv) != 10:
    print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
    sys.exit(1)

# Parse the command-line arguments
BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout = sys.argv[1:]
NUM = int(NUM)
SURF_ONLY = int(SURF_ONLY)
SPLITHALF = int(SPLITHALF)
SPLITPCT = int(SPLITPCT)
percent_holdout = int(percent_holdout)

# Configure template and labels based on SURF_ONLY value
templates = {
    0: ('abcd', 'subcort_included'),
    1: ('abcd', 'surfonly'),
    2: ('abcd-SCAN', 'SCAN_network'),
    3: ('abcd-SCAN', 'SCAN_network')
}
TEMPLATE, SURF_ONLY_LABEL = templates.get(SURF_ONLY, ('abcd', 'SCAN_network'))

# Initialize dictionaries to store the status of permutations
successful_permutations = {}
failed_permutations = {}
failed_either_half = set()

# Function to check permutations for a given filename suffix
def check_permutations(comparison_folder, suffix):
    local_successful = []
    local_failed = []
    for perm in range(1, NUM + 1):
        file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3{suffix}.dscalar.nii"
        if os.path.exists(file_path):
            local_successful.append(perm)
        else:
            local_failed.append(perm)
            if comparison_folder in ['Half1', 'Half2'] and suffix == '_recolored':
                failed_either_half.add(perm)
    return local_successful, local_failed

# Wrapper function to check both recolored and non-recolored permutations
def process_comparisons(comparison_folder):
    # For recolored
    successful_recolored, failed_recolored = check_permutations(comparison_folder, '_recolored')
    successful_permutations[comparison_folder] = successful_recolored
    failed_permutations[comparison_folder] = failed_recolored

    if successful_recolored:
        print(f"Successful {comparison_folder} Permutations (recolored): {successful_recolored}")
    if failed_recolored:
        print(f"Failed {comparison_folder} Permutations (recolored): {failed_recolored}")

    # For non-recolored
    successful_non_recolored, _ = check_permutations(comparison_folder, '')
    successful_permutations[f"{comparison_folder}_non-recolored"] = successful_non_recolored

    if successful_non_recolored:
        print(f"Successful {comparison_folder} Permutations (non-recolored): {successful_non_recolored}")

# Checking Split Half
if SPLITHALF == 1:
    process_comparisons('Half1')
    process_comparisons('Half2')
    print("Failed Permutations in Either Half (recolored):", list(failed_either_half))

# Checking Percent Holdout
if SPLITPCT == 1:
    folder = f"Percent_holdout-{percent_holdout}"
    process_comparisons(folder)

# Generate .conc files
def generate_conc_file(permutations, filename, comparison_folder, suffix, is_successful=True):
    path = os.path.join(BASEDIR, f"{filename}.conc")
    with open(path, 'w') as file:
        for perm in permutations:
            if is_successful:
                file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3{suffix}.dscalar.nii\n")
            else:
                file.write(f"{perm}\n")

if SPLITHALF == 1:
    generate_conc_file(successful_permutations.get('Half1', []), f"sub-{SUB}_ses-{SES}_successful_half1", "Half1", '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get('Half2', []), f"sub-{SUB}_ses-{SES}_successful_half2", "Half2", '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get('Half1_non-recolored', []), f"sub-{SUB}_ses-{SES}_successful_non-recolored_half1", "Half1", '', is_successful=True)
    generate_conc_file(successful_permutations.get('Half2_non-recolored', []), f"sub-{SUB}_ses-{SES}_successful_non-recolored_half2", "Half2", '', is_successful=True)
    generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half", "Half1", '_recolored', is_successful=False)

if SPLITPCT == 1:
    folder = f"Percent_holdout-{percent_holdout}"
    generate_conc_file(successful_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}", folder, '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get(f"{folder}_non-recolored", []), f"sub-{SUB}_ses-{SES}_successful_non-recolored_percent_holdout-{percent_holdout}", folder, '', is_successful=True)
    generate_conc_file(failed_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}", folder, '_recolored', is_successful=False)



print("Conc files generated for all successful and failed permutations checks.")

