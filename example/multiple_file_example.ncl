let sroto = import "../sroto.ncl" in

std.array.map (fun x =>
  sroto.File "example_%{x}.proto" "example_%{x}" {
    "%{std.string.uppercase x}" = sroto.Message {
      message = sroto.StringField 1,
    },
  }
) ["a", "b"]
