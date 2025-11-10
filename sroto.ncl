# Sroto Nickel Library - Improved Version
# A Nickel frontend for generating Protocol Buffer schemas
# This version provides a clean API similar to Jsonnet with automatic name extraction

let RecordToArray = fun record transform =>
  let fields = %record/fields% record in
  std.array.map (fun field_name => transform field_name (std.record.get field_name record)) fields
in

# Sort array by a key function (Nickel doesn't have std.array.sort_by built-in)
let SortBy = fun key_fn array =>
  let with_keys = std.array.map (fun elem => { key = key_fn elem, value = elem }) array in
  let sorted = std.array.sort (fun a b =>
    if a.key < b.key then 'Lesser
    else if a.key > b.key then 'Greater
    else 'Equal
  ) with_keys in
  std.array.map (fun x => x.value) sorted
in

# Transform reserved shorthand: [1, [5, 10], [20, "max"], "NAME"]
# into separate reserved_ranges and reserved_names arrays (like Jsonnet)
let TransformReserved = fun reserved_list =>
  let ranges = std.array.filter (fun r =>
    %typeof% r == 'Number ||
    (%typeof% r == 'Array && %typeof% (std.array.first r) == 'Number)
  ) reserved_list in
  let names = std.array.filter (fun r => %typeof% r == 'String) reserved_list in
  {
    reserved_ranges = std.array.map (fun r =>
      if %typeof% r == 'Number then
        { start = r, end = r }
      else if std.array.length r == 2 then
        if %typeof% (std.array.last r) == 'String then
          { start = std.array.first r, end = null }
        else
          { start = std.array.first r, end = std.array.last r }
      else
        { start = std.array.first r, end = std.array.first r }
    ) ranges,
    reserved_names = names,
  }
in

{
  # Helper function to normalize type representation
  NormalizeType = fun field_type =>
    if %typeof% field_type == 'String then
      { name = field_type }
    else
      field_type,

  # Well-known types from google.protobuf
  WKT =
    let bytesLiteral_def = fun bytes_array => {
      reserved = "__bytes_literal__",
      value = bytes_array,
    } in

    let enumValueLiteral_def = fun enum_name => {
      reserved = "__enum_value_literal__",
      name = enum_name,
    } in

    let mapLiteral_def = fun map =>
      let fields = %record/fields% map in
      std.array.map (fun k => { key = k, value = std.record.get k map }) fields in

    # Mutually recursive literal value constructors for struct types
    let rec literals = {
      listValueLiteral = fun list_vals =>
        if list_vals == null then null
        else { values = std.array.map (fun v => literals.valueLiteral v) list_vals },

      structLiteral = fun struct_val =>
        if struct_val == null then null
        else
          let field_keys = %record/fields% struct_val in
          {
            fields = std.array.map (fun k =>
              { key = k, value = literals.valueLiteral (std.record.get k struct_val) }
            ) field_keys
          },

      valueLiteral = fun val =>
        if val == null then { null_value = enumValueLiteral_def "NULL_VALUE" }
        else if %typeof% val == 'Number then { number_value = val }
        else if %typeof% val == 'String then { string_value = val }
        else if %typeof% val == 'Bool then { bool_value = val }
        else if %typeof% val == 'Record then { struct_value = literals.structLiteral val }
        else if %typeof% val == 'Array then { list_value = literals.listValueLiteral val }
        else std.contract.blame_with_message "invalid type for ValueLiteral" val,
    } in

    # Type definitions and literal constructors
    {
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

      # Literal value constructors for well-known wrapper types
      BoolValueLiteral = fun v => if v == null then null else { value = v },
      BytesValueLiteral = fun v => if v == null then null else { value = bytesLiteral_def v },
      DoubleValueLiteral = fun v => if v == null then null else { value = v },
      FloatValueLiteral = fun v => if v == null then null else { value = v },
      Int32ValueLiteral = fun v => if v == null then null else { value = v },
      Int64ValueLiteral = fun v => if v == null then null else { value = v },
      StringValueLiteral = fun v => if v == null then null else { value = v },
      UInt32ValueLiteral = fun v => if v == null then null else { value = v },
      UInt64ValueLiteral = fun v => if v == null then null else { value = v },
      ListValueLiteral = literals.listValueLiteral,
      StructLiteral = literals.structLiteral,
      ValueLiteral = literals.valueLiteral,
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

  # Map literal constructor (converts object to protobuf map format)
  MapLiteral = fun map =>
    let fields = %record/fields% map in
    std.array.map (fun k => { key = k, value = std.record.get k map }) fields,

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
    # Sort enum values by number ONLY for record-style (matching Jsonnet's behavior)
    # Array-style enums preserve insertion order
    let final_values =
      if is_array then value_array
      else SortBy (fun v => v.number) value_array
    in
    let enum_base = {
      name | default = "",
      help | default = "",
      values = final_values,
      options | default = [],
      # Supports Jsonnet-style reserved shorthand: [2, [4, "max"], "MEDIUM"]
      reserved | default = [],
      reserved_ranges | force = (TransformReserved reserved).reserved_ranges,
      reserved_names | force = (TransformReserved reserved).reserved_names,
    } in
    # For record-based enums, merge the original values back so they can be accessed
    # (e.g., custom_options_example.SQLType.TEXT)
    if is_array then enum_base else values & enum_base,

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
    let field_values = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "field") categorized) in
    # Sort fields by their number (matching Jsonnet's behavior)
    let sorted_fields = SortBy (fun f => f.number) field_values in
    {
      name | default = "",
      help | default = "",
      enums = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "enum") categorized),
      messages = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "message") categorized),
      oneofs = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "oneof") categorized),
      fields = sorted_fields,
      options | default = [],
      # Supports Jsonnet-style reserved shorthand: [2, [4, "max"], "field_name"]
      reserved | default = [],
      reserved_ranges | force = (TransformReserved reserved).reserved_ranges,
      reserved_names | force = (TransformReserved reserved).reserved_names,
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
    # Return the IR structure merged with the original definitions
    # This allows importing files and accessing their definitions (like example.Priority)
    definitions & {
      name = file_name,
      package = file_package,
      enums = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "enum") categorized),
      messages = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "message") categorized),
      services = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "service") categorized),
      custom_options = std.array.map (fun x => x.value) (std.array.filter (fun x => x.category == "custom_option") categorized),
      options | default = [],
    },
}
