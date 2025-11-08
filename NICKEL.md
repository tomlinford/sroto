# Nickel Frontend for Sroto

This document describes the Nickel-lang frontend for sroto, an alternative to the Jsonnet frontend.

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

Use Nickel's record merging (`&`) to add options to any definition:

```nickel
MyMessage = sroto.Message {
  id = sroto.StringField 1,
} & {
  options = [{
    type = { name = "deprecated" },
    path = "",
    value = true,
  }],
}
```

For field options:
```nickel
{
  email = sroto.StringField 1 & {
    options = [{
      type = {
        name = "field_behavior",
        package = "google.api",
        filename = "google/api/field_behavior.proto",
      },
      path = "",
      value = [sroto.EnumValueLiteral "REQUIRED"],
    }],
  },
}
```

### Reserved Fields

Add reserved field numbers and names:

```nickel
MyEnum = sroto.Enum {
  LOW = 1,
  HIGH = 3,
} & {
  reserved_ranges = [
    { start = 2, end = 2 },
    { start = 10, end = 20 },
    { start = 100, end = null },  # null means "max"
  ],
  reserved_names = ["DEPRECATED_VALUE"],
}
```

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
    field = sroto.StringField 1 & {
      options = [{
        type = { name = "my_option", package = "myapp" },
        path = "",
        value = "custom value",
      }],
    },
  },
}
```

### Help Text / Comments

Add documentation comments using the `help` field:

```nickel
MyMessage = sroto.Message {
  id = sroto.Int64Field 1,
} & {
  help = m%"
    MyMessage represents a user in the system.

    It contains the unique identifier and other metadata.
  "%,
}
```

Nickel's multiline strings (`m%"..."%`) are perfect for documentation.

## Comparison with Jsonnet

### Similarities

- Both frontends generate the same IR format
- Both produce identical `.proto` output
- API is nearly identical between the two

### Differences

| Feature | Jsonnet | Nickel |
|---------|---------|--------|
| String interpolation | `"%(name)s"` | `"%{name}"` |
| Multiline strings | `|||...|||` | `m%"..."%` |
| Record merging | `+:` | `&` |
| Imports | `import "file.libsonnet"` | `import "file.ncl"` |
| Type system | None (dynamic only) | Optional static + contracts |
| Standard library | `std.*` | `%record/*`, `%array/*`, etc. |

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

## Examples

See the `example/` directory for complete examples:

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
