# Sroto Nickel Library
# A Nickel frontend for generating Protocol Buffer schemas

{
  # Helper function to normalize type representation
  NormalizeType = fun field_type =>
    if %typeof% field_type == 'String then
      { name = field_type }
    else
      field_type,

  # Well-known types from google.protobuf
  WKT = {
    Any = { name = "Any", package = "google.protobuf", filename = "google/protobuf/any.proto" },
    Duration = { name = "Duration", package = "google.protobuf", filename = "google/protobuf/duration.proto" },
    Empty = { name = "Empty", package = "google.protobuf", filename = "google/protobuf/empty.proto" },
    Timestamp = { name = "Timestamp", package = "google.protobuf", filename = "google/protobuf/timestamp.proto" },
    Value = { name = "Value", package = "google.protobuf", filename = "google/protobuf/struct.proto" },
    Struct = { name = "Struct", package = "google.protobuf", filename = "google/protobuf/struct.proto" },
    ListValue = { name = "ListValue", package = "google.protobuf", filename = "google/protobuf/struct.proto" },
    DoubleValue = { name = "DoubleValue", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    FloatValue = { name = "FloatValue", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    Int64Value = { name = "Int64Value", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    UInt64Value = { name = "UInt64Value", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    Int32Value = { name = "Int32Value", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    UInt32Value = { name = "UInt32Value", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    BoolValue = { name = "BoolValue", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    StringValue = { name = "StringValue", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    BytesValue = { name = "BytesValue", package = "google.protobuf", filename = "google/protobuf/wrappers.proto" },
    FieldMask = { name = "FieldMask", package = "google.protobuf", filename = "google/protobuf/field_mask.proto" },
  },

  # Enum value literal constructor (for use in option values)
  EnumValueLiteral = fun enum_name => {
    reserved = "__enum_value_literal__",
    name = enum_name,
  },

  # Bytes literal constructor (for use in option values)
  BytesLiteral = fun bytes_array => {
    reserved = "__bytes_literal__",
    value = bytes_array,
  },

  # Field constructor - creates a field with a given type and number
  Field = fun field_type field_number => {
    name | default = "",
    help | default = "",
    number = field_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) field_type,
    label | default = "",
    options | default = [],
  },

  # Convenience field constructors for common types
  DoubleField = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "double" },
    label | default = "",
    options | default = [],
  },

  FloatField = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "float" },
    label | default = "",
    options | default = [],
  },

  Int32Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "int32" },
    label | default = "",
    options | default = [],
  },

  Int64Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "int64" },
    label | default = "",
    options | default = [],
  },

  Uint32Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "uint32" },
    label | default = "",
    options | default = [],
  },

  Uint64Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "uint64" },
    label | default = "",
    options | default = [],
  },

  Sint32Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "sint32" },
    label | default = "",
    options | default = [],
  },

  Sint64Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "sint64" },
    label | default = "",
    options | default = [],
  },

  Fixed32Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "fixed32" },
    label | default = "",
    options | default = [],
  },

  Fixed64Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "fixed64" },
    label | default = "",
    options | default = [],
  },

  Sfixed32Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "sfixed32" },
    label | default = "",
    options | default = [],
  },

  Sfixed64Field = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "sfixed64" },
    label | default = "",
    options | default = [],
  },

  BoolField = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "bool" },
    label | default = "",
    options | default = [],
  },

  StringField = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "string" },
    label | default = "",
    options | default = [],
  },

  BytesField = fun n => {
    name | default = "",
    help | default = "",
    number = n,
    type = { name = "bytes" },
    label | default = "",
    options | default = [],
  },

  # Repeated field constructor
  RepeatedField = fun field_type field_number => {
    name | default = "",
    help | default = "",
    number = field_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) field_type,
    label = "repeated",
    options | default = [],
  },

  # Enum value constructor
  EnumValue = fun ev_number => {
    name | default = "",
    help | default = "",
    number = ev_number,
    options | default = [],
  },

  # Enum constructor
  Enum = fun enum_values => {
    name | default = "",
    help | default = "",
    values = enum_values,
    options | default = [],
    reserved_ranges | default = [],
    reserved_names | default = [],
  },

  # Oneof constructor
  Oneof = fun oneof_fields => {
    name | default = "",
    help | default = "",
    fields = oneof_fields,
    options | default = [],
  },

  # Message constructor
  Message = fun msg_enums msg_messages msg_oneofs msg_fields => {
    name | default = "",
    help | default = "",
    enums = msg_enums,
    messages = msg_messages,
    oneofs = msg_oneofs,
    fields = msg_fields,
    options | default = [],
    reserved_ranges | default = [],
    reserved_names | default = [],
  },

  # Method constructor
  Method = fun in_type out_type client_stream server_stream => {
    name | default = "",
    help | default = "",
    input_type = (fun t => if %typeof% t == 'String then { name = t } else t) in_type,
    output_type = (fun t => if %typeof% t == 'String then { name = t } else t) out_type,
    client_streaming = client_stream,
    server_streaming = server_stream,
    options | default = [],
  },

  # Unary method convenience constructor
  UnaryMethod = fun in_type out_type => {
    name | default = "",
    help | default = "",
    input_type = (fun t => if %typeof% t == 'String then { name = t } else t) in_type,
    output_type = (fun t => if %typeof% t == 'String then { name = t } else t) out_type,
    client_streaming = false,
    server_streaming = false,
    options | default = [],
  },

  # Service constructor
  Service = fun service_methods => {
    name | default = "",
    help | default = "",
    methods = service_methods,
    options | default = [],
  },

  # Custom option constructor
  CustomOption = fun opt_type opt_field_type opt_number => {
    name | default = "",
    help | default = "",
    number = opt_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) opt_field_type,
    option_type = opt_type,
    label | default = "",
  },

  # Custom option types (matching the Go enum)
  CustomFileOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "file_option",
    label | default = "",
  },

  CustomMessageOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "message_option",
    label | default = "",
  },

  CustomFieldOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "field_option",
    label | default = "",
  },

  CustomOneofOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "oneof_option",
    label | default = "",
  },

  CustomEnumOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "enum_option",
    label | default = "",
  },

  CustomEnumValueOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "enum_value_option",
    label | default = "",
  },

  CustomServiceOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "service_option",
    label | default = "",
  },

  CustomMethodOption = fun ctype cnumber => {
    name | default = "",
    help | default = "",
    number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "method_option",
    label | default = "",
  },

  # File constructor
  File = fun file_name file_package file_enums file_messages file_services file_custom_options => {
    name = file_name,
    package = file_package,
    enums = file_enums,
    messages = file_messages,
    services = file_services,
    custom_options = file_custom_options,
    options | default = [],
  },
}
