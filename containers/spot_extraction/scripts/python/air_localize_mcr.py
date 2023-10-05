
import matlab
import numpy as np
import sys
import AIRLOCALIZE_N5
import n5_metadata_utils as n5mu


def as_matlab(arr):
    try:
        np2matlabDict = {
            'float64': matlab.double,
            'float32': matlab.single,
            'uint8': matlab.uint8,
            'int8': matlab.int8,
            'uint16': matlab.uint16,
            'int16': matlab.int16,
            'uint32': matlab.uint32,
            'int32': matlab.int32,
            'uint64': matlab.uint64,
            'int64': matlab.int64,
        }
        print('Convert ', arr.shape, arr.dtype, 'to matlab', flush=True)
        return np2matlabDict[str(arr.dtype)](arr)
    except KeyError:
        raise TypeError("Unsupported data type")


def read_coords(path):
    with open(path, 'r') as f:
        offset = np.array(f.readline().split(' ')).astype(np.float64)
        extent = np.array(f.readline().split(' ')).astype(np.float64)
    return offset, extent


if __name__ == '__main__':
    image_path       = sys.argv[1]
    subpath          = sys.argv[2]
    coords           = sys.argv[3]
    params           = sys.argv[4]
    output           = sys.argv[5]
    suffix           = sys.argv[6]

    dapi_subpath = None
    if len(sys.argv) > 7:
        dapi_subpath        = sys.argv[7]

    n5 = n5mu.open_n5(image_path)

    offset, extent = read_coords(coords)
    vox            = n5mu.read_n5_voxel_spacing(n5, subpath)
    offset_vox     = np.round(offset/vox).astype(np.uint16)
    extent_vox     = np.round(extent/vox).astype(np.uint16)
    ends           = offset_vox + extent_vox

    image = n5[subpath]
    print('N5 Path:', image_path, flush=True)
    print('N5 Data Set:', subpath, flush=True)
    print('Shape:', image.shape, flush=True)
    print('Voxel Size:', vox, flush=True)

    data  = image[offset_vox[2]:ends[2], offset_vox[1]:ends[1], offset_vox[0]:ends[0]]
    print('Non-zero voxel count:',np.count_nonzero(data), flush=True)

    data  = np.moveaxis(data, (0, 2), (2, 0))

    if dapi_subpath:
        dapi_image = n5[dapi_subpath]
        dapi  = dapi_image[offset_vox[2]:ends[2], offset_vox[1]:ends[1], offset_vox[0]:ends[0]]
        dapi  = np.moveaxis(dapi, (0, 2), (2, 0))
        lo=np.percentile(np.ndarray.flatten(dapi),99.5)
        bg_dapi=np.percentile(np.ndarray.flatten(dapi[dapi!=0]),1)
        bg_data=np.percentile(np.ndarray.flatten(data[data!=0]),1)
        dapi_factor=np.median((data[dapi>lo] - bg_data)/(dapi[dapi>lo] - bg_dapi))
        data = np.maximum(0, data - bg_data - dapi_factor * (dapi - bg_dapi)).astype('float32')
        print('Bleedthrough:',dapi_factor, flush=True)
        print('DAPI background:',bg_dapi, flush=True)
        print('c3 background:',bg_data, flush=True)

    print('Initializing MATLAB runtime...', flush=True)
    # use compiled matlab AIRLOCALIZE, no need for matlab license
    AIRLOCALIZE_N5.initialize_runtime(['-nojvm', '-nodisplay'])
    AIRLOCALIZE=AIRLOCALIZE_N5.initialize()
    matlab_data = as_matlab(data)
    print('Calling AIRLOCALIZE_N5 - data shape:', data.shape, data.dtype, flush=True)
    points = AIRLOCALIZE.AIRLOCALIZE_N5(params, matlab_data, output, nargout=1)
    points = np.array(points._data).reshape(points.size, order='F')
    print('Close MATLAB runtime...', flush=True)
    AIRLOCALIZE_N5.terminate_runtime()

    # TODO: write default spot file for tiles that return 0 spots
    num_points = points.shape[0]

    # Write out points in micrometer cooordinate space
    points_um = np.copy(points)
    points_um[:, :3] = points_um[:, :3] * vox + offset
    filename = f"{output}/air_localize_points{suffix}"
    print(f"Saving {num_points} points to", filename, flush=True)
    np.savetxt(filename, points_um)
