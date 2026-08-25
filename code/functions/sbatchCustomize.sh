#!/bin/bash -l

#This script takes in the values you will need to personalize the sbatch scripts for Template Shuffle. 

#In order, provide the account and output log directory
#Example command: sbatchCustomize.sh miran045 /projects/standard/faird/shared/projects/ExampleProject/outputLogs/
#NOTE: This script must be located in the main directory of your copy the TemplateShuffle code for it to work. 

#Takes the directory this file is located in
TEMPLATE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ACCOUNT=$1 #The MSI account you want to use (faird, miran045, smnelson, ...)
LOG_DIR=$2 #The directory you want your log files to be outputted to

function alter_sbatch () { #First input is file, second is account, third is log
    sed -i "s|output_logs/|$3|" $1 #Changes output log directory
    sed -i -e "s|-A faird|-A $2|" $1  #Changes account from faird to account you use
    sed -i -e "s|-A smnelson|-A $2|" $1 #Changes account from smnelson to account you specify
}

alter_sbatch $TEMPLATE_DIR/code/main_run_script_template_matching_split_half.sh $ACCOUNT $LOG_DIR
alter_sbatch $TEMPLATE_DIR/code/functions/make_figs_and_dscalars.sh $ACCOUNT $LOG_DIR

sed -i "s|/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle|$TEMPLATE_DIR|" $TEMPLATE_DIR/code/wrappers/run_split_half_Template_Matching_wrapper.sh
sed -i "s|/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle|$TEMPLATE_DIR|" $TEMPLATE_DIR/code/wrappers/run_split_half_Template_Matching_wrapper.sh