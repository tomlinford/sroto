# Example Nickel file for sroto - Improved version
# This demonstrates the clean API with automatic name extraction

let sroto = import "../sroto.ncl" in

sroto.File "example.proto" "example" {
  Priority = sroto.Enum {
    # Note: The 0 value will be auto-generated as PRIORITY_UNSPECIFIED
    LOW = 1,
    HIGH = 3,
  } & {
    # Nickel's record merging allows adding optional fields cleanly
    reserved_ranges = [
      { start = 2, end = 2 },
      { start = 4, end = null },  # null means "max"
    ],
    reserved_names = ["MEDIUM"],
  },

  EchoRequest = sroto.Message {
    message = sroto.StringField 1,
    importance = sroto.Oneof {
      is_important = sroto.BoolField 2,
      priority = sroto.Field "Priority" 3,
    },
  },

  EchoResponse = sroto.Message {
    message = sroto.StringField 1,
  } & {
    # Using record merging to add help text
    help = m%"
      EchoResponse echoes back the initial message in the EchoRequest.

      This is used by EchoService.
    "%,
  },

  EchoService = sroto.Service {
    # UnaryMethod is just Method with false for both streaming flags
    Echo = sroto.UnaryMethod "EchoRequest" "EchoResponse",
    StreamEcho = sroto.Method "EchoRequest" "EchoResponse" true true,
  },

  # Enums can also be defined with arrays for explicit ordering
  Quality = sroto.Enum [
    sroto.EnumValue 2 & { name = "QUALITY_HIGH" },
    sroto.EnumValue 1 & { name = "QUALITY_LOW" },
  ],
}
