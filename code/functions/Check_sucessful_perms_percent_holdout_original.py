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

def check_permutations(comparison_folder):
    local_successful = []
    local_failed = []
    for perm in range(1, NUM + 1):
        file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
        if os.path.exists(file_path):
            local_successful.append(perm)
        else:
            local_failed.append(perm)
            if comparison_folder in ['Half1', 'Half2']:
                failed_either_half.add(perm)
    successful_permutations[comparison_folder] = local_successful
    failed_permutations[comparison_folder] = local_failed
    if local_successful:
        print(f"Successful {comparison_folder} Permutations: {local_successful}")
    if local_failed:
        print(f"Failed {comparison_folder} Permutations: {local_failed}")

# Checking Split Half
if SPLITHALF == 1:
    check_permutations('Half1')
    check_permutations('Half2')
    print("Failed Permutations in Either Half:", list(failed_either_half))

# Checking Percent Holdout
if SPLITPCT == 1:
    check_permutations(f"Percent_holdout-{percent_holdout}")

# Generate .conc files
def generate_conc_file(permutations, filename, comparison_folder, is_successful=True):
    path = os.path.join(BASEDIR, f"{filename}.conc")
    with open(path, 'w') as file:
        for perm in permutations:
            if is_successful:
                file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")
            else:
                file.write(f"{perm}\n")

if SPLITHALF == 1:
    generate_conc_file(successful_permutations.get('Half1', []), f"sub-{SUB}_ses-{SES}_successful_half1", "Half1", is_successful=True)
    generate_conc_file(successful_permutations.get('Half2', []), f"sub-{SUB}_ses-{SES}_successful_half2", "Half2", is_successful=True)
    generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half", "Half1", is_successful=False)

if SPLITPCT == 1:
    folder = f"Percent_holdout-{percent_holdout}"
    generate_conc_file(successful_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}", folder, is_successful=True)
    generate_conc_file(failed_permutations.get(folder, []), f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}", folder, is_successful=False)

#what code was before failing on subjects with sessions that had half1 in them.           
# def generate_conc_file(permutations, filename, is_successful=True):
#     path = os.path.join(BASEDIR, f"{filename}.conc")
#     with open(path, 'w') as file:
#         for perm in permutations:
#             if is_successful:
#                 comparison_folder = 'Half1' if 'half1' in filename else ('Half2' if 'half2' in filename else f"Percent_holdout-{percent_holdout}")
#                 file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")
#             else:
#                 file.write(f"{perm}\n")

# if SPLITHALF == 1:
#     generate_conc_file(successful_permutations.get('Half1', []), f"sub-{SUB}_ses-{SES}_successful_half1", is_successful=True)
#     generate_conc_file(successful_permutations.get('Half2', []), f"sub-{SUB}_ses-{SES}_successful_half2", is_successful=True)
#     generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half", is_successful=False)

# if SPLITPCT == 1:
#     generate_conc_file(successful_permutations.get(f"Percent_holdout-{percent_holdout}", []), f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}", is_successful=True)
#     generate_conc_file(failed_permutations.get(f"Percent_holdout-{percent_holdout}", []), f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}", is_successful=False)

print("Conc files generated for all successful and failed permutations checks.")



# import os
# import sys

# print(f"Received arguments: {sys.argv}")
# print(f"Number of arguments received: {len(sys.argv)}")

# # Check if the correct number of arguments are provided
# if len(sys.argv) != 10:
#     print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
#     sys.exit(1)

# # Parse the command-line arguments
# BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout = sys.argv[1:]
# NUM = int(NUM)
# SURF_ONLY = int(SURF_ONLY)
# SPLITHALF = int(SPLITHALF)
# SPLITPCT = int(SPLITPCT)
# percent_holdout = int(percent_holdout)

# # Configure template and labels based on SURF_ONLY value
# templates = {
#     0: ('abcd', 'subcort_included'),
#     1: ('abcd', 'surfonly'),
#     2: ('abcd-SCAN', 'SCAN_network')
# }
# TEMPLATE, SURF_ONLY_LABEL = templates.get(SURF_ONLY, ('abcd', 'SCAN_network'))

# # Initialize dictionaries to store the status of permutations
# successful_permutations = {}
# failed_permutations = {}
# failed_either_half = set()

# def check_permutations(comparison_folder):
#     local_successful = []
#     local_failed = []
#     for perm in range(1, NUM + 1):
#         file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#         if os.path.exists(file_path):
#             local_successful.append(perm)
#         else:
#             local_failed.append(perm)
#             if comparison_folder in ['Half1', 'Half2']:
#                 failed_either_half.add(perm)
#     successful_permutations[comparison_folder] = local_successful
#     failed_permutations[comparison_folder] = local_failed
#     if local_successful:
#         print(f"Successful {comparison_folder} Permutations: {local_successful}")
#     if local_failed:
#         print(f"Failed {comparison_folder} Permutations: {local_failed}")

# # Checking Split Half
# if SPLITHALF == 1:
#     check_permutations('Half1')
#     check_permutations('Half2')
#     print("Failed Permutations in Either Half:", list(failed_either_half))

# # Checking Percent Holdout
# if SPLITPCT == 1:
#     check_permutations(f"Percent_holdout-{percent_holdout}")

# # Generate .conc files
# def generate_conc_file(permutations, filename):
#     path = os.path.join(BASEDIR, f"{filename}.conc")
#     with open(path, 'w') as file:
#         for perm in permutations:
#             comparison_folder = 'Half1' if 'half1' in filename else ('Half2' if 'half2' in filename else f"Percent_holdout-{percent_holdout}")
#             file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

# if SPLITHALF == 1:
#     generate_conc_file(successful_permutations.get('Half1', []), f"sub-{SUB}_ses-{SES}_successful_half1")
#     generate_conc_file(successful_permutations.get('Half2', []), f"sub-{SUB}_ses-{SES}_successful_half2")
#     generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half")

# if SPLITPCT == 1:
#     generate_conc_file(successful_permutations.get(f"Percent_holdout-{percent_holdout}", []), f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}")
#     generate_conc_file(failed_permutations.get(f"Percent_holdout-{percent_holdout}", []), f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}")

# print("Conc files generated for all successful and failed permutations checks.")




# import os
# import sys

# print(f"Received arguments: {sys.argv}")
# print(f"Number of arguments received: {len(sys.argv)}")

# # Check if the correct number of arguments are provided
# if len(sys.argv) != 10:
#     print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
#     sys.exit(1)

# # Parse the command-line arguments
# BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout = sys.argv[1:]
# NUM = int(NUM)
# SURF_ONLY = int(SURF_ONLY)
# SPLITHALF = int(SPLITHALF)
# SPLITPCT = int(SPLITPCT)
# percent_holdout = int(percent_holdout)

# # Configure template and labels based on SURF_ONLY value
# templates = {
#     0: ('abcd', 'subcort_included'),
#     1: ('abcd', 'surfonly'),
#     2: ('abcd-SCAN', 'SCAN_network')
# }
# TEMPLATE, SURF_ONLY_LABEL = templates.get(SURF_ONLY, ('abcd', 'SCAN_network'))

# # Initialize dictionaries to store the status of permutations
# successful_permutations = {'Half1': [], 'Half2': [], f'Percent_holdout-{percent_holdout}': []}
# failed_permutations = {'Half1': [], 'Half2': [], f'Percent_holdout-{percent_holdout}': []}
# failed_either_half = set()

# def check_permutations(comparison_folder):
#     local_successful = []
#     local_failed = []
#     for perm in range(1, NUM + 1):
#         file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#         if os.path.exists(file_path):
#             local_successful.append(perm)
#         else:
#             local_failed.append(perm)
#             if comparison_folder in ['Half1', 'Half2']:
#                 failed_either_half.add(perm)
#     successful_permutations[comparison_folder].extend(local_successful)
#     failed_permutations[comparison_folder].extend(local_failed)
#     if local_successful:
#         print(f"Successful {comparison_folder} Permutations: {local_successful}")
#     if local_failed:
#         print(f"Failed {comparison_folder} Permutations: {local_failed}")

# # Checking Split Half
# if SPLITHALF == 1:
#     check_permutations('Half1')
#     check_permutations('Half2')

# # Checking Percent Holdout
# if SPLITPCT == 1:
#     check_permutations(f"Percent_holdout-{percent_holdout}")

# # Generate .conc files
# def generate_conc_file(permutations, filename):
#     path = os.path.join(BASEDIR, f"{filename}.conc")
#     with open(path, 'w') as file:
#         for perm in permutations:
#             comparison_folder = filename.split('_')[3].replace('successful_', '') if 'successful' in filename else filename.split('_')[3].replace('failed_', '')
#             file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

# if SPLITHALF == 1:
#     generate_conc_file(successful_permutations['Half1'], f"sub-{SUB}_ses-{SES}_successful_half1")
#     generate_conc_file(successful_permutations['Half2'], f"sub-{SUB}_ses-{SES}_successful_half2")
#     generate_conc_file(failed_either_half, f"sub-{SUB}_ses-{SES}_failed_either_half")

# if SPLITPCT == 1:
#     generate_conc_file(successful_permutations[f"Percent_holdout-{percent_holdout}"], f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}")
#     generate_conc_file(failed_permutations[f"Percent_holdout-{percent_holdout}"], f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}")

# print("Conc files generated for all successful and failed permutations checks.")
# import os
# import sys

# print(f"Received arguments: {sys.argv}")
# print(f"Number of arguments received: {len(sys.argv)}")

# # Check if the correct number of arguments are provided
# if len(sys.argv) != 10:
#     print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
#     sys.exit(1)

# # Parse the command-line arguments
# BASEDIR, SUB, SES, TASK, NUM, SURF_ONLY, SPLITHALF, SPLITPCT, percent_holdout = sys.argv[1:]
# NUM = int(NUM)
# SURF_ONLY = int(SURF_ONLY)
# SPLITHALF = int(SPLITHALF)
# SPLITPCT = int(SPLITPCT)
# percent_holdout = int(percent_holdout)

# # Configure template and labels based on SURF_ONLY value
# templates = {
#     0: ('abcd', 'subcort_included'),
#     1: ('abcd', 'surfonly'),
#     2: ('abcd-SCAN', 'SCAN_network')
# }
# TEMPLATE, SURF_ONLY_LABEL = templates.get(SURF_ONLY, ('abcd', 'SCAN_network'))

# # Initialize dictionaries to store the status of permutations
# successful_permutations = {'Half1': [], 'Half2': [], f'Percent_holdout-{percent_holdout}': []}
# failed_permutations = {'Half1': [], 'Half2': [], f'Percent_holdout-{percent_holdout}': []}

# def check_permutations(comparison_folder):
#     local_successful = []
#     local_failed = []
#     for perm in range(1, NUM + 1):
#         file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#         if os.path.exists(file_path):
#             local_successful.append(perm)
#         else:
#             local_failed.append(perm)
#     successful_permutations[comparison_folder].extend(local_successful)
#     failed_permutations[comparison_folder].extend(local_failed)
#     if local_successful:
#         print(f"Successful {comparison_folder} Permutations: {local_successful}")
#     if local_failed:
#         print(f"Failed {comparison_folder} Permutations: {local_failed}")

# # Checking Split Half
# if SPLITHALF == 1:
#     check_permutations('Half1')
#     check_permutations('Half2')

# # Checking Percent Holdout
# if SPLITPCT == 1:
#     check_permutations(f"Percent_holdout-{percent_holdout}")

# # Generate .conc files
# def generate_conc_file(permutations, filename):
#     path = os.path.join(BASEDIR, f"{filename}.conc")
#     with open(path, 'w') as file:
#         for perm in permutations:
#             file.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{filename.split('_')[2]}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

# if SPLITHALF == 1:
#     generate_conc_file(successful_permutations['Half1'], f"sub-{SUB}_ses-{SES}_successful_half1")
#     generate_conc_file(successful_permutations['Half2'], f"sub-{SUB}_ses-{SES}_successful_half2")
#     generate_conc_file(failed_permutations['Half1'], f"sub-{SUB}_ses-{SES}_failed_half1")
#     generate_conc_file(failed_permutations['Half2'], f"sub-{SUB}_ses-{SES}_failed_half2")

# if SPLITPCT == 1:
#     generate_conc_file(successful_permutations[f"Percent_holdout-{percent_holdout}"], f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}")
#     generate_conc_file(failed_permutations[f"Percent_holdout-{percent_holdout}"], f"sub-{SUB}_ses-{SES}_failed_percent_holdout-{percent_holdout}")

# print("Conc files generated for all successful and failed permutations checks.")


# import os
# import sys

# print(f"Received arguments: {sys.argv}")
# print(f"Number of arguments received: {len(sys.argv)}")

# # Check if the correct number of arguments are provided
# expected_args = 10  # Including the script name itself
# if len(sys.argv) != expected_args:
#     print(f"Usage: python {sys.argv[0]} BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
#     sys.exit(1)

# # # Check if the correct number of arguments are provided
# # if len(sys.argv) != 9:
# #     print("Usage: python Check_successful_perms.py BASEDIR SUB SES TASK NUM SURF_ONLY SPLITHALF SPLITPCT percent_holdout")
# #     sys.exit(1)

# # Parse the command-line arguments
# BASEDIR = sys.argv[1]
# SUB = sys.argv[2]
# SES = sys.argv[3]
# TASK = sys.argv[4]
# NUM = int(sys.argv[5])
# SURF_ONLY = int(sys.argv[6])
# SPLITHALF = int(sys.argv[7])
# SPLITPCT = int(sys.argv[8])
# percent_holdout = sys.argv[9]


# # Configure template and labels based on SURF_ONLY value
# if SURF_ONLY == 0:
#     SURF_ONLY_LABEL = 'subcort_included'
#     TEMPLATE = 'abcd'
# elif SURF_ONLY == 1:
#     SURF_ONLY_LABEL = 'surfonly'
#     TEMPLATE = 'abcd'
# elif SURF_ONLY == 2:
#     SURF_ONLY_LABEL = 'SCAN_network'
#     TEMPLATE = 'abcd-SCAN'

# # Initialize lists to store the status of permutations
# successful_permutations = []
# failed_permutations = []

# def check_permutations(comparison_folder):
#     for perm in range(1, NUM + 1):
#         file_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparison_folder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
        
#         if os.path.exists(file_path):
#             successful_permutations.append(perm)
#         else:
#             failed_permutations.append(perm)

# # Checking Split Half
# if SPLITHALF == 1:
#     check_permutations('Half1')
#     check_permutations('Half2')
# else:
#     print("Not checking if Split Half Permutations were run successfully since the SPLITHALF flag was set to 0. If you want to check the Split Half Permutations change SPLITHALF=1")

# # Checking Percent Holdout
# if SPLITPCT == 1:
#     check_permutations(f"Percent_holdout-{percent_holdout}")
# else:
#     print(f"Not checking if Percent Holdout Permutations were run successfully since the SPLITPCT flag was set to 0. If you want to check the Percent Holdout Permutations change SPLITPCT=1")

# # Print summary
# print("Successful Permutations:", successful_permutations)
# print("Failed Permutations:", failed_permutations)

# # Generate .conc files
# if SPLITHALF == 1:
#     half1_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half1.conc")
#     half2_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half2.conc")
#     with open(half1_conc_path, 'w') as half1_conc, open(half2_conc_path, 'w') as half2_conc:
#         for perm in successful_permutations:
#             half1_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")
#             half2_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

# if SPLITPCT == 1:
#     holdout_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}.conc")
#     with open(holdout_conc_path, 'w') as holdout_conc:
#         for perm in successful_permutations:
#             holdout_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Percent_holdout-{percent_holdout}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

# failed_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_failed_permutations.conc")
# with open(failed_conc_path, 'w') as failed_conc:
#     for perm in failed_permutations:
#         failed_conc.write(f"{perm}\n")

# print("Conc files generated for successful permutations and failed permutations.")














# BASEDIR=/panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/task_scans_run-1_to_run-96/sub-01/ses-combined/
# SUB=01
# SES=combined 
# TASK=nsdcore
# NUM=100

# BASEDIR=/panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/task_scans_run-1_to_run-96/sub-01/ses-combined/
# SUB=01
# SES=combined 
# TASK=nsdcore
# NUM=100

# BASEDIR=/panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/
# SUB=01
# SES=combined 
# TASK=rest
# NUM=100


# comparisonfolder=Half1
# comparison_path= f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparisonfolder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"

# ${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK}/${perm}/${comparisonfolder}/${TEMPLATE}_template/${SURF_ONLY_LABEL}

# SPLITHALF=${16}
# SPLITPCT=${17}
# half1_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}
# half2_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}


# _bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#     half2_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
# ${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK}/${perm}/${comparisonfolder}/ *_recolored.dscalar.nii

# /panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/sub-01/ses-combined/rest/16/Half1/abcd-SCAN_template/SCAN_network/sub-01_ses-combined_task-rest_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii

# /panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/task_scans_run-1_to_run-96/sub-01/ses-combined/sub-01/ses-combined/nsdcore/16/Percent_holdout-80/abcd-SCAN_template/SCAN_network/sub-01_ses-combined_task-nsdcore_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii
# if [ ${SURF_ONLY} == 0 ]; then
#   TEMPLATE_PATH='/projects/standard/faird/shared/code/internal/analytics/compare_matrices_copy_to_merge_from/support_files/seedmaps_ABCD164template_SMOOTHED_dtseries_all_networksZscored.mat'
#   SURF_ONLY_LABEL='subcort_included'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 1 ]; then
#   TEMPLATE_PATH='/projects/standard/faird/shared/code/internal/analytics/compare_matrices_copy_to_merge_from/support_files/ABCD_surface_template/seedmaps_ABCD_surface_dtseries_all_networksZscored.mat'
#   SURF_ONLY_LABEL='surfonly'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 2 ]; then
#   TEMPLATE_PATH='/projects/standard/rando149/shared/projects/ABCD_template_maker/seedmaps_from_template2.0/ABCD_scan_seedmap/seedmaps_subs_withsmoothed_dtseries_n141_all_networksZscored.mat'
#   SURF_ONLY_LABEL='SCAN_network'
#   TEMPLATE=abcd-SCAN
# fi

# if [ ${SURF_ONLY} == 0 ]; then
#   SURF_ONLY_LABEL='subcort_included'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 1 ]; then
#   SURF_ONLY_LABEL='surfonly'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 2 ]; then
#   SURF_ONLY_LABEL='SCAN_network'
#   TEMPLATE=abcd-SCAN
# fi

# dscalarin=${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK}/${perm}/${comparisonfolder}/${TEMPLATE}_template/${SURF_ONLY_LABEL}


# Can you help me modify a code to include more input flags which define more options of the code? 

# The original code checks comparisonfolders Half1 and Half2 and makes sure the dscalar.nii is there for both comparisons. It does this by defining the comparisonfolders as half1 and half2

#     half1_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#     half2_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"

# However, for the new code, I want 3 additional inputs 1) SURF_ONLY = int(sys.argv[6]) 2) SPLITHALF = int(sys.argv[7]) and 3) SPLITPCT = int(sys.argv[8]) 

# 1) one input that is SURF_ONLY = int(sys.argv[6]) which can either be 0 1 or 2 at the moment.
# This option will make sure that the parts of the path above abcd-SCAN_template/SCAN_network are not hard coded. So it would do a conditional statement based on the SURF_ONLY input and use that to fill in the path. 

# in another bash code I define these using this statement which obviously wouldnt work in the python code, but an example of what I was doing. 

# if [ ${SURF_ONLY} == 0 ]; then
#   SURF_ONLY_LABEL='subcort_included'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 1 ]; then
#   SURF_ONLY_LABEL='surfonly'
#   TEMPLATE=abcd
# elif [ ${SURF_ONLY} == 2 ]; then
#   SURF_ONLY_LABEL='SCAN_network'
#   TEMPLATE=abcd-SCAN
# fi

# It would then use this to replace the hard code to something like this comparisonfolder=Half1
# half1_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/{comparisonfolder}/{TEMPLATE}_template/{SURF_ONLY_LABEL}/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"

# 2) Then the second flag I want to add is SPLITHALF = int(sys.argv[7]) which would be either a 1 or a 0. If it is a 1 you run the original code to check if the dscalars are in the half1 and half2. However, if it is zero or something other than 1 it skipps this code and gives the user a message "Not checking if Split Half Permutations were run sucessfully since the SPLITHALF flag was set to 0 if you want to check the Split Half Permutations change SPLITHALF=1"

# 3) Then for the third flag SPLITPCT = int(sys.argv[8]) the inputs will be similar to SPLITHALF with 1 indicating to run the new code and 0 to skip it with the message "Not checking if Percent Holdout Permutations were run sucessfully since the SPLITPCT flag was set to 0 if you want to check the Percent Holdout Permutations change SPLITPCT=1" Then the new code I want it to run is similar to the SPLITHALF option, but instead of searching in the two comparison folders half1 and half2 it searches in  the comparison Percent_holdout-{percent_holdout} instead of half1 or half2. I am now realizing we need a fourth input percent_holdout = int(sys.argv[9]) this is an input given as a number most likely between 0 and 100 in this example it is 80 i.e. instead of half1 or half2 in the path it would be Percent_holdout-80 
# And then instead of checking if all the permutations exist in the both halves it checks if all of the permutations exist in this new comparisonfolder which is Percent_holdout-{percent_holdout} folder with the same strucure as above, with the only thing that differs being the {comparisonfolder}. 
# and the outputs would no longer be called 
# half1_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half1.conc")
# half2_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half2.conc")
# failed_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_failed_either_half.conc")
# but instead something like
# holdout_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_percent_holdout-{percent_holdout}.conc")
# failed_percent_holdout_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_failed_percent_holdout_permutations.conc")
# Does that make sense? Here is the original code I want to modify


# import os
# import sys

# # Check if the correct number of arguments are provided
# if len(sys.argv) != 6:
#     print("Usage: python Check_successful_perms.py BASEDIR SUB SES TASK NUM")
#     sys.exit(1)

# # Parse the command-line arguments
# BASEDIR = sys.argv[1]
# SUB = sys.argv[2]
# SES = sys.argv[3]
# TASK = sys.argv[4]
# NUM = int(sys.argv[5])

# # Initialize lists to store the status of permutations
# successful_permutations = []
# failed_permutations = []

# # Iterate over the permutations
# for perm in range(1, NUM + 1):
#     half1_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"
#     half2_path = f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii"

#     half1_exists = os.path.exists(half1_path)
#     half2_exists = os.path.exists(half2_path)

#     if half1_exists and half2_exists:
#         successful_permutations.append(perm)
#     else:
#         failed_permutations.append(perm)

# # Print summary
# print("Successful Permutations:", successful_permutations)
# print("Failed Permutations in Either Half:", failed_permutations)

# # Generate .conc files for successful and failed permutations with sub and ses in the filename
# half1_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half1.conc")
# half2_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_successful_half2.conc")
# failed_conc_path = os.path.join(BASEDIR, f"sub-{SUB}_ses-{SES}_failed_either_half.conc")

# with open(half1_conc_path, 'w') as half1_conc, open(half2_conc_path, 'w') as half2_conc, open(failed_conc_path, 'w') as failed_conc:
#     for perm in successful_permutations:
#         half1_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half1/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")
#         half2_conc.write(f"{BASEDIR}/sub-{SUB}/ses-{SES}/{TASK}/{perm}/Half2/abcd-SCAN_template/SCAN_network/sub-{SUB}_ses-{SES}_task-{TASK}_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii\n")

#     for perm in failed_permutations:
#         failed_conc.write(f"{perm}\n")

# print("Conc files generated for successful permutations and failed permutations in either half.")
