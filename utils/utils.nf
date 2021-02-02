def index_channel(c) {
    c.reduce([ 0, [] ]) { accum, elem ->
        def indexed_elem = [accum[0], elem]
        [ accum[0]+1, accum[1]+[indexed_elem] ]
    } | flatMap { it[1] }
}
