import sys
import numpy as np
import n5_metadata_utils as n5mu
from glob import glob
from os.path import split


def read_coords(path):
    with open(path, 'r') as f:
        offset = np.array(f.readline().split(' ')).astype(np.float64)
        extent = np.array(f.readline().split(' ')).astype(np.float64)
        index  = np.array(f.readline().split(' ')).astype(np.uint16)
    return offset, extent, index




if __name__ == '__main__':

    tiledir       = sys.argv[1]
    suffix        = sys.argv[2]
    output        = sys.argv[3]
    xy_overlap    = int(sys.argv[4])
    z_overlap     = int(sys.argv[5])
    reference     = sys.argv[6]
    subpath       = sys.argv[7]

    all_points = [-1, -1, -1, 0]
    points_files = sorted(glob(tiledir + '/*/air_localize_points' + suffix))
    for point_file in points_files:

        vox    = n5mu.read_voxel_spacing(reference, subpath)
        grid   = n5mu.read_voxel_grid(reference, subpath) * vox
        points = np.loadtxt(point_file)
        if points.shape[0] == 0: points = np.array([[-1, -1, -1, 0, 0]])  # file has 0 points
        if len(points.shape) == 1: points = points[np.newaxis, :]         # file has 1 point
        points = points[:, :-1]  # last column from air localize is all zeros
        tile   = split(point_file)[0]
        offset, extent, index = read_coords(tile + '/coords.txt')

        margins = np.array([xy_overlap, xy_overlap, z_overlap]) * vox * 0.5
        lbs = np.array([offset[i]+margins[i] if index[i] != 0 else offset[i] for i in range(3)])
        ends = offset + extent
        ubs = np.array([ends[i]-margins[i] if ends[i] < grid[i] else ends[i] for i in range(3)])

        out_of_bounds = np.logical_or(points[:, :3] < lbs, points[:, :3] >= ubs)
        points[:, :3][out_of_bounds] = -1

        all_points = np.vstack((all_points, points))
        all_points = all_points[ (all_points != -1).all(axis=1), : ]
        all_points = all_points[ (all_points != -8).all(axis=1), : ]
    np.savetxt(output, all_points, delimiter=',')

