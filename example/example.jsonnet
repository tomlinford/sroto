local sroto = import "sroto.libsonnet";

sroto.File("example.proto", "example", {
    Priority: sroto.Enum({
        // note the lack of the 0 value here, it'll be auto-generated
        LOW: 1,
        HIGH: 3,
    }) {
        // In jsonnet you can pass "keyword arguments" via object composition
        // The sroto.Enum call returns an object which is merged with this
        // object. This enables extending objects without exhaustive redefinition.
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
        // All sroto types have a `help` attribute for comments
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
    // Enums can also be defined with arrays for explicit ordering
    Quality: sroto.Enum([
        sroto.EnumValue(2) {name: "QUALITY_HIGH"},
        sroto.EnumValue(1) {name: "QUALITY_LOW"},
    ]),
})
