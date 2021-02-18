#!/usr/bin/env python
# coding: utf-8

import os
import sys
import zarr
import numpy as np
import pandas as pd
from glob import glob
from skimage.measure import regionprops
from skimage.io import imread, imsave
from os.path import abspath, dirname

if __name__ == "__main__":
    label_path = sys.argv[1]
    puncta_path = sys.argv[2]
    outdir = sys.argv[3]
    r = sys.argv[4]
    channel = sys.argv[5]
    scale = sys.argv[6]
    if len(sys.argv) > 7:
        dapi_channel = sys.argv[7]
    else:
        dapi_channel = 'c2'
    if len(sys.argv) > 8:
        bleed_channel = sys.argv[8]
    else:
        bleed_channel = 'c3'

lb = imread(label_path)
roi = np.unique(lb)

# get n5 image data
ch_scale_path = '{}/{}'.format(channel, scale)
print('Image path:', puncta_path, ch_scale_path)
im = zarr.open(store=zarr.N5Store(puncta_path), mode='r')
img = im[ch_scale_path][...]

if channel == bleed_channel:
    dapi_ch_scale_path = '{}/{}'.format(dapi_channel, scale) # c2/s2
    dapi = im[dapi_ch_scale_path][...]
    lo = np.percentile(np.ndarray.flatten(dapi), 99.5)
    bg_dapi = np.percentile(np.ndarray.flatten(dapi[dapi != 0]), 1)
    bg_img = np.percentile(np.ndarray.flatten(img[img != 0]), 1)
    dapi_factor = np.median(
        (img[dapi > lo] - bg_img)/(dapi[dapi > lo] - bg_dapi))
    img = np.maximum(0, img - bg_img - dapi_factor *
                     (dapi - bg_dapi)).astype('float32')
    print('bleed_through:', dapi_factor)
    print('DAPI background:', bg_dapi)
    print('bleed_through channel background:', bg_img)

df = pd.DataFrame(data=np.empty([len(roi)-1, 4]),
                  columns=['roi', 'weighted_centroid', 'weighted_local_centroid', 'mean_intensity'],
                  dtype=object)
lb_stat = regionprops(lb, intensity_image=img)
for i in range(0, len(roi)-1):
    df.loc[i, 'roi'] = lb_stat[i].label
    df.loc[i, 'mean_intensity'] = lb_stat[i].mean_intensity

df.to_csv(outdir+'/{}_{}_intensity.csv'.format(r, channel), index=False)
