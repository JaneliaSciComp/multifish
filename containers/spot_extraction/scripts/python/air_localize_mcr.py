
import zarr
import numpy as np
import sys
import json
import AIRLOCALIZE_N5
import matlab
import n5_metadata_utils as n5mu
from _internal.mlarray_utils import _get_strides, _get_mlsize


# BEGIN:
# copied from SO:
# https://stackoverflow.com/questions/10997254/converting-numpy-arrays-to-matlab-and-vice-versa
def _wrapper__init__(self, arr):
    assert arr.dtype == type(self)._numpy_type
    self._python_type = type(arr.dtype.type().item())
    self._is_complex = np.issubdtype(arr.dtype, np.complexfloating)
    self._size = _get_mlsize(arr.shape)
    self._strides = _get_strides(self._size)[:-1]
    self._start = 0

    if self._is_complex:
        self._real = arr.real.ravel(order='F')
        self._imag = arr.imag.ravel(order='F')
    else:
        self._data = arr.ravel(order='F')

_wrappers = {}
def _define_wrapper(matlab_type, numpy_type):
    t = type(matlab_type.__name__, (matlab_type,), dict(
        __init__=_wrapper__init__,
        _numpy_type=numpy_type
    ))
    # this tricks matlab into accepting our new type
    t.__module__ = matlab_type.__module__
    _wrappers[numpy_type] = t

_define_wrapper(matlab.double, np.double)
_define_wrapper(matlab.single, np.single)
_define_wrapper(matlab.uint8, np.uint8)
_define_wrapper(matlab.int8, np.int8)
_define_wrapper(matlab.uint16, np.uint16)
_define_wrapper(matlab.int16, np.int16)
_define_wrapper(matlab.uint32, np.uint32)
_define_wrapper(matlab.int32, np.int32)
_define_wrapper(matlab.uint64, np.uint64)
_define_wrapper(matlab.int64, np.int64)
_define_wrapper(matlab.logical, np.bool_)

def as_matlab(arr):
    try:
        cls = _wrappers[arr.dtype.type]
    except KeyError:
        raise TypeError("Unsupported data type")
    return cls(arr)
# END: SO copy


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
    print('N5 Path:',image_path)
    print('N5 Data Set:',subpath)
    print('Shape:',image.shape)
    print('Voxel Size:',vox)

    data  = image[offset_vox[2]:ends[2], offset_vox[1]:ends[1], offset_vox[0]:ends[0]]
    print('Non-zero voxel count:',np.count_nonzero(data))

    data  = np.moveaxis(data, (0, 2), (2, 0))

    if dapi_subpath:
        dapi_image = n5[dapi_subpath]
        dapi  = dapi_image[offset_vox[2]:ends[2], offset_vox[1]:ends[1], offset_vox[0]:ends[0]]
        dapi  = np.moveaxis(dapi, (0, 2), (2, 0))
        lo=np.percentile(np.ndarray.flatten(dapi),99.5)
        bg_dapi=np.percentile(np.ndarray.flatten(dapi[dapi!=0]),1)
        bg_data=np.percentile(np.ndarray.flatten(data[data!=0]),1)
        dapi_factor=np.median((data[dapi>lo] - bg_data)/(dapi[dapi>lo] - bg_dapi))
        data  = np.maximum(0, data - bg_data - dapi_factor * (dapi - bg_dapi)).astype('float32')
        print('Bleedthrough:',dapi_factor)
        print('DAPI background:',bg_dapi)
        print('c3 background:',bg_data)

    print('Initializing MATLAB runtime...')
    # use compiled matlab AIRLOCALIZE, no need for matlab license
    AIRLOCALIZE_N5.initialize_runtime(['-nojvm', '-nodisplay'])
    AIRLOCALIZE=AIRLOCALIZE_N5.initialize()
    matlab_data = as_matlab(data)
    print('Calling AIRLOCALIZE_N5')
    
    points = AIRLOCALIZE.AIRLOCALIZE_N5(params, matlab_data, output, nargout=1)
    points = np.array(points._data).reshape(points.size, order='F')
    # TODO: write default spot file for tiles that return 0 spots

    num_points = points.shape[0]

    # Write out points in micrometer cooordinate space
    points_um = np.copy(points)
    points_um[:, :3] = points_um[:, :3] * vox + offset
    filename = f"{output}/air_localize_points{suffix}"
    print("Saving {num_points} points to", filename)
    np.savetxt(filename, points)
