import json
import numpy as np
import zarr


def _correct_subpath(subpath):
    return '' if subpath[-2:] == 's0' else subpath


def _get_atts(n5_path, subpath, correct_subpath=True):
    if correct_subpath: atts_path = n5_path + _correct_subpath(subpath)
    else: atts_path = n5_path + subpath
    atts_path += '/attributes.json'
    with open(atts_path, 'r') as atts:
        return json.load(atts)


def read_voxel_spacing(n5_path, subpath):
    atts = _get_atts(n5_path, subpath)
    if subpath[-2:] == 's0':
        print("Reading vox as 'pixelResolution.dimensions' from %s/%s" % (n5_path, subpath))
        vox = np.absolute(atts['pixelResolution']['dimensions'])
    else:
        print("Reading vox as 'pixelResolution'*'downsamplingFactors' from %s/%s" % (n5_path, subpath))
        vox = np.absolute(np.array(atts['pixelResolution']) * np.array(atts['downsamplingFactors']))
    print("Got vox", vox)
    return vox.astype(np.float32)


def read_voxel_grid(n5_path, subpath):
    atts = _get_atts(n5_path, subpath, correct_subpath=False)
    print("Reading voxel grid as 'dimensions' from %s/%s" % (n5_path, subpath))
    return np.array(atts['dimensions']).astype(np.uint16)


def transfer_metadata(ref_path, ref_subpath, out_path, out_subpath):
    if ref_subpath[-2:] != out_subpath[-2:]:
        print('can only transfer metadata between equivalent scale levels')
        print('nothing copied')
    else:
        ref_atts = _get_atts(ref_path, ref_subpath, correct_subpath=False)
        out_atts = _get_atts(out_path, out_subpath, correct_subpath=False)
        for k in ref_atts.keys():
            if k not in out_atts.keys():
                out_atts[k] = ref_atts[k]
        with open(out_path + out_subpath + '/attributes.json', 'w') as atts:
            json.dump(out_atts, atts)

# Improved versions of above functions, using the Zarr API. 
# TODO: modify the rest of the code to use these instead

def open_n5(n5_path):
    print(f"Opening N5 from {n5_path}")
    return zarr.open(store=zarr.N5Store(n5_path), mode='r')


def read_n5_voxel_spacing(n5, subpath):
    if subpath[-2:] == 's0':
        print(f"Reading vox as 'pixelResolution.dimensions' from {subpath}")
        vox = np.array(n5.attrs['pixelResolution']['dimensions'])
    else:
        print(f"Reading vox as 'pixelResolution'*'downsamplingFactors' from {subpath}")
        attrs = n5[subpath].attrs
        vox = np.array(attrs['pixelResolution']) * np.array(attrs['downsamplingFactors'])
    print("Got vox", vox)
    return vox.astype(np.float32)


def read_n5_voxel_grid(n5, subpath):
    print(f"Reading voxel grid as array shape from {subpath}")
    # We must flip here because Zarr reads N5 metadata in reverse
    return np.flip(n5[subpath].shape).astype(np.uint16)
