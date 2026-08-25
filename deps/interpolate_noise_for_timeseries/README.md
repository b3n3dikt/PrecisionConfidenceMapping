INTERPOLATE_NOISE_FOR_SUBCORTICALS - This function works by finding
voxels/grayordiantes in thetimseries that are equal to 0 (exactly) and
injects noise into each frame based on the mean and standard deviation of
the grayordinates in the same structure.

R. Hermosillo 10/13/2022
Inputs are: 
-dtseries file = full path to the dtseriesfile (ends in dtseries.nii)
-wb_command = full path to workbench command.
-run_locally = Set to 1 if your running this on Robert's Desktop computer. Set to 0
if you're running this on MSI. (This will automatically load the necessary cifti dependencies.)

Some dependencies used by this software:
Gifti 1.6
Matlab-cifti
ft_read_cifti_mod - a utility that can be downloaded from the Midnight Scan Club database.