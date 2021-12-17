# Protocol Buffers, evolved

[![Go Reference](https://pkg.go.dev/badge/google.golang.org/protobuf.svg)](https://pkg.go.dev/github.com/tomlinford/sroto)

This project enables generation of `.proto` files in jsonnet. `.proto` files serve as critical schema specifications for a vast variety of data interchange use cases which has created an enormous ecosystem of tools that leverage definitions in `.proto` files. For instance, [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) will generate REST APIs purely from `.proto` files and [protoc-gen-validate](https://github.com/envoyproxy/protoc-gen-validate) will autogenerate validators in Go code from `.proto` files.

However, raw `.proto` files have no functionality that enables code reuse since `.proto` files are effectively data definitions of schemas. While this approach creates simplicity, it hinders its usefulness. [Jsonnet](https://jsonnet.org/) is a data templating language specifically designed to remove boilerplate when the output is pure data.

## Installation
```
$ go install github.com/tomlinford/sroto/cmd/srotoc@latest
```

You will also need to have the [protobuf toolchain installed](https://grpc.io/docs/protoc-installation/). The `srotoc` binary will call `protoc` directly, so `protoc` will need to be available in your `$PATH`. The `srotoc` binary embeds [go-jsonnet](https://github.com/google/go-jsonnet) as well as the `sroto.libsonnet` library file, so there's no need to install a jsonnet toolchain.

## Project status

I consider the project to be feature-complete since all features of `.proto` files are covered.

Using this project should be fine for serious use-cases, although early on I'd recommend checking in any `.proto` files to help verify that changes to those files are what's expected.

## Quick example
(Note: these examples can also be found in the `example` folder)
```jsonnet
// filename: example.jsonnet

local sroto = import "sroto.libsonnet";

sroto.File("example.proto", "example", {
    Priority: sroto.Enum({
        // note the lack of the 0 value here, it'll be auto-generated
        LOW: 1,
        HIGH: 3,
    }) {
        // In jsonnet you can pass in a sort of "keyword argument" by doing
        // object composition. The sroto.Enum call returns an object which is
        // then merged with this object with only the `reserved` field set.
        // This enables "subclasses" of these objects without requiring an
        // exhaustive redefinition of the optional arguments.
        reserved: [2, [4, "max"], "MEDIUM"],
    },
    EchoRequest: sroto.Message({
        message: sroto.StringField(1),
        importance: sroto.Oneof({
            is_important: sroto.BoolField(2),
            priority: sroto.Field("Priority", 3),
        }),
    }),
    EchoResponse: sroto.Message({
        message: sroto.StringField(1),
    }) {
        // All sroto types have a `help` attribute which can be used to insert
        // a comment before the definition in the .proto output, which then
        // gets pulled in by the protobuf compiler.
        help: |||
            EchoResponse echoes back the initial message in the EchoRequest.

            This is used by EchoService.
        |||
    },
    EchoService: sroto.Service({
        // UnaryMethod is just Method with false for (client|server)_streaming
        Echo: sroto.UnaryMethod("EchoRequest", "EchoResponse"),
        StreamEcho: sroto.Method("EchoRequest", "EchoResponse", true, true)
    }),
    // can also define enums with arrays, but need to specify the name. This
    // helps in certain situations like maintaining ordering, although generally
    // defining objects reads more cleanly.
    Quality: sroto.Enum([
        sroto.EnumValue(2) {name: "QUALITY_HIGH"},
        sroto.EnumValue(1) {name: "QUALITY_LOW"},
    ]),
})
```

Running `srotoc --proto_out=. example.jsonnet` will yield the following:
```protobuf
// filename: example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package example;

enum Priority {
    PRIORITY_UNSPECIFIED = 0;
    LOW = 1;
    HIGH = 3;

    reserved 2;
    reserved 4 to max;
    reserved "MEDIUM";
}

enum Quality {
    QUALITY_UNSPECIFIED = 0;
    QUALITY_HIGH = 2;
    QUALITY_LOW = 1;
}

message EchoRequest {
    oneof importance {
        bool is_important = 2;
        Priority priority = 3;
    }
    string message = 1;
}

// EchoResponse echoes back the initial message in the EchoRequest.
//
// This is used by EchoService.
message EchoResponse {
    string message = 1;
}

service EchoService {
    rpc Echo(EchoRequest) returns (EchoResponse);
    rpc StreamEcho(stream EchoRequest) returns (stream EchoResponse);
}
```

Furthermore, it's possible to leverage the `srotoc` command to also generate the relevant code for the language, so the above command could have been:
```sh
srotoc --proto_out=. --python_out=. example.jsonnet
```
And then `example.proto` and `example_pb2.py` would have been created. The `srotoc` command identifies arguments relevant to the `jsonnet -> proto` conversion and omits them from a subprocess call to `protoc`, but also includes any `.proto` files generated from the first step.

## Importing example

Imports can either be done from a `.jsonnet` file or specified raw (ie. from a .proto file directly):

```jsonnet
// filename: import_example.jsonnet

local sroto = import "sroto.libsonnet";
// importing from another sroto file
local example = import "example.jsonnet";

// "importing" from a protobuf file
local Timestamp = {
    name: "Timestamp",
    filename: "google/protobuf/timestamp.proto",
    package: "google.protobuf",
};

sroto.File("import_example.proto", "import_example", {
    LogEntry: sroto.Message({
        message: sroto.StringField(1),
        priority: sroto.Field(example.Priority, 2),
        created_at: sroto.Field(Timestamp, 3),
        // Well-known types (like Timestamp) are pre-defined in sroto.WKT,
        // so the above could be simplified by doing:
        updated_at: sroto.Field(sroto.WKT.Timestamp, 4),
    }),
})
```

This generates the following `.proto` file:
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

This also makes imports in protobufs a bit easier to understand. With raw protobuf files, it's a bit hard to tell which file a particular type is defined in, since the file is imported buf the type is specified using the package. This bundles all the information together on the imported type:
1. What is the name of the type, ie. the enum, message, or custom option (discussed below)?
2. Which file is the type declared in?
3. What is the package of the file that the type is declared in? (in the future, this may become unnecessary to specify since this can be determined with a quick `protoc` invocation)

## Options example

Of course, this doesn't quite show the power of using a higher level language. Suppose we want to add a UUID field to a message but we also want to document that it's a UUID field with OpenAPI on our [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) service and we want to use [protoc-gen-validate](https://github.com/envoyproxy/protoc-gen-validate) to validate that it's a valid UUID. In raw protobuf world, this would look like:

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

This is not composable at all. If we add another UUID field anywhere we'd have to copy-paste all of the options. With sroto we can declare a new `UUIDField` and use it. Likely we'd want to put this into a library file that we can share:
```jsonnet
// filename: my_custom_fields.libsonnet

local sroto = import "sroto.libsonnet";

{
    UUIDField(number):: sroto.StringField(number) {
        // note we're doing `options+:` instead of `options:` -- we don't want to
        // overwrite any existing options (and sroto will check for this)
        options+: [
            {
                // of course, can choose to just inline the "imports"
                type: {
                    name: "openapiv2_field",
                    filename: "protoc-gen-openapiv2/options/annotations.proto",
                    package: "grpc.gateway.protoc_gen_openapiv2.options",
                },
                value: {
                    pattern: "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}",
                    min_length: 36,
                },
            },
            {
                // this is equivalent to doing (validate.rules).string.uuid = true
                type: {
                    name: "rules",
                    filename: "validate/validate.proto",
                    package: "validate",
                },
                path: "string.uuid",
                value: true,
            },
        ],
    },
}
```

Then we can import the library file into where we need to use it: (this example also shows a bunch of other cases where we can set custom options)
```jsonnet
// filename: options_example.jsonnet

local sroto = import "sroto.libsonnet";
local my_custom_fields = import "my_custom_fields.libsonnet";

// "import" the custom options
local openapiv2Annotation(name_suffix) = {
    name: "openapiv2_" + name_suffix,
    filename: "protoc-gen-openapiv2/options/annotations.proto",
    package: "grpc.gateway.protoc_gen_openapiv2.options",
};
local api_field_behavior = {
    name: "field_behavior",
    filename: "google/api/field_behavior.proto",
    package: "google.api",
};
local http_api = {
    name: "http",
    filename: "google/api/annotations.proto",
    package: "google.api",
};

sroto.File("options_example.proto", "example", {
    User: sroto.Message({
        id: my_custom_fields.UUIDField(1),
        referrer_user_id: my_custom_fields.UUIDField(2),
    }) {options+: [{
        type: openapiv2Annotation("schema"),
        path: "example",
        value: std.manifestJsonMinified({
            id: "24508faf-20e3-46ca-8b09-d079b595ef0b",
            referrer_user_id: "27fa4a4e-5650-484f-87f9-bd915889f92b",
        }),
    }]},
    GetUserRequest: sroto.Message({
        id: sroto.StringField(1) {options+: [{
            type: api_field_behavior,
            value: [sroto.EnumValueLiteral("REQUIRED")],
        }]},
    }),
    UserService: sroto.Service({
        GetUser: sroto.UnaryMethod("GetUserRequest", "User") {options+: [{
            type: http_api,
            value: {get: "/users/{id}"},
        }]},
    }) {options+: [{
        type: openapiv2Annotation("tag"),
        path: "description",
        value: "UserService is for various operations on users.",
    }]},
}) {options+: [
    // if the option is a built-in, can just have an object with a single
    // key/value pair, with they key being the name of the option and the
    // value being the option value
    {go_package: "github.com/tomlinford/sroto/example/options_example"}
]}
```

This will generate the following `.proto` file:
```protobuf
// filename: options_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package example;

option go_package = "github.com/tomlinford/sroto/example/options_example";

import "google/api/annotations.proto";
import "google/api/field_behavior.proto";
import "protoc-gen-openapiv2/options/annotations.proto";
import "validate/validate.proto";

message GetUserRequest {
    string id = 1 [
        (google.api.field_behavior) = REQUIRED
    ];
}

message User {
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_schema) = {
        example: "{\"id\":\"24508faf-20e3-46ca-8b09-d079b595ef0b\",\"referrer_user_id\":\"27fa4a4e-5650-484f-87f9-bd915889f92b\"}"
    };

    string id = 1 [
        (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_field) = {
            min_length: 36,
            pattern: "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"
        },
        (validate.rules) = {
            string: {
                uuid: true
            }
        }
    ];
    string referrer_user_id = 2 [
        (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_field) = {
            min_length: 36,
            pattern: "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"
        },
        (validate.rules) = {
            string: {
                uuid: true
            }
        }
    ];
}

service UserService {
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_tag) = {
        description: "UserService is for various operations on users."
    };

    rpc GetUser(GetUserRequest) returns (User) {
        option (google.api.http) = {
            get: "/users/{id}"
        };
    };
}
```

Auto-importing is also taken care of here. The `type` object matches the information specified above in the "Import example" section:
1. What is the name of the option? Inside the `extend` blocks in files that specify custom options there's some `<label>? <type> <name> = <number>;`, and the `name` is what we want to extract here to fill that.
2. Which file is the custom option declared in?
3. What is the package of the file that the custom option is declared in?

Additionally, note how the `.proto` file output has many different formats for the options, whereas with sroto, the options are defined in a consistent manner. I had to reference an [example](https://github.com/grpc-ecosystem/grpc-gateway/blob/master/examples/internal/proto/examplepb/a_bit_of_everything.proto) in the grpc-gateway repo to get a sense as to how these different options had to be specified.

## Custom options example

`sroto` also supports specifying custom options:
```jsonnet
// filename: custom_options_example.jsonnet

local sroto = import "sroto.libsonnet";

sroto.File("custom_options_example.proto", "custom_options_example", {
    SQLTableOptions: sroto.Message({
        table_name: sroto.StringField(1),
    }),
    sql_table: sroto.CustomMessageOption("SQLTableOptions", 6072),
    SQLType: sroto.Enum({
        BIGINT: 1,
        TEXT: 2,
    }),
    sql_type: sroto.CustomFieldOption("SQLType", 6073),
})
```

This results in:
```protobuf
// filename: custom_options_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package custom_options_example;

import "google/protobuf/descriptor.proto";

extend google.protobuf.MessageOptions {
    SQLTableOptions sql_table = 6072;
}

extend google.protobuf.FieldOptions {
    SQLType sql_type = 6073;
}

enum SQLType {
    SQL_TYPE_UNSPECIFIED = 0;
    BIGINT = 1;
    TEXT = 2;
}

message SQLTableOptions {
    string table_name = 1;
}
```

And then we can use the custom options like so:
```jsonnet
// filename: using_custom_options_example.jsonnet

local sroto = import "sroto.libsonnet";
local custom_options_example = import "custom_options_example.jsonnet";

sroto.File("using_custom_options_example.proto", "using_custom_options_example", {
    UserTable: sroto.Message({
        id: sroto.StringField(1) {options+: [{
            // note how we can just use the `sroto` objects directly here:
            type: custom_options_example.sql_type,
            value: custom_options_example.SQLType.TEXT,
        }]},
    }) {options+: [{
        type: custom_options_example.sql_table,
        value: {table_name: "users"},
    }]},
})
```

Which then generates the following protobuf file:
```protobuf
// filename: using_custom_options_example.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package using_custom_options_example;

import "custom_options_example.proto";

message UserTable {
    option (custom_options_example.sql_table) = {
        table_name: "users"
    };

    string id = 1 [
        (custom_options_example.sql_type) = TEXT
    ];
}
```

## Importing from .proto files

This is probably self-evident by now, but since `srotoc` generates `.proto` files directly, you can of course import from the generated `.proto` file into a hand-written `.proto` file:

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

With this interoperability, you can choose to start writing your `.proto` files using sroto, while still enabling downstream users of your `.proto` files to keep writing `.proto` files.

## Generating multiple .proto files

It's also possible to generate multiple `.proto` files from a single `.jsonnet` file. Simply have the jsonnet file result in an array of `sroto.File`s instead of a single `sroto.File`:

```jsonnet
// filename: multiple_file_example.jsonnet

local sroto = import "sroto.libsonnet";

[
    sroto.File("example_%s.proto" % [x], "example_%s" % [x], {
        [std.asciiUpper(x)]: sroto.Message({
            message: sroto.StringField(1),
        })
    }) for x in ["a", "b"]
]
```

This will yield two `.proto` files:
```protobuf
// filename: example_a.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package example_a;

message A {
    string message = 1;
}
```
```protobuf
// filename: example_b.proto

// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package example_b;

message B {
    string message = 1;
}
```

## Project goals

Sroto has the following design goals:
1. Provide a new and intuitive way to write protobuf files that enables composition.
2. Seamlessly fit into existing usage of protobufs.
3. Create a significantly improved experience working with custom options.

At a high level, these goals are achieved by:
1. Leveraging jsonnet to serve as a new end-user interface for writing protobuf files with a shared jsonnet library that exposes an easy to use API. In default usage, each jsonnet file maps directly to a protobuf file.
2. Enabling seamless imports from raw protobuf files into jsonnet files and vice-versa.
3. Provide a highly compatible binary, `srotoc` that invokes `protoc` as a subprocess and can basically be used exactly like `protoc` but also can generate protobuf files from jsonnet files before invoking `protoc`.

This approach of using jsonnet to generate `.proto` files aims to enable the benefits of code-first schemas without the drawbacks. Generally code-first schemas are written in the language of the service used, which has an unintentional side effect of making all other users of the schema second class citizens (unless there's a concerted effort to mitigate this). To illustrate:
* schema-first (eg. gRPC): `schema -> all application code`
* code-first (eg. django-rest-framework): `primary service application code -> schema -> other application code`
* sroto: `data templating language -> schema -> all application code`

With sroto, protobuf files could better serve as the source of truth for your schemas. For instance, gRPC APIs could be defined more succinctly, and protobuf types could be extended to provide metadata used by `grpc-gateway` in a more composable fashion. In the extreme, this approach could also be used for _all_ schemas, including database schemas. Perhaps it would be valuable to define SQL schemas in protobuf files and then have a `protoc-gen-*` command that generates the SQL statements. If done well, such an approach could enable trivial model specification in CRUD apps in a language-agnostic way.

## Other interfaces

Sroto was initially built for jsonnet because it worked the best out of all the languages I was fairly familiar with. However, there's no reason why more interfaces couldn't be supported. Presently, the jsonnet shared library (`sroto.libsonnet`) performs a lightweight translation into an intermediate representation ("IR") serialized into JSON, and the schema of the IR is defined by Go structs in the `sroto_ir` package. (Perhaps this could be defined by protobufs in the future, but simplicity seemed preferable here). The IR is then transformed into a protobuf AST, where it then can print the protobuf files.

Here are the steps and responsibilities of each step:
1. `jsonnet -> sroto IR`: Expose end-user interface, normalize data inputs into IR format. Do name resolution and input validation.
2. `sroto IR -> proto AST`: Identify imported files, insert `*_UNSPECIFIED = 0;` enum values, merge and normalize options and reserved fields and values, and then translate into AST format.
3. `proto AST -> proto file`: Translate the AST into a string with the file contents.

So for instance, a re-implementation using [cuelang](https://cuelang.org/) would only need to replace the first step.
