// Gaven Rendell, 2021.


const EncodingMethod = enum {
    raw,
    static,
    dynamic
}

const Block = struct {
    last_in_stream: bool,
    encoding_method: EncodingMethod,
};

