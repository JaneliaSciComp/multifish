### apply flatfield correction to s0 image

import os
import numpy as np
from scipy.ndimage import zoom
import zarr

from matplotlib import pyplot as plt
import seaborn as sns
import tifffile

import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')

def transform(images, f, d=None):
    if d is not None:
        images_transformed = (np.clip(images-d[np.newaxis],0,None))/f[np.newaxis]
    else:
        images_transformed = images/f[np.newaxis]
        
    return images_transformed

def transform_pipe(images_raw, dx, ff, upscale=8):
    """
    """
    ff_s = zoom(ff, upscale).astype(np.float16)
    dx_s = zoom(dx, upscale).astype(np.float16)
    images_s_transformed = transform(images_raw.astype(np.float16), ff_s, d=dx_s).astype(np.uint16)
    return images_s_transformed

### inputs
f_dx = '/u/home/f/f7xiesnm/project-zipursky/easifish/results/flatfield/darkfield.tiff' 
f_ff = '/u/home/f/f7xiesnm/project-zipursky/easifish/results/flatfield/flatfield.tiff' 

path    = "/u/home/f/f7xiesnm/project-zipursky/data/00_tiled/lt185_r2.n5"
outpath = "/u/home/f/f7xiesnm/project-zipursky/data/02_flat/lt185_r2_autos1_flat.n5"

scale   = 's1' #'s0'
upscale = 8    # 16 - linear
# scale   = 's3' #'s0'
# upscale = 2    # 16 - linear


# selected setups to create
# i_s = np.array([0,1,2,3]) # np.arange(0, 20, 1) # c0
# i_s = np.hstack([
#     np.arange( 0, 20,1),
#     np.arange(20, 40,1),
#     np.arange(40, 60,1),
#     np.arange(80,100,1),
# ])

# i_s = np.arange(0,100,1)
i_s = np.arange(47,100,1)
logging.info(f'Selected setups: {i_s}')

### end of inputs

# load two images
dx = tifffile.imread(f_dx).astype(np.float32)
ff = tifffile.imread(f_ff).astype(np.float32)

# load data handles
zarr_data = zarr.open(store=zarr.N5Store(path), mode='r')

if os.path.isdir(outpath):
    mode = 'r+'
else: 
    mode = 'w'
n5_root   = zarr.open(store=zarr.N5Store(outpath), mode=mode)

# add a setup level structure - same as previous
setups = list(zarr_data.keys())
for setup in setups: 
    # add setup level attributes to conform to bdv.n5 format -- needed for fusion
    setup_handle  = n5_root.require_group(f'{setup}')
    setup_attrs = setup_handle.attrs.asdict()
    setup_attrs['downsamplingFactors'] = [[1,1,1]] # BigStitcher-Spark only uses [1,1,1]
    setup_attrs['dataType'] = 'uint16'
    setup_handle.attrs.update(setup_attrs)

# for slot in slots: # this can be parallelized
for setup_idx in i_s: 
    slot = f'/setup{setup_idx}/timepoint0/{scale}'
    logging.info(slot)

    # get image handle
    images_s0_handle  = zarr_data[slot]
    attributes = images_s0_handle.attrs.asdict()
    # attributes['pixelResolution'] = [0.23, 0.23, 0.42] # useful later

    # get
    logging.info('retrieving the image...')
    images_s0_raw = images_s0_handle[...]

    # transform
    logging.info('transforming the image...')
    a = transform_pipe(images_s0_raw, dx, ff, upscale=upscale)

    # save
    logging.info('saving the image...')
    dataset = n5_root.require_dataset(
        slot,
        data=a,
        shape=a.shape,
        chunks=images_s0_handle.chunks, # (64, 128, 128),
        dtype=images_s0_handle.dtype,
        compressor=images_s0_handle.compressor,  # GZip(level=1),
        )
    dataset.attrs.update(**attributes)