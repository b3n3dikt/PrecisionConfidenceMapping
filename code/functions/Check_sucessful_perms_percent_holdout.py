import os
import sys
import glob

print(f"Received arguments: {sys.argv}")
print(f"Number of arguments received: {len(sys.argv)}")

# ── Argument dispatch ─────────────────────────────────────────────────────────
# New-style call (7 or 8 args): BASEDIR SUB SES TASK NUM TASK_FOLDER SPLITHALF
# Old-style call (10 or 11 args): BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF
#                                  SPLITPCT percent_holdout [METHOD]

if len(sys.argv) in (8, 9):
    # New-style: 7 positional args (argv[1..7]), optional 8th ignored
    BASEDIR, SUB, SES, TASK, NUM, TASK_FOLDER, SPLITHALF = sys.argv[1:8]
    NUM = int(NUM)
    SPLITHALF = int(SPLITHALF)

    TASK_DIR = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK_FOLDER}"
    perms_dir = f"{TASK_DIR}/perms"

    successful_perms = []
    failed_perms = []
    successful_half1 = []
    successful_half2 = []
    failed_either_half = []

    def recolored_in(d):
        # Method-agnostic completion check: matlab_tm and reprotm name their
        # output dscalars differently, so match any *recolored.dscalar.nii in
        # the folder instead of an exact name.
        hits = sorted(glob.glob(os.path.join(d, "*recolored.dscalar.nii")))
        return hits[0] if hits else None

    for perm in range(1, NUM + 1):
        perm_str = f"perm-{perm:04d}"
        perm_dir = f"{perms_dir}/{perm_str}"

        if SPLITHALF == 1:
            h1_path = recolored_in(f"{perm_dir}/half1")
            h2_path = recolored_in(f"{perm_dir}/half2")
            if h1_path:
                successful_half1.append(h1_path)
            if h2_path:
                successful_half2.append(h2_path)
            if not h1_path or not h2_path:
                failed_either_half.append(perm)
        else:
            full_path = recolored_in(perm_dir)
            if full_path:
                successful_perms.append(full_path)
            else:
                failed_perms.append(perm)

    if SPLITHALF == 1:
        # successful_perms_half1.conc / half2.conc — full paths
        with open(f"{TASK_DIR}/successful_perms_half1.conc", 'w') as f:
            for path in successful_half1:
                f.write(path + '\n')
        with open(f"{TASK_DIR}/successful_perms_half2.conc", 'w') as f:
            for path in successful_half2:
                f.write(path + '\n')

        # failed_perms.conc — perm numbers only (union of missing half1 or half2)
        with open(f"{TASK_DIR}/failed_perms.conc", 'w') as f:
            for perm in failed_either_half:
                f.write(str(perm) + '\n')

        print(f"Successful half1 perms: {len(successful_half1)}")
        print(f"Successful half2 perms: {len(successful_half2)}")
        print(f"Failed (either half) perms: {failed_either_half}")
    else:
        # successful_perms.conc — full paths
        with open(f"{TASK_DIR}/successful_perms.conc", 'w') as f:
            for path in successful_perms:
                f.write(path + '\n')

        # failed_perms.conc — perm numbers only
        with open(f"{TASK_DIR}/failed_perms.conc", 'w') as f:
            for perm in failed_perms:
                f.write(str(perm) + '\n')

        print(f"Successful perms: {[p for p in range(1, NUM+1) if p not in failed_perms]}")
        print(f"Failed perms:     {failed_perms}")

    print("Conc files generated for all successful and failed permutations checks.")
    sys.exit(0)

# ── Old-style backward-compatible logic ───────────────────────────────────────
# Check if the correct number of arguments are provided
# METHOD is optional (11th arg) for backward compatibility; defaults to matlab_tm
if len(sys.argv) == 10:
    BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout = sys.argv[1:]
    METHOD = 'matlab_tm'
elif len(sys.argv) == 11:
    BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout, METHOD = sys.argv[1:]
else:
    print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM TASK_FOLDER SPLITHALF")
    print(f"       python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout [METHOD]")
    sys.exit(1)

# Parse the command-line arguments
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

# ── Template matching path helpers ────────────────────────────────────────────
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

# Wrapper function to check both recolored and non_recolored permutations
def process_comparisons(comparison_folder):
    # For recolored
    successful_recolored, failed_recolored = check_permutations(comparison_folder, '_recolored')
    successful_permutations[comparison_folder] = successful_recolored
    failed_permutations[comparison_folder] = failed_recolored

    if successful_recolored:
        print(f"Successful {comparison_folder} Permutations (recolored): {successful_recolored}")
    if failed_recolored:
        print(f"Failed {comparison_folder} Permutations (recolored): {failed_recolored}")

    # For non_recolored
    successful_non_recolored, _ = check_permutations(comparison_folder, '')
    successful_permutations[f"{comparison_folder}_non_recolored"] = successful_non_recolored

    if successful_non_recolored:
        print(f"Successful {comparison_folder} Permutations (non_recolored): {successful_non_recolored}")

# Generate .conc files
def generate_conc_file(permutations, filename, comparison_folder, suffix, is_successful=True):
    path = os.path.join(BASEDIR, f"{filename}.conc")
    with open(path, 'w') as file:
        for perm in permutations:
            if is_successful:
                file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3{suffix}.dscalar.nii\n")
            else:
                file.write(f"{perm}\n")

# ── Run checks ────────────────────────────────────────────────────────────────
# Checking Split Half
if SPLITHALF == 1:
    process_comparisons('Half1')
    process_comparisons('Half2')
    print("Failed Permutations in Either Half (recolored):", list(failed_either_half))

# Checking Percent Holdout
if SPLITPCT == 1:
    folder = f"Percent_holdout-{percent_holdout}"
    process_comparisons(folder)

if SPLITHALF == 1:
    generate_conc_file(successful_permutations.get('Half1', []), f"sub-{SUB}_ses-{SES}_successful_half1", "Half1", '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get('Half2', []), f"sub-{SUB}_ses-{SES}_successful_half2", "Half2", '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get('Half1_non_recolored', []), f"sub-{SUB}_ses-{SES}_successful_non_recolored_half1", "Half1", '', is_successful=True)
    generate_conc_file(successful_permutations.get('Half2_non_recolored', []), f"sub-{SUB}_ses-{SES}_successful_non_recolored_half2", "Half2", '', is_successful=True)
    generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half", "Half1", '_recolored', is_successful=False)

if SPLITPCT == 1:
    folder = f"Percent_holdout-{percent_holdout}"
    generate_conc_file(successful_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}", folder, '_recolored', is_successful=True)
    generate_conc_file(successful_permutations.get(f"{folder}_non_recolored", []), f"sub-{SUB}_ses-{SES}_successful_non_recolored_percent_holdout-{percent_holdout}", folder, '', is_successful=True)
    generate_conc_file(failed_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}", folder, '_recolored', is_successful=False)



print("Conc files generated for all successful and failed permutations checks.")
