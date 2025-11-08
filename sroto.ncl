# Sroto Nickel Library - Improved Version
# A Nickel frontend for generating Protocol Buffer schemas
# This version provides a clean API similar to Jsonnet with automatic name extraction

let RecordToArray = fun record transform =>
  let fields = %record/fields% record in
  std.array.map (fun field_name => transform field_name (std.record.get field_name record)) fields
in

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
  DoubleField = fun n => { name | default = "", help | default = "", number = n, type = { name = "double" }, label | default = "", options | default = [] },
  FloatField = fun n => { name | default = "", help | default = "", number = n, type = { name = "float" }, label | default = "", options | default = [] },
  Int32Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "int32" }, label | default = "", options | default = [] },
  Int64Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "int64" }, label | default = "", options | default = [] },
  Uint32Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "uint32" }, label | default = "", options | default = [] },
  Uint64Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "uint64" }, label | default = "", options | default = [] },
  Sint32Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "sint32" }, label | default = "", options | default = [] },
  Sint64Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "sint64" }, label | default = "", options | default = [] },
  Fixed32Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "fixed32" }, label | default = "", options | default = [] },
  Fixed64Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "fixed64" }, label | default = "", options | default = [] },
  Sfixed32Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "sfixed32" }, label | default = "", options | default = [] },
  Sfixed64Field = fun n => { name | default = "", help | default = "", number = n, type = { name = "sfixed64" }, label | default = "", options | default = [] },
  BoolField = fun n => { name | default = "", help | default = "", number = n, type = { name = "bool" }, label | default = "", options | default = [] },
  StringField = fun n => { name | default = "", help | default = "", number = n, type = { name = "string" }, label | default = "", options | default = [] },
  BytesField = fun n => { name | default = "", help | default = "", number = n, type = { name = "bytes" }, label | default = "", options | default = [] },

  # Repeated field constructor
  RepeatedField = fun field_type field_number => {
    name | default = "",
    help | default = "",
    number = field_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) field_type,
    label = "repeated",
    options | default = [],
  },

  # Enum value constructor - can be just a number or an object
  EnumValue = fun ev_number => {
    name | default = "",
    help | default = "",
    number = ev_number,
    options | default = [],
  },

  # Enum constructor - accepts either a record {LOW = 1, HIGH = 2} or array of values
  # Supports reserved field shorthand: reserved = [1, [5, "max"], "OLD_NAME"]
  Enum = fun values =>
    let is_array = %typeof% values == 'Array in
    let value_array =
      if is_array then
        values
      else
        # Convert record to array of enum values, extracting names
        RecordToArray values (fun field_name val =>
          if %typeof% val == 'Number then
            { name = field_name, number = val, help | default = "", options | default = [] }
          else
            let has_name = %record/has_field% "name" val && val.name != "" in
            if has_name then val else val & { name = field_name }
        )
    in
    {
      name | default = "",
      help | default = "",
      values = value_array,
      options | default = [],
      reserved_ranges | default = [],
      reserved_names | default = [],
    },

  # Oneof constructor - accepts a record of fields
  Oneof = fun fields_record =>
    let field_array = RecordToArray fields_record (fun field_name field_val =>
      let has_name = %record/has_field% "name" field_val && field_val.name != "" in
      if has_name then field_val else field_val & { name = field_name }
    ) in
    {
      name | default = "",
      help | default = "",
      fields = field_array,
      options | default = [],
    },

  # Message constructor - accepts a record of definitions (fields, nested messages, enums, oneofs)
  Message = fun definitions =>
    let HasField = fun obj field => %record/has_field% field obj in
    let categorized = RecordToArray definitions (fun def_name def_val =>
      # Categorize based on structure
      let is_field = HasField def_val "number" && HasField def_val "type" in
      let is_oneof = HasField def_val "fields" && !(HasField def_val "messages") in
      let is_message = HasField def_val "messages" in
      let is_enum = HasField def_val "values" in
      let has_name = HasField def_val "name" && def_val.name != "" in

      {
        name = def_name,
        value = if has_name then def_val else def_val & { name = def_name },
        category =
          if is_field then "field"
          else if is_oneof then "oneof"
          else if is_message then "message"
          else if is_enum then "enum"
          else "unknown"
      }
    ) in
    {
      name | default = "",
      help | default = "",
      enums = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "enum") categorized),
      messages = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "message") categorized),
      oneofs = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "oneof") categorized),
      fields = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "field") categorized),
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

  # Service constructor - accepts a record of methods
  Service = fun methods_record =>
    let method_array = RecordToArray methods_record (fun method_name method_val =>
      let has_name = %record/has_field% "name" method_val && method_val.name != "" in
      if has_name then method_val else method_val & { name = method_name }
    ) in
    {
      name | default = "",
      help | default = "",
      methods = method_array,
      options | default = [],
    },

  # Custom option constructors
  CustomOption = fun opt_type opt_field_type opt_number => {
    name | default = "",
    help | default = "",
    number = opt_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) opt_field_type,
    option_type = opt_type,
    label | default = "",
  },

  CustomFileOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "file_option", label | default = "",
  },

  CustomMessageOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "message_option", label | default = "",
  },

  CustomFieldOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "field_option", label | default = "",
  },

  CustomOneofOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "oneof_option", label | default = "",
  },

  CustomEnumOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "enum_option", label | default = "",
  },

  CustomEnumValueOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "enum_value_option", label | default = "",
  },

  CustomServiceOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "service_option", label | default = "",
  },

  CustomMethodOption = fun ctype cnumber => {
    name | default = "", help | default = "", number = cnumber,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
    option_type = "method_option", label | default = "",
  },

  # File constructor - accepts a record of definitions
  File = fun file_name file_package definitions =>
    let HasField = fun obj field => %record/has_field% field obj in
    let categorized = RecordToArray definitions (fun def_name def_val =>
      let is_service = HasField def_val "methods" in
      let is_message = HasField def_val "messages" || (HasField def_val "fields" && !is_service) in
      let is_enum = HasField def_val "values" in
      let is_custom_option = HasField def_val "option_type" in
      let has_name = HasField def_val "name" && def_val.name != "" in

      {
        name = def_name,
        value = if has_name then def_val else def_val & { name = def_name },
        category =
          if is_service then "service"
          else if is_message then "message"
          else if is_enum then "enum"
          else if is_custom_option then "custom_option"
          else "unknown"
      }
    ) in
    {
      name = file_name,
      package = file_package,
      enums = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "enum") categorized),
      messages = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "message") categorized),
      services = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "service") categorized),
      custom_options = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "custom_option") categorized),
      options | default = [],
    },
}
