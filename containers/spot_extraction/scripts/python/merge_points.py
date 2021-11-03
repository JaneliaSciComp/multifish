import os
import sys
import numpy as np
import n5_metadata_utils as n5mu
from glob import glob
from os.path import split
import pathlib

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
    n5_path       = sys.argv[6]
    subpath       = sys.argv[7]

    n5 = n5mu.open_n5(n5_path)
    vox    = n5mu.read_n5_voxel_spacing(n5, subpath)
    grid   = n5mu.read_n5_voxel_grid(n5, subpath) * vox

    all_points = [-1, -1, -1, 0]
    points_files = sorted(glob(tiledir + '/*/air_localize_points' + suffix))
    for point_file in points_files:

        print("Reading", point_file)
        points = np.loadtxt(point_file)
        num_points = points.shape[0]
        print(f"Got {num_points} points")

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

    filepath = f"{output}{suffix}"
    print("Saving ", filepath)
    np.savetxt(filepath, all_points, delimiter=',')
 
    d = pathlib.Path(f"{output}_voxels")
    print("Creating scaled output dir", d)
    d.mkdir(parents=True, exist_ok=True)

    group = os.path.split(subpath.strip('/'))[0]
    for scale in n5[group]:
        print("Transforming points to scale", scale)

        # Convert from micrometer space to the voxel space of current scale
        scale_vox = n5mu.read_n5_voxel_spacing(n5, group+'/'+scale)
        scaled = all_points[:, :3]/scale_vox
        ones = np.ones(all_points.shape[0])
        points_vox = np.c_[ scaled, ones, ones, all_points[:, -1:] ]

        # Write out points in voxel space
        filepath = str(pathlib.Path(d, f"{d.name}_{scale}{suffix}"))

        print("Saving", filepath)
        # Matches the RS-FISH output format, for easy loading into BigDataViewer with the RS-FISH plugin
        np.savetxt(filepath, points_vox, delimiter=',', \
            fmt=['%.4f','%.4f','%.4f','%d','%d','%.4f'], \
            header='x,y,z,t,c,intensity', comments="")

        # Currently we output just s0 scale voxel coordinates. Remove this break to output all scales s1, s2, etc..
        break
