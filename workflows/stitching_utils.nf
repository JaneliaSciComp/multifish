def entries_inputs_args(data_dir, entries, flag, suffix, ext) {
    entries_inputs(data_dir, entries, "${suffix}${ext}")
        .inject('') {
            arg, item -> "${arg} ${flag} ${item}"
        }
}

def entries_inputs(data_dir, entries, suffix) {
    return entries.collect {
        if (data_dir != null && data_dir != '')
            "${data_dir}/${it}${suffix}"
        else
            "${it}${suffix}"
    }
}

def read_config(cf) {
    jsonSlurper = new groovy.json.JsonSlurper()
    return jsonSlurper.parse(cf)
}

def write_config(data, cf) {
    json_str = groovy.json.JsonOutput.toJson(data)
    json_beauty = groovy.json.JsonOutput.prettyPrint(json_str)
    cf.write(json_beauty)
}
