include {
  apply_transform;
} from '../processes/registration' addParams(lsf_opts: params.lsf_opts, 
                                             registration_container: params.registration_container)

workflow warp_spots {

    take:
    fixed
    fixed_subpath
    moving
    moving_subpath
    warped_spots_txmpath
    warped_spots_outdir
    warped_spots_outfile
    points_path

    main:
    log.info """
    WARP SPOTS
    ===================================
    workDir              : $workDir
    warped_spots_txmpath : $warped_spots_txmpath
    warped_spots_outdir  : $warped_spots_outdir
    """
    .stripIndent()
                
    done = apply_transform(
        fixed,
        fixed_subpath,
        moving,
        moving_subpath,
        warped_spots_txmpath,
        warped_spots_outdir,
        warped_spots_outfile,
        points_path)
    
    emit:
    done
}
