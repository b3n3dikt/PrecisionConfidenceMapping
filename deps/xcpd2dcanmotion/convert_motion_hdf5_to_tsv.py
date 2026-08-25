#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 23 19:27:37 2024

@author: kweldon


This code converts motion hdf5 to a tsv file (excluding the binary mask). 

usage:

python convert_motion_hdf5_to_tsv.py /abs/path/to/func/dir


"""

import os, glob, h5py, sys
import pandas as pd
#import argparse
#%%

if len(sys.argv) > 1:
    funcDir = sys.argv[1]

#strip trailing slash
if os.path.split(funcDir)[1] == '':
    funcDir = funcDir[:-1]

print('reading from...%s'%funcDir)
#gather the files 
input_list = []
input_list = glob.glob(os.path.join(funcDir, '*qc.hdf5'))
print(input_list)

#%%    
for file in input_list:
    print('converting... ', file)
    f = h5py.File(file,'r')
    group = f['dcan_motion']
    df = pd.DataFrame(group)
    for iF,fd in enumerate(group.keys()):
        #print(iF)
        #print(fd)
        for element in group[fd].keys():
            if element != 'binary_mask':
                #df[element] = group[fd][element][()]
                df.loc[iF,element] = group[fd][element][()]
                #print(df)
                #print(element, group[fd][element][()])
    
    df['remaining_min']=df['remaining_seconds']/60
    csvname = os.path.split(file)[-1].split('.')[0] + '.tsv'
    csvpath = os.path.join(funcDir,csvname)
    df.to_csv(csvpath, sep='\t', index=False)