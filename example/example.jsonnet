local sroto = import "sroto.libsonnet";

sroto.File("example.proto", "example", {
    Priority: sroto.Enum({
        // note the lack of the 0 value here, it'll be auto-generated
        LOW: 1,
        HIGH: 3,
    }) {
        // In jsonnet you can pass in a sort of "keyword argument" by doing
        // object composition. The sroto.Enum call returns an object which is
        // then merged with this object with only the `reserved` field set.
        // This enables "subclasses" of these objects without requiring an
        // exhaustive redefinition of the optional arguments.
        reserved: [2, [4, "max"], "MEDIUM"],
    },
    EchoRequest: sroto.Message({
        message: sroto.StringField(1),
        importance: sroto.Oneof({
            is_important: sroto.BoolField(2),
            priority: sroto.Field("Priority", 3),
        }),
    }),
    EchoResponse: sroto.Message({
        message: sroto.StringField(1),
    }) {
        // All sroto types have a `help` attribute which can be used to insert
        // a comment before the definition in the .proto output, which then
        // gets pulled in by the protobuf compiler.
        help: |||
            EchoResponse echoes back the initial message in the EchoRequest.

            This is used by EchoService.
        |||
    },
    EchoService: sroto.Service({
        // UnaryMethod is just Method with false for (client|server)_streaming
        Echo: sroto.UnaryMethod("EchoRequest", "EchoResponse"),
        StreamEcho: sroto.Method("EchoRequest", "EchoResponse", true, true)
    }),
    // can also define enums with arrays, but need to specify the name. This
    // helps in certain situations like maintaining ordering, although generally
    // defining objects reads more cleanly.
    Quality: sroto.Enum([
        sroto.EnumValue(2) {name: "QUALITY_HIGH"},
        sroto.EnumValue(1) {name: "QUALITY_LOW"},
    ]),
})
