# Nickel Frontend for Sroto

This document describes the Nickel-lang frontend for sroto, an alternative to the Jsonnet frontend.

## Table of Contents

- [Overview](#overview)
- [Installation Requirements](#installation-requirements)
- [Basic Usage](#basic-usage)
- [API Reference](#api-reference)
- [Advanced Features](#advanced-features)
- [Comparison with Jsonnet](#comparison-with-jsonnet)
- [Complete Examples](#complete-examples)
  - [Importing Example](#importing-example)
  - [Options Example](#options-example)
  - [Composed Fields Example](#composed-fields-example)
  - [Custom Options Example](#custom-options-example)
  - [Importing from .proto Files](#importing-from-proto-files)
  - [Generating Multiple .proto Files](#generating-multiple-proto-files)
- [Additional Examples](#additional-examples)
- [Troubleshooting](#troubleshooting)
- [Implementation Details](#implementation-details)
- [See Also](#see-also)

## Overview

[Nickel](https://nickel-lang.org/) is a configuration language designed to be "JSON with functions" and offers several advantages over Jsonnet:

- **Modern type system**: Opt-in static typing with contracts for validation
- **Better tooling**: Built-in LSP, REPL, and documentation generator
- **Record merging**: First-class support for composing configurations
- **Functional programming**: Clean syntax with pattern matching and destructuring

The Nickel frontend for sroto provides the same functionality as the Jsonnet frontend but leverages Nickel's unique features.

## Installation Requirements

To use the Nickel frontend, you need:

1. **Nickel CLI**: Install from [nickel-lang.org](https://nickel-lang.org/)
   ```bash
   # On macOS with Homebrew
   brew install nickel

   # Or build from source
   cargo install nickel-lang-cli
   ```

2. **Sroto**: The sroto toolchain (already installed if you're reading this)

## Basic Usage

### Creating a Nickel Schema

Create a `.ncl` file that imports the `sroto.ncl` library:

```nickel
let sroto = import "sroto.ncl" in

sroto.File "my_service.proto" "mypackage" {
  MyMessage = sroto.Message {
    id = sroto.Int64Field 1,
    name = sroto.StringField 2,
  },

  MyService = sroto.Service {
    GetMessage = sroto.UnaryMethod "MyMessage" "MyMessage",
  },
}
```

### Generating Proto Files

Use `srotoc` just like with Jsonnet files:

```bash
srotoc --proto_out=./gen my_service.ncl
```

You can also mix Nickel and Jsonnet files:

```bash
srotoc --proto_out=./gen schema1.ncl schema2.jsonnet
```

## API Reference

The Nickel API closely mirrors the Jsonnet API. Here are the main functions:

### File Constructor

```nickel
sroto.File : String -> String -> Record -> File
```

Creates a proto file definition.

**Parameters:**
- `name`: The output filename (e.g., `"example.proto"`)
- `package`: The protobuf package name
- `definitions`: A record containing messages, enums, services, and custom options

**Example:**
```nickel
sroto.File "example.proto" "myapp" {
  MyMessage = sroto.Message { ... },
  MyEnum = sroto.Enum { ... },
}
```

### Message Constructor

```nickel
sroto.Message : Record -> Message
```

Creates a message definition. The record can contain fields, nested messages, enums, and oneofs.

**Example:**
```nickel
MyMessage = sroto.Message {
  id = sroto.Int64Field 1,
  nested = sroto.Message {
    value = sroto.StringField 1,
  },
  priority = sroto.Field "Priority" 2,
}
```

### Field Constructors

Basic field constructor:
```nickel
sroto.Field : (String | Type) -> Number -> Field
```

Convenience constructors for common types:
- `sroto.StringField : Number -> Field`
- `sroto.Int32Field : Number -> Field`
- `sroto.Int64Field : Number -> Field`
- `sroto.BoolField : Number -> Field`
- `sroto.DoubleField : Number -> Field`
- `sroto.FloatField : Number -> Field`
- `sroto.BytesField : Number -> Field`
- And more...

Repeated fields:
```nickel
sroto.RepeatedField : (String | Type) -> Number -> Field
```

**Example:**
```nickel
{
  name = sroto.StringField 1,
  count = sroto.Int32Field 2,
  tags = sroto.RepeatedField "string" 3,
  custom_type = sroto.Field "CustomMessage" 4,
}
```

### Enum Constructor

```nickel
sroto.Enum : (Record | Array) -> Enum
```

Creates an enum. Can accept either a record (for named values) or an array (for explicit ordering).

**Record style:**
```nickel
Priority = sroto.Enum {
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3,
}
```

**Array style:**
```nickel
Priority = sroto.Enum [
  sroto.EnumValue 3 & { name = "HIGH" },
  sroto.EnumValue 2 & { name = "MEDIUM" },
  sroto.EnumValue 1 & { name = "LOW" },
]
```

**Note:** The enum value 0 will be auto-generated as `{ENUM_NAME}_UNSPECIFIED` if not provided.

### Oneof Constructor

```nickel
sroto.Oneof : Record -> Oneof
```

Creates a oneof field group.

**Example:**
```nickel
importance = sroto.Oneof {
  is_important = sroto.BoolField 2,
  priority_level = sroto.Int32Field 3,
}
```

### Service Constructor

```nickel
sroto.Service : Record -> Service
```

Creates a gRPC service definition.

**Example:**
```nickel
MyService = sroto.Service {
  GetUser = sroto.UnaryMethod "GetUserRequest" "User",
  StreamUsers = sroto.Method "Empty" "User" false true,
}
```

### Method Constructors

```nickel
sroto.Method : Type -> Type -> Bool -> Bool -> Method
sroto.UnaryMethod : Type -> Type -> Method
```

Create RPC methods. `UnaryMethod` is a convenience wrapper for non-streaming RPCs.

**Parameters:**
- `input_type`: Input message type
- `output_type`: Output message type
- `client_streaming`: Whether the client streams
- `server_streaming`: Whether the server streams

## Advanced Features

### Adding Options

In Nickel's sroto implementation, options are added as an array parameter after the definition:

For message options:
```nickel
MyMessage = sroto.Message {
  id = sroto.StringField 1,
} [{
  type = { name = "deprecated" },
  path = "",
  value = true,
}]
```

For field options, pass the options array directly to the field constructor:
```nickel
{
  email = sroto.StringField 1 [{
    type = {
      name = "field_behavior",
      package = "google.api",
      filename = "google/api/field_behavior.proto",
    },
    path = "",
    value = [sroto.EnumValueLiteral "REQUIRED"],
  }],
}
```

For file options:
```nickel
sroto.File "example.proto" "example" {
  MyMessage = sroto.Message { ... },
} [
  { go_package = "github.com/example/mypackage" }
]
```

### Reserved Fields

Nickel supports reserved field definitions using record fields within the message or enum definition.

**Shorthand style (recommended):**

```nickel
MyEnum = sroto.Enum {
  LOW = 1,
  HIGH = 3,
  # Mix numbers, ranges, and names in a single array
  reserved = [
    2,              # Single field number
    [10, 20],       # Range from 10 to 20
    [100, "max"],   # Range from 100 to max
    "DEPRECATED",   # Reserved name
  ],
}
```

**Explicit style:**

```nickel
MyEnum = sroto.Enum {
  LOW = 1,
  HIGH = 3,
  reserved_ranges = [
    { start = 2, end = 2 },
    { start = 10, end = 20 },
    { start = 100, end = null },  # null means "max"
  ],
  reserved_names = ["DEPRECATED_VALUE"],
}
```

The shorthand `reserved` field is automatically transformed into separate `reserved_ranges` and `reserved_names` during proto generation (not at Nickel evaluation time). Both styles work for enums and messages.

### Well-Known Types

Use the `WKT` record for Google's well-known types:

```nickel
MyMessage = sroto.Message {
  created_at = sroto.Field sroto.WKT.Timestamp 1,
  metadata = sroto.Field sroto.WKT.Struct 2,
  duration = sroto.Field sroto.WKT.Duration 3,
}
```

### Custom Options

Define custom options for extending protobuf:

```nickel
sroto.File "example.proto" "myapp" {
  my_option = sroto.CustomFieldOption "string" 50000,

  MyMessage = sroto.Message {
    field = sroto.StringField 1 [{
      type = { name = "my_option", package = "myapp" },
      path = "",
      value = "custom value",
    }],
  },
} []
```

### Help Text / Comments

Add documentation comments using the `help` field within the message definition:

```nickel
MyMessage = sroto.Message {
  id = sroto.Int64Field 1,
  help = m%"
    MyMessage represents a user in the system.

    It contains the unique identifier and other metadata.
  "%,
}
```

Nickel's multiline strings (`m%"..."%`) are perfect for documentation. The `help` field can be added to messages, enums, fields, and other definitions.

## Comparison with Jsonnet

### Similarities

- Both frontends generate the same IR format
- Both produce identical `.proto` output
- API is nearly identical between the two

### Differences

| Feature | Jsonnet | Nickel |
|---------|---------|--------|
| String interpolation | `"%(name)s"` | `"%{name}"` |
| Multiline strings | `\|\|\|...\|\|\|` | `m%"..."%` |
| Record merging | `+:` | `&` |
| Imports | `import "file.libsonnet"` | `import "file.ncl"` |
| Type system | None (dynamic only) | Optional static + contracts |
| Standard library | `std.*` | `std.array.*`, `std.string.*`, etc. |
| Options syntax | `{options+: [...]}` | Field/array params `[...]` |

### Why Choose Nickel?

1. **Better tooling**: LSP support out of the box
2. **Type safety**: Optional contracts for validation
3. **Cleaner syntax**: More modern, functional programming style
4. **Better errors**: More helpful error messages
5. **Active development**: Nickel is actively maintained by Tweag

### Why Stick with Jsonnet?

1. **Established**: More mature ecosystem
2. **No dependencies**: Already integrated into sroto
3. **Familiar**: If you're already using Jsonnet elsewhere

## Complete Examples

### Importing Example

Imports can either be from `.ncl` files or specified raw (from `.proto` files):

```nickel
# filename: import_example.ncl

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
```

**Generated output:**
```protobuf
// filename: import_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package import_example;

import "example.proto";
import "google/protobuf/timestamp.proto";

message LogEntry {
    string message = 1;
    example.Priority priority = 2;
    google.protobuf.Timestamp created_at = 3;
    google.protobuf.Timestamp updated_at = 4;
}
```

This bundles type information together:
1. Type name (the enum, message, or custom option)
2. Which file the type is declared in
3. Package of that file

### Options Example

Suppose we want a UUID field with OpenAPI documentation via [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) and validation via [protoc-gen-validate](https://github.com/envoyproxy/protoc-gen-validate).

In raw protobuf this is not composable:

```protobuf
import "protoc-gen-openapiv2/options/annotations.proto";
import "validate/validate.proto";

message User {
    string id = 1 [
        (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_field) = {
            pattern: "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}",
            min_length: 36  // quick quiz: are trailing commas permitted? (answer: no)
        },
        (validate.rules).string.uuid = true
    ];
    ...
}
```

With sroto, create a reusable `UUIDField`:

```nickel
# filename: my_custom_fields.ncl

let sroto = import "sroto.ncl" in

{
  UUIDField = fun number => sroto.StringField number [
    {
      # of course, can choose to just inline the "imports"
      type = {
        name = "openapiv2_field",
        filename = "protoc-gen-openapiv2/options/annotations.proto",
        package = "grpc.gateway.protoc_gen_openapiv2.options",
      },
      value = {
        pattern = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}",
        min_length = 36,
      },
    },
    {
      # this is equivalent to doing (validate.rules).string.uuid = true
      type = {
        name = "rules",
        filename = "validate/validate.proto",
        package = "validate",
      },
      path = "string.uuid",
      value = true,
    },
  ],
}
```

Then use it anywhere:

```nickel
# filename: options_example.ncl

let sroto = import "sroto.ncl" in
let my_custom_fields = import "my_custom_fields.ncl" in

# "import" the custom options
let openapiv2Annotation = fun name_suffix => {
  name = "openapiv2_%{name_suffix}",
  filename = "protoc-gen-openapiv2/options/annotations.proto",
  package = "grpc.gateway.protoc_gen_openapiv2.options",
} in
let api_field_behavior = {
  name = "field_behavior",
  filename = "google/api/field_behavior.proto",
  package = "google.api",
} in
let http_api = {
  name = "http",
  filename = "google/api/annotations.proto",
  package = "google.api",
} in

sroto.File "options_example.proto" "example" {
  User = sroto.Message {
    id = my_custom_fields.UUIDField 1,
    referrer_user_id = my_custom_fields.UUIDField 2,
  } [{
    type = openapiv2Annotation "schema",
    path = "example",
    value = std.serialize 'Json {
      id = "24508faf-20e3-46ca-8b09-d079b595ef0b",
      referrer_user_id = "27fa4a4e-5650-484f-87f9-bd915889f92b",
    },
  }],
  GetUserRequest = sroto.Message {
    id = sroto.StringField 1 [{
      type = api_field_behavior,
      value = [sroto.EnumValueLiteral "REQUIRED"],
    }],
  },
  UserService = sroto.Service {
    GetUser = sroto.UnaryMethod "GetUserRequest" "User" [{
      type = http_api,
      value = { get = "/users/{id}" },
    }],
  } [{
    type = openapiv2Annotation "tag",
    path = "description",
    value = "UserService is for various operations on users.",
  }],
} [
  # Built-in options use simple key/value syntax
  { go_package = "github.com/tomlinford/sroto/example/options_example" }
]
```

### Composed Fields Example

Create reusable custom field types by composing fields with options at multiple levels using array concatenation:

```nickel
# filename: composed_fields_example.ncl

# Example demonstrating field composition with options at multiple levels
let sroto = import "sroto.ncl" in

# Layer 1: Base custom field with validation options
let StringFieldWithValidation = fun number min_length max_length opts =>
  sroto.StringField number ([{
    type = {
      name = "rules",
      filename = "validate/validate.proto",
      package = "validate",
    },
    path = "string",
    value = {
      min_len = min_length,
      max_len = max_length,
    },
  }] @ opts)
in

# Layer 2: UUID field built on validated string field
let UUIDField = fun number opts =>
  StringFieldWithValidation number 36 36 ([{
    type = {
      name = "rules",
      filename = "validate/validate.proto",
      package = "validate",
    },
    path = "string.uuid",
    value = true,
  }] @ opts)
in

# Layer 3: Required UUID field built on UUID field
let RequiredUUIDField = fun number opts =>
  UUIDField number ([{
    type = {
      name = "field_behavior",
      filename = "google/api/field_behavior.proto",
      package = "google.api",
    },
    value = [sroto.EnumValueLiteral "REQUIRED"],
  }] @ opts)
in

sroto.File "composed_fields_example.proto" "composed_fields_example" {
  User = sroto.Message {
    # Uses base custom field
    nickname = StringFieldWithValidation 1 3 50 [],
    # Uses layer 2 (composed) custom field
    user_id = UUIDField 2 [],
    # Uses layer 3 (double composed) custom field
    tenant_id = RequiredUUIDField 3 [],
  } [],
} []
```

**Generated output:**
```protobuf
# filename: composed_fields_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package composed_fields_example;

import "google/api/field_behavior.proto";
import "validate/validate.proto";

message User {
    string nickname = 1 [
        (validate.rules) = {string: {max_len: 50, min_len: 3}}
    ];
    string user_id = 2 [(validate.rules).string.uuid = true];
    string tenant_id = 3 [
        (google.api.field_behavior) = REQUIRED,
        (validate.rules).string.uuid = true
    ];
}
```

Note how `tenant_id` combines options from multiple composition layers - both the `REQUIRED` field behavior from `RequiredUUIDField` and the UUID validation from `UUIDField`. The `@ opts` operator (array concatenation) ensures that options are accumulated at each composition layer, with each composed function accepting an `opts` parameter that gets concatenated with its own options before passing to the next layer.

### Options Merging Behavior

When composing fields with options in Nickel, understand how options are merged:

- **Using `@ opts`** - Concatenates option arrays, accumulating all options from each layer
- The pattern `([{...}] @ opts)` ensures caller-provided options are added to the function's own options

Options are accumulated in an array, processed by sroto in order. If multiple options set the same field:
- **Different types**: All options are applied independently
- **Same type, different paths**: Both options are applied (e.g., `(validate.rules).string.min_len` and `(validate.rules).string.uuid`)
- **Same type, same path**: Later options in the array take precedence

**Example of option conflict:**
```nickel
# This field has conflicting min_len values
let ConflictingField = fun number =>
  sroto.StringField number [
    { type = rules, path = "string.min_len", value = 5 },
    { type = rules, path = "string.min_len", value = 10 },  # This wins
  ]
in
```

In practice, avoid conflicts by designing your composed fields carefully. Each composition layer should add complementary options, not conflicting ones.

### Custom Options Example

Define custom options in your schemas:

```nickel
# filename: custom_options_example.ncl

let sroto = import "sroto.ncl" in

sroto.File "custom_options_example.proto" "custom_options_example" {
  SQLTableOptions = sroto.Message {
    table_name = sroto.StringField 1,
    table_tags = sroto.Field sroto.WKT.Struct 2,
    table_bin_data = sroto.BytesField 3,
    # Obviously using StringValues doesn't really make sense for custom
    # options, but the example is here for illustrative purposes.
    prev_table_name = sroto.Field sroto.WKT.StringValue 4,
    next_table_name = sroto.Field sroto.WKT.StringValue 5,
  },
  sql_table = sroto.CustomMessageOption "SQLTableOptions" 6072,
  SQLType = sroto.Enum {
    BIGINT = 1,
    TEXT = 2,
  },
  sql_type = sroto.CustomFieldOption "SQLType" 6073,
} []
```

Use the custom options:

```nickel
# filename: using_custom_options_example.ncl

let sroto = import "sroto.ncl" in
let custom_options_example = import "custom_options_example.ncl" in

sroto.File "using_custom_options_example.proto" "using_custom_options_example" {
  UserTable = sroto.Message {
    id = sroto.StringField 1 [{
      # note how we can just use the `sroto` objects directly here:
      type = custom_options_example.sql_type,
      value = custom_options_example.SQLType.TEXT,
    }],
  } [{
    type = custom_options_example.sql_table,
    value = {
      table_name = "users",
      # Can encode an arbitrary object!
      table_tags = sroto.WKT.StructLiteral {
        foo = "bar",
        baz = ["qux", "quz"],
        teapot = null,
      },
      table_bin_data = sroto.BytesLiteral [0, 1, 2, 3, 4, 5, 6, 7, 8],
      prev_table_name = sroto.WKT.StringValueLiteral "old_users",
      next_table_name = null, # This entry will get omitted.
    },
  }],
}
```

**Generated output:**
```protobuf
// filename: using_custom_options_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package using_custom_options_example;

import "custom_options_example.proto";

message UserTable {
    option (custom_options_example.sql_table) = {
        prev_table_name: {value: "old_users"},
        table_bin_data: "\x00\x01\x02\x03\x04\x05\x06\a\b",
        table_name: "users",
        table_tags: {
            fields: [
                {
                    key: "baz",
                    value: {
                        list_value: {
                            values: [
                                {string_value: "qux"},
                                {string_value: "quz"}
                            ]
                        }
                    }
                },
                {key: "foo", value: {string_value: "bar"}},
                {key: "teapot", value: {null_value: NULL_VALUE}}
            ]
        }
    };

    string id = 1 [(custom_options_example.sql_type) = TEXT];
}
```

### Importing from .proto Files

Import generated files into hand-written `.proto` files:

```protobuf
// filename: protobuf_example.proto

syntax = "proto3";

package protobuf_example;

import "example.proto";

message Bug {
    string description = 1;
    example.Priority priority = 2;
}
```

This lets you adopt sroto gradually while downstream users continue using raw `.proto` files.

### Generating Multiple .proto Files

Return an array to generate multiple files from one `.ncl` file:

```nickel
# filename: multiple_file_example.ncl

let sroto = import "sroto.ncl" in

std.array.map (fun x =>
  sroto.File "example_%{x}.proto" "example_%{x}" {
    "%{std.string.uppercase x}" = sroto.Message {
      message = sroto.StringField 1,
    },
  } []
) ["a", "b"]
```

**Generated files:**

```protobuf
// filename: example_a.proto
syntax = "proto3";
package example_a;

message A {
    string message = 1;
}
```

```protobuf
// filename: example_b.proto
syntax = "proto3";
package example_b;

message B {
    string message = 1;
}
```

## Additional Examples

See the `example/` directory for more complete examples:

- `example/example.ncl` - Basic message, enum, and service definitions
- `example/options_example.ncl` - Custom options and well-known types

## Troubleshooting

### "nickel: command not found"

Install the Nickel CLI:
```bash
cargo install nickel-lang-cli
```

### Import errors

Make sure your import path is correct. Nickel resolves imports relative to the importing file:
```nickel
# If sroto.ncl is in the parent directory:
let sroto = import "../sroto.ncl" in
...
```

### Syntax errors

Nickel has strict syntax. Common issues:
- Use `=` for record fields, not `:`
- Use `&` for record merging, not `+` or `+:`
- String interpolation uses `"%{expr}"`, not `"%(expr)s"`

## Implementation Details

The Nickel frontend works by:

1. Parsing `.ncl` files and evaluating them with the `nickel export --format json` command
2. The `sroto.ncl` library constructs records that match the sroto IR JSON schema
3. The JSON IR is then processed identically to Jsonnet output
4. The rest of the pipeline (IR → AST → .proto) is shared between frontends

This design keeps the frontends decoupled and allows for easy addition of new frontends in the future.

## See Also

- [README.md](README.md) - Overview and getting started
- [JSONNET.md](JSONNET.md) - Jsonnet examples and patterns
