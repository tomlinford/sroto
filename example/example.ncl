# Example Nickel file for sroto
# This demonstrates the basic usage of the sroto Nickel frontend

let sroto = import "../sroto.ncl" in

sroto.File
  "example.proto"
  "example"
  # Enums
  [
    sroto.Enum [
      { name = "LOW", number = 1, help = "", options = [] },
      { name = "HIGH", number = 3, help = "", options = [] },
    ] & {
      name = "Priority",
      reserved_ranges = [
        { start = 2, end = 2 },
        { start = 4, end = null },  # null means "max"
      ],
      reserved_names = ["MEDIUM"],
    },
    sroto.Enum [
      { name = "QUALITY_HIGH", number = 2, help = "", options = [] },
      { name = "QUALITY_LOW", number = 1, help = "", options = [] },
    ] & { name = "Quality" },
  ]
  # Messages
  [
    sroto.Message
      [] # nested enums
      [] # nested messages
      # oneofs
      [
        sroto.Oneof [
          sroto.BoolField 2 & { name = "is_important" },
          sroto.Field "Priority" 3 & { name = "priority" },
        ] & { name = "importance" },
      ]
      # fields
      [
        sroto.StringField 1 & { name = "message" },
      ]
      & { name = "EchoRequest" },
    sroto.Message
      [] # nested enums
      [] # nested messages
      [] # oneofs
      # fields
      [
        sroto.StringField 1 & { name = "message" },
      ]
      & {
        name = "EchoResponse",
        help = m%"
          EchoResponse echoes back the initial message in the EchoRequest.

          This is used by EchoService.
        "%,
      },
  ]
  # Services
  [
    sroto.Service [
      sroto.UnaryMethod "EchoRequest" "EchoResponse" & { name = "Echo" },
      sroto.Method "EchoRequest" "EchoResponse" true true & { name = "StreamEcho" },
    ] & { name = "EchoService" },
  ]
  # Custom options
  []
