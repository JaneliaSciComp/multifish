
import sys
import numpy as np
import n5_metadata_utils as n5mu

#
# Read in the RS-FISH output (in voxel space) and output the points in microns
#
if __name__ == '__main__':

    input_voxels        = sys.argv[1] 
    output_microns      = sys.argv[2]
    n5_path             = sys.argv[3]
    extraction_subpath  = sys.argv[4]

    n5     = n5mu.open_n5(n5_path)
    vox    = n5mu.read_n5_voxel_spacing(n5, extraction_subpath)
    grid   = n5mu.read_n5_voxel_grid(n5, extraction_subpath)

    rsfish_spots = np.loadtxt(input_voxels, delimiter=',', skiprows=1)
    rsfish_spots[:, :3] = rsfish_spots[:, :3] * vox

    # Remove unnecessary columns (t,c) at indexes 3 and 4 
    rsfish_spots = np.delete(rsfish_spots, np.s_[3:5], axis=1)

    print(f"Saving {rsfish_spots.shape[0]} points in micron space to", output_microns)
    np.savetxt(output_microns, rsfish_spots, delimiter=',')
