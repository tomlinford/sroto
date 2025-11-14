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

# Normalize option values: convert enum values to EnumValueLiteral
let rec NormalizeOptionValue = fun value =>
  let is_record = %typeof% value == 'Record in
  let is_array = %typeof% value == 'Array in
  # Enum values have "number" and "name" but not "type" (fields have "type")
  # and not "values" (enums have "values")
  let is_enum_value = is_record &&
    %record/has_field% "number" value &&
    %record/has_field% "name" value &&
    !(%record/has_field% "type" value) &&
    !(%record/has_field% "values" value) in

  if is_enum_value then
    # Convert enum value to EnumValueLiteral
    { name = value.name, reserved = "__enum_value_literal__" }
  else if is_record then
    # Recursively normalize nested records
    let field_names = %record/fields% value in
    std.array.fold_left
      (fun acc field_name =>
        let field_val = std.record.get field_name value in
        acc & { "%{field_name}" = NormalizeOptionValue field_val }
      )
      value
      field_names
  else if is_array then
    std.array.map NormalizeOptionValue value
  else
    value
in

# Normalize option format: {go_package: "..."} -> {type: {name: "go_package"}, value: "..."}
let NormalizeOption = fun opt =>
  let fields = %record/fields% opt in
  if std.array.length fields == 1 then
    # Shorthand format: {option_name: value}
    let opt_name = std.array.first fields in
    {
      type = { name = opt_name },
      path = "",
      value = std.record.get opt_name opt,  # Don't normalize here
    }
  else if %record/has_field% "type" opt && %record/has_field% "value" opt then
    # Full format: already has type and value fields - normalize to consistent structure
    {
      type = opt.type,
      path = if %record/has_field% "path" opt then opt.path else "",
      value = opt.value,
    }
  else
    # Unknown format, pass through
    opt
in

# Normalize option values after option format normalization
let NormalizeOptionValues = fun opt =>
  if %record/has_field% "value" opt then
    opt & { value | force = NormalizeOptionValue opt.value }
  else
    opt
in

# Recursively normalize all options arrays in a structure
let rec NormalizeAllOptions = fun value =>
  let HasField = fun obj field => %record/has_field% field obj in
  let is_record = %typeof% value == 'Record in
  let is_array = %typeof% value == 'Array in

  if is_record && HasField value "options" then
    # This record has an options field - normalize it and recursively process other fields
    let options_normalized = std.array.map NormalizeOption value.options in
    let other_fields = std.record.remove "options" value in
    let other_normalized = std.record.map (fun _name val => NormalizeAllOptions val) other_fields in
    other_normalized & { options = options_normalized }
  else if is_record then
    # Recursively process all fields
    std.record.map (fun _name val => NormalizeAllOptions val) value
  else if is_array then
    std.array.map NormalizeAllOptions value
  else
    value
in

# Add package and filename to top-level types that need them
let AddPackageInfo = fun pkg fname value =>
  let HasField = fun obj field => %record/has_field% field obj in
  let is_record = %typeof% value == 'Record in

  # Check if this is a type that needs package info
  let needs_package =
    is_record && (
      (HasField value "values") ||  # Enum
      (HasField value "fields") ||  # Message
      (HasField value "methods") || # Service
      (HasField value "option_type") # Custom option
    ) in

  # Add package/filename if needed and missing
  if needs_package && !(HasField value "package") then
    value & { package = pkg, filename = fname }
  else
    value
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
  Field = fun field_type field_number opts => {
    name | default = "",
    help | default = "",
    number = field_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) field_type,
    label | default = "",
    options = opts,
  },

  # Helper to create typed field constructors
  MakeFieldConstructor = fun type_name =>
    fun n opts => {
      name | default = "",
      help | default = "",
      number = n,
      type = { name = type_name },
      label | default = "",
      options = opts,
    },

  # Convenience field constructors for common types
  DoubleField = MakeFieldConstructor "double",
  FloatField = MakeFieldConstructor "float",
  Int32Field = MakeFieldConstructor "int32",
  Int64Field = MakeFieldConstructor "int64",
  Uint32Field = MakeFieldConstructor "uint32",
  Uint64Field = MakeFieldConstructor "uint64",
  Sint32Field = MakeFieldConstructor "sint32",
  Sint64Field = MakeFieldConstructor "sint64",
  Fixed32Field = MakeFieldConstructor "fixed32",
  Fixed64Field = MakeFieldConstructor "fixed64",
  Sfixed32Field = MakeFieldConstructor "sfixed32",
  Sfixed64Field = MakeFieldConstructor "sfixed64",
  BoolField = MakeFieldConstructor "bool",
  StringField = MakeFieldConstructor "string",
  BytesField = MakeFieldConstructor "bytes",

  # Repeated field constructor
  RepeatedField = fun field_type field_number opts => {
    name | default = "",
    help | default = "",
    number = field_number,
    type = (fun t => if %typeof% t == 'String then { name = t } else t) field_type,
    label = "repeated",
    options = opts,
  },

  # Enum value constructor - can be just a number or an object
  EnumValue = fun ev_number opts => {
    name | default = "",
    help | default = "",
    number = ev_number,
    options = opts,
  },

  # Enum constructor - accepts either a record {LOW = 1, HIGH = 2} or array of values
  # Supports reserved field shorthand: reserved = [1, [5, "max"], "OLD_NAME"]
  Enum = fun values opts =>
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
            if has_name then val else (std.record.remove "name" val) & { name = field_name }
        )
    in
    # Sort enum values by number only for record-style enums (records don't preserve order)
    # Array-style enums preserve declaration order
    let final_values = if is_array then value_array else SortBy (fun v => v.number) value_array in
    let enum_base = {
      name | default = "",
      help | default = "",
      values = final_values,
      options = opts,
      # Supports Jsonnet-style reserved shorthand: [2, [4, "max"], "MEDIUM"]
      reserved | default = [],
      reserved_ranges | force = (TransformReserved reserved).reserved_ranges,
      reserved_names | force = (TransformReserved reserved).reserved_names,
    } in
    # For record-based enums, create a record with EnumValue objects for each field
    # so they can be accessed (e.g., custom_options_example.SQLType.TEXT)
    if is_array then
      enum_base
    else
      let enum_value_record = std.record.from_array (
        std.array.map (fun v => { field = v.name, value = v }) final_values
      ) in
      enum_value_record & enum_base,

  # Oneof constructor - accepts a record of fields
  Oneof = fun fields_record opts =>
    let field_array = RecordToArray fields_record (fun field_name field_val =>
      let has_name = %record/has_field% "name" field_val && field_val.name != "" in
      if has_name then field_val else field_val & { name = field_name }
    ) in
    {
      name | default = "",
      help | default = "",
      fields = field_array,
      options = opts,
    },

  # Message constructor - accepts a record of definitions (fields, nested messages, enums, oneofs)
  Message = fun definitions opts =>
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
      options = opts,
      # Supports Jsonnet-style reserved shorthand: [2, [4, "max"], "field_name"]
      reserved | default = [],
      reserved_ranges | force = (TransformReserved reserved).reserved_ranges,
      reserved_names | force = (TransformReserved reserved).reserved_names,
    },

  # Method constructor
  Method = fun in_type out_type client_stream server_stream opts => {
    name | default = "",
    help | default = "",
    input_type = (fun t => if %typeof% t == 'String then { name = t } else t) in_type,
    output_type = (fun t => if %typeof% t == 'String then { name = t } else t) out_type,
    client_streaming = client_stream,
    server_streaming = server_stream,
    options = opts,
  },

  # Unary method convenience constructor
  UnaryMethod = fun in_type out_type opts => {
    name | default = "",
    help | default = "",
    input_type = (fun t => if %typeof% t == 'String then { name = t } else t) in_type,
    output_type = (fun t => if %typeof% t == 'String then { name = t } else t) out_type,
    client_streaming = false,
    server_streaming = false,
    options = opts,
  },

  # Service constructor - accepts a record of methods
  Service = fun methods_record opts =>
    let method_array = RecordToArray methods_record (fun method_name method_val =>
      let has_name = %record/has_field% "name" method_val && method_val.name != "" in
      if has_name then method_val else method_val & { name = method_name }
    ) in
    {
      name | default = "",
      help | default = "",
      methods = method_array,
      options = opts,
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

  # Helper to create custom option constructors for specific types
  MakeCustomOptionConstructor = fun option_type_name =>
    fun ctype cnumber => {
      name | default = "",
      help | default = "",
      number = cnumber,
      type = (fun t => if %typeof% t == 'String then { name = t } else t) ctype,
      option_type = option_type_name,
      label | default = "",
    },

  CustomFileOption = MakeCustomOptionConstructor "file_option",
  CustomMessageOption = MakeCustomOptionConstructor "message_option",
  CustomFieldOption = MakeCustomOptionConstructor "field_option",
  CustomOneofOption = MakeCustomOptionConstructor "oneof_option",
  CustomEnumOption = MakeCustomOptionConstructor "enum_option",
  CustomEnumValueOption = MakeCustomOptionConstructor "enum_value_option",
  CustomServiceOption = MakeCustomOptionConstructor "service_option",
  CustomMethodOption = MakeCustomOptionConstructor "method_option",

  # File constructor - accepts a record of definitions and optional file-level options
  # file_options: array of file-level options (defaults to [] if not provided)
  File = fun file_name file_package definitions file_options =>
    let HasField = fun obj field => %record/has_field% field obj in
    # Add package and filename to all top-level type definitions
    let field_names = %record/fields% definitions in
    let defs_with_package = std.array.fold_left
      (fun acc field_name =>
        let field_val = std.record.get field_name definitions in
        acc & { "%{field_name}" = AddPackageInfo file_package file_name field_val }
      )
      definitions
      field_names
    in
    let categorized = RecordToArray defs_with_package (fun def_name def_val =>
      let is_service = HasField def_val "methods" in
      let is_message = HasField def_val "messages" || (HasField def_val "fields" && !is_service) in
      let is_enum = HasField def_val "values" in
      let is_custom_option = HasField def_val "option_type" in
      let has_name = HasField def_val "name" && def_val.name != "" in

      {
        name = def_name,
        value =
          if has_name then
            def_val
          else
            # Remove name field (with default) and add it back with correct value
            (std.record.remove "name" def_val) & { name = def_name },
        category =
          if is_service then "service"
          else if is_message then "message"
          else if is_enum then "enum"
          else if is_custom_option then "custom_option"
          else "unknown"
      }
    ) in
    # Update definitions with names from categorization
    let defs_with_names = std.array.fold_left
      (fun acc item =>
        acc & { "%{item.name}" = item.value }
      )
      defs_with_package
      categorized
    in
    # Helper to normalize options in a value
    let NormalizeValueOptions = fun val =>
      if %record/has_field% "options" val && %typeof% val.options == 'Array then
        # Two-step normalization: format then values
        let format_normalized = std.array.map NormalizeOption val.options in
        let value_normalized = std.array.map NormalizeOptionValues format_normalized in
        # Remove old options field and add normalized one
        let val_without_options = std.record.remove "options" val in
        val_without_options & { options = value_normalized }
      else
        val
    in
    # Helper to normalize options in nested messages/fields
    let NormalizeMessageOptions = fun msg =>
      let msg_with_opts = NormalizeValueOptions msg in
      if %record/has_field% "fields" msg_with_opts && %typeof% msg_with_opts.fields == 'Array then
        let normalized_fields = std.array.map NormalizeValueOptions msg_with_opts.fields in
        msg_with_opts & { fields | force = normalized_fields }
      else
        msg_with_opts
    in
    # Normalize all options in the categorized values for IR output
    let enums_normalized = std.array.map (fun x => NormalizeValueOptions x.value) (std.array.filter (fun x => x.category == "enum") categorized) in
    let messages_normalized = std.array.map (fun x => NormalizeMessageOptions x.value) (std.array.filter (fun x => x.category == "message") categorized) in
    let services_normalized = std.array.map (fun x => NormalizeValueOptions x.value) (std.array.filter (fun x => x.category == "service") categorized) in
    let custom_options_normalized = std.array.map (fun x => NormalizeValueOptions x.value) (std.array.filter (fun x => x.category == "custom_option") categorized) in
    # Return the IR structure merged with the updated definitions
    defs_with_names & {
      name = file_name,
      package = file_package,
      enums = enums_normalized,
      messages = messages_normalized,
      services = services_normalized,
      custom_options = custom_options_normalized,
      # Normalize file options (handles shorthand {go_package: "..."} format)
      options = std.array.map NormalizeOption file_options,
    },
}
