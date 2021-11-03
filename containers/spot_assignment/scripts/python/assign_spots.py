import os
import sys
import numpy as np
import pandas as pd
from glob import glob
from skimage.io import imread
from os.path import abspath, dirname

if __name__ == '__main__':
    lb_dir = sys.argv[1]
    spot_dir = sys.argv[2]
    out_dir = sys.argv[3]

    print("Reading", lb_dir)
    lb = imread(lb_dir)
    fx = sorted(glob(spot_dir+"/air_localize_points_c*.txt"))

    lb_id = np.unique(lb[lb != 0])
    z, y, x = lb.shape
    
    # TODO: get voxel size of segmentation image from original pixelResolution * s2 downsamplingFactors
    s=[0.92,0.92,0.84]

    count = pd.DataFrame(np.empty([len(lb_id), 0]), index=lb_id)

    for f in fx:

        print("Reading", f)
        r = os.path.basename(f).split('/')[-1]
        r = r.split('.')[0]
        spot = np.loadtxt(f, delimiter=',')
        n = len(spot)
        
        # Convert from micrometer space to the voxel space of the segmented image
        rounded_spot = np.round(spot[:, :3]/s).astype('int')
        df = pd.DataFrame(np.zeros([len(lb_id), 1]), index=lb_id, columns=['count'])

        for i in range(0, n):
            if np.any(np.isnan(spot[i,:3])):
                print('NaN found in {} line# {}'.format(f, i+1))
            else:
                if np.any(spot[i,:3]<0):
                    print('Point outside of fixed image found in {} line# {}'.format(f, i+1))
                else:
                    try:
                        # if all non-rounded coord are valid values (none is NaN)
                        Coord = np.minimum(rounded_spot[i], [x, y, z])
                        idx = lb[Coord[2]-1, Coord[1]-1, Coord[0]-1]
                        if idx > 0 and idx <= len(lb_id):
                            # increment counter
                            df.loc[idx, 'count'] = df.loc[idx, 'count']+1
                    except Exception as e:
                        print('Unexpected error in {} line# {}: {}'.format(f, i+1, e))

        count.loc[:, r] = df.to_numpy()

    out_file = out_dir + '/count.csv'
    print("Writing", out_file)
    count.to_csv(out_file)
