/**
 * 
 * Given a list of directory paths that need to be accessed
 * create mount options for the current container engine.
 */
def create_container_options(dirList) {
    def dirs = dirList.unique(false)
    if (workflow.containerEngine == 'singularity') {
        dirs
        .findAll { it != null && it != '' }
        .inject(params.runtime_opts) {
            arg, item -> "${arg} -B ${item}"
        }
    } else if (workflow.containerEngine == 'docker') {
        dirs
        .findAll { it != null && it != '' }
        .inject(params.runtime_opts) {
            arg, item -> "${arg} -v ${item}:${item}"
        }
    } else {
        params.runtime_opts
    }
}