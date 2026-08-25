import os
import sys

# Check if the correct number of arguments are provided
if len(sys.argv) != 6:
    print("Usage: python Check_successful_perms.py BASEDIR SUB SES TASK NUM")
    sys.exit(1)

# Parse the command-line arguments
BASEDIR = sys.argv[1]
SUB = sys.argv[2]
SES = sys.argv[3]
TASK = sys.argv[4]
NUM = int(sys.argv[5])

# Initialize lists to store the status of permutations
successful_permutations = []
failed_permutations = []

# Iterate over the permutations
for perm in range(1, NUM + 1):
    half1_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
    half2_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"

    half1_exists = os.path.exists(half1_path)
    half2_exists = os.path.exists(half2_path)

    if half1_exists and half2_exists:
        successful_permutations.append(perm)
    else:
        failed_permutations.append(perm)

# Print summary
print("Successful Permutations:", successful_permutations)
print("Failed Permutations in Either Half:", failed_permutations)

# Generate .conc files for successful and failed permutations with sub and ses in the filename
half1_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half1.conc")
half2_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half2.conc")
failed_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_failed_either_half.conc")

with open(half1_conc_path, 'w') as half1_conc, open(half2_conc_path, 'w') as half2_conc, open(failed_conc_path, 'w') as failed_conc:
    for perm in successful_permutations:
        half1_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")
        half2_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

    for perm in failed_permutations:
        failed_conc.write(f"{perm}\n")

print("Conc files generated for successful permutations and failed permutations in either half.")
