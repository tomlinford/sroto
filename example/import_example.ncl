let sroto = import "sroto.ncl" in
# importing from another sroto file
let example = import "example.ncl" in

# "importing" from a protobuf file
let Timestamp = {
  name = "Timestamp",
  filename = "google/protobuf/timestamp.proto",
  package = "google.protobuf",
} in

sroto.File "import_example.proto" "import_example" {
  LogEntry = sroto.Message {
    message = sroto.StringField 1,
    priority = sroto.Field example.Priority 2,
    created_at = sroto.Field Timestamp 3,
    # Well-known types (like Timestamp) are pre-defined in sroto.WKT,
    # so the above could be simplified by doing:
    updated_at = sroto.Field sroto.WKT.Timestamp 4,
  },
} []
