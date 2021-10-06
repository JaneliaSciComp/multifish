---
layout: default
parent: Modules
nav_order: 10
---

# RS-FISH

## Interactive Parameter Finding

1. Use File->Import->N5 to open your data set and select the "Crop" option to cut out a small but interesting region for testing spot detection.
2. File->Save As->Tiff... and reopen the TIFF image.
3. Install RS-FISH plugins: Help->Update... then click "Manage Update Sites" and enable "Radial Symmetry" then click Close and restart Fiji. 
4. Plugins -> RS-FISH -> Tools -> Calculate Anisotropy Coefficient. Save this coefficient for later use. It should stay consistent when using the same microscope.
5. Plugins -> RS-FISH -> RS-FISH 
    * Set the anisotropy coefficient from step 4
    * Click Ok and Done on the options dialog
    * Set the minimum value in the intensity distribution
    * Click "OK press to proceed to final results"
6. RS-FISH -> Tools -> Show Detections in BigDataViewer

Iteratively adjust the parameters until you are detecting all the spots you want.

At the end, you can choose RS-FISH -> Advanced to view all of parameter values, or record to a macro to save them. This will give you all the parameters you need to run the pipeline:

```
run("RS-FISH", "image=cropped.tif mode=Advanced anisotropy=0.7213 robust_fitting=RANSAC compute_min/max use_anisotropy sigma=1.50000 threshold=0.00500 support=3 min_inlier_ratio=0.10 max_error=1.50 spot_intensity_threshold=269.54 background=[No background subtraction] background_subtraction_max_error=0.05 background_subtraction_min_inlier_ratio=0.10 results_file=[]");
```

