"""Three plausible implementations to investigate and repair. No syntax puzzles."""
import hashlib
import json
import numpy as np

def make_request_spec(science, inputs, environment, runtime):
    def normalize(v):
        if isinstance(v, dict):
            return {str(k): normalize(val) for k, val in sorted(v.items())}
        elif isinstance(v, list):
            return [normalize(x) for x in v]
        elif isinstance(v, float):
            if v.is_integer():
                return int(v)
            return v
        elif isinstance(v, int):
            return int(v)
        else:
            return v

    norm_science = normalize(science)
    norm_env = normalize(environment)
    
    ordered_inputs = {}
    for role in ['red', 'nir']:
        if role in inputs:
            inp = inputs[role]
            ordered_inputs[role] = {
                'artifact_id': inp.get('artifact_id'),
                'sha256': inp.get('sha256'),
                'size_bytes': inp.get('size_bytes'),
                'raster': inp.get('raster'),
                'lineage': inp.get('lineage')
            }

    spec = {
        'policy_name': 'exact_environment_v1',
        'policy': 'exact_environment_v1',
        'equivalence_policy': 'exact_environment_v1',
        'stage': science.get('stage'),
        'settings': norm_science,
        'inputs': ordered_inputs,
        'environment': norm_env
    }
    
    normalized_spec = normalize(spec)
    json_bytes = json.dumps(normalized_spec, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')
    fingerprint = hashlib.sha256(json_bytes).hexdigest()
    return normalized_spec, fingerprint





def validate_pair(red, nir):
    if red['lineage']['collection'] != nir['lineage']['collection']:
        raise ValueError('Input collections differ')

    if red['lineage']['item_id'] != nir['lineage']['item_id']:
        raise ValueError('Input scenes differ')

    if red['lineage']['aoi_key'] != nir['lineage']['aoi_key']:
        raise ValueError('Input AOIs differ')

    if red['lineage']['recipe_version'] != nir['lineage']['recipe_version']:
        raise ValueError('Input extraction recipes differ')

    if red['lineage']['asset_key'] != 'red':
        raise ValueError('First input must be red')

    if nir['lineage']['asset_key'] != 'nir':
        raise ValueError('Second input must be nir')

    for key in ('shape', 'crs', 'transform'):
        if red['raster'][key] != nir['raster'][key]:
            raise ValueError(f'Input {key} differs')

    for metadata in (red, nir):
        scale = metadata['raster']['scale']
        offset = metadata['raster']['offset']

        if scale is None or not np.isfinite(scale) or scale <= 0:
            raise ValueError('Invalid radiometric scale')

        if offset is None or not np.isfinite(offset):
            raise ValueError('Invalid radiometric offset')


def calculate_ndvi(red, nir, red_meta, nir_meta, epsilon):
    red = np.asarray(red)
    nir = np.asarray(nir)

    red_valid = (red != red_meta['nodata']) & np.isfinite(red)
    nir_valid = (nir != nir_meta['nodata']) & np.isfinite(nir)

    red_float = red.astype(np.float64)
    nir_float = nir.astype(np.float64)

    red_reflectance = (
        red_float * red_meta['scale'] + red_meta['offset']
    )

    nir_reflectance = (
        nir_float * nir_meta['scale'] + nir_meta['offset']
    )

    denominator = nir_reflectance + red_reflectance

    valid = red_valid & nir_valid
    valid &= np.isfinite(denominator)
    valid &= np.abs(denominator) > epsilon

    result = np.full(red.shape, np.nan, dtype=np.float32)

    with np.errstate(divide='ignore', invalid='ignore'):
        result[valid] = (
            (nir_reflectance[valid] - red_reflectance[valid])
            / denominator[valid]
        ).astype(np.float32)

    return result