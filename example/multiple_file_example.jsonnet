local sroto = import "sroto.libsonnet";

[
    sroto.File("example_%s.proto" % [x], "example_%s" % [x], {
        [std.asciiUpper(x)]: sroto.Message({
            message: sroto.StringField(1),
        })
    }) for x in ["a", "b"]
]
