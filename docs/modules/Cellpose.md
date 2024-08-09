---
layout: default
parent: Modules
nav_order: 10
---

# Cellpose

[https://github.com/MouseLand/cellpose.git](Cellpose) is a generic segmentation algorithm.

Multifish pipeline currently supports Cellpose v2.0

## Pipeline usage 

To use Cellpose in order to perform the segmentation, you must pass the `--use_cellpose` parameter to the pipeline, and then specify additional Cellpose parameters, e.g. The work can be split for each block and distributed to a DASK cluster.

```
--use_cellpose --cellpose_model cyto --cellpose-diameter 30
```

More information about the parameters, including controlling the DASK cluster size, is included in the [parameter documentation](../Parameters.html).
