def channels_json_inputs(data_dir, channels, suffix) {
    channels_inputs(data_dir, channels, "${suffix}.json")
        .inject('') {
            arg, item -> "${arg} -i ${item}"
        }
}

def channels_inputs(data_dir, channels, suffix) {
    return channels.collect {
        "${data_dir}/${it}${suffix}"
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
