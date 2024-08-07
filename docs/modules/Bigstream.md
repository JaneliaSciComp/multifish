---
layout: default
parent: Modules
nav_order: 10
---

# Bigstream

[https://github.com/JaneliaSciComp/bigstream.git](Bigstream) is a collection of tools for 3D registration. 

Bigstream registration allows you to run one or multiple algorithms in order to perform the registration of a moving round to a fixed round. The algorithm can be applied initially to the entire volume, at the `aff_scale`, in order to find a rough alignment, which then can be refined by applying the same or more finely grained algorithms on a per block basis at the `def_scale`. The current supported algorithms are: `ransac`, `affine`, `deform` and the parameters for these can be defined in a yaml file like [bigstream_config.yaml](../../configs/bigstream_config.yml). Since the rough alignment is performed in memory on the entire volume, the `aff_scale` must be chosen carefully or enough memory must be provided to the global registration steps. For refining the alignment, Bigstream partitions the volume at the `def_scale` and distributes the work for each block to a DASK cluster started as a Nextflow subworkflow. We currently provide parameters that allow you to configure both the size `bigstream_workers` and the resources (cpu: `bigstream_worker_cpus`, memory: `bigstream_worker_mem_gb`) allocated to the DASK cluster.

## Pipeline usage 

To use the new DASK based Bigstream instead of the legacy implementation, you must pass the `--use_bigstream` parameter to the pipeline, and then specify the Bigstream parameters, e.g.

```
--use_bigstream --bigstream_global_steps ransac --bigstream_local_steps "ransac,affine,deform" --bigstream_config my/bigstream_config.yml
```

More information about the parameters, including controlling the DASK cluster size, is included in the [parameter documentation](../Parameters.html).


## Bigstream tuning

Bigstream provides a collection of registration algorithms, such as ransac, gradient descent affine, gradient descent deform, etc. The parameters for all these algorithms can be provided in a yml file similar to the one provided in the configs folder: [configs/bigstream_config.yml](../../configs/bigstream_config.yml).
