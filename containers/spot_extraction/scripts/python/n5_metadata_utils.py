import json
import numpy as np


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

