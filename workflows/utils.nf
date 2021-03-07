/**
 * index_channel converts the original channel into
 * another channel that contains a tuple of with 
 * the position of the element in the channel and element itself.
 * For example:
 * [e1, e2, e3, ..., en] -> [ [0, e1], [1, e2], [2, e3], ..., [n-1, en] ]
 *
 * This function is needed when we need to pair outputs from process, let's say P1,
 * with other inputs to be passed to another process, P2  in the pipeline,
 * because the asynchronous nature of the process execution
 */
def index_channel(c) {
    c.reduce([ 0, [] ]) { accum, elem ->
        def indexed_elem = [accum[0], elem]
        [ accum[0]+1, accum[1]+[indexed_elem] ]
    } | flatMap { it[1] }
}
