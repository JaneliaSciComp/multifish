
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

lb = imread(lb_dir)
fx = sorted(glob(spot_dir+"/*.txt"))

lb_id = np.unique(lb[lb != 0])
z, y, x = lb.shape
s=[0.92,0.92,0.84] ## voxel size in segmentation image
count = pd.DataFrame(np.empty([len(lb_id), 0]), index=lb_id)

for f in fx:
    print("Load:", f)
    r = os.path.basename(f).split('/')[-1]
    r = r.split('.')[0]
    spot = np.loadtxt(f, delimiter=',')
    n = len(spot)
    rounded_spot = np.round(spot[:, :3]/s).astype('int')
    df = pd.DataFrame(np.zeros([len(lb_id), 1]),
                      index=lb_id, columns=['count'])

    for i in range(0, n):
        if np.any(np.isnan(spot[i,:3])):
            print('NaN found in {} line# {}'.format(f, i+1))
        else:
            # if all non-rounded coord are valid values (none is NaN)
            Coord = np.minimum(rounded_spot[i], [x, y, z])
            idx = lb[Coord[2]-1, Coord[1]-1, Coord[0]-1]
            if idx > 0 and idx <= len(lb_id):
                df.loc[idx, 'count'] = df.loc[idx, 'count']+1
    count.loc[:, r] = df.to_numpy()
count.to_csv(out_dir+'/count.csv')
