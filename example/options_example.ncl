# Example demonstrating custom options in Nickel

let sroto = import "../sroto.ncl" in

# Define custom option types (imported from other proto files)
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

# A simple custom field helper (mimicking my_custom_fields.libsonnet)
let UUIDField = fun number =>
  sroto.StringField number
in

sroto.File "options_example.proto" "example" {
  User = sroto.Message {
    id = UUIDField 1,
    referrer_user_id = UUIDField 2,
  } & {
    options = [{
      type = openapiv2Annotation "schema",
      path = "example",
      value = {
        id = "24508faf-20e3-46ca-8b09-d079b595ef0b",
        referrer_user_id = "27fa4a4e-5650-484f-87f9-bd915889f92b",
      },
    }],
  },

  GetUserRequest = sroto.Message {
    id = sroto.StringField 1 & {
      options = [{
        type = api_field_behavior,
        path = "",
        value = [sroto.EnumValueLiteral "REQUIRED"],
      }],
    },
  },

  UserService = sroto.Service {
    GetUser = sroto.UnaryMethod "GetUserRequest" "User" & {
      options = [{
        type = http_api,
        path = "",
        value = { get = "/users/{id}" },
      }],
    },
  } & {
    options = [{
      type = openapiv2Annotation "tag",
      path = "description",
      value = "UserService is for various operations on users.",
    }],
  },
} & {
  # File-level options can use the shorthand for built-in options
  options = [{
    type = { name = "go_package" },
    path = "",
    value = "github.com/tomlinford/sroto/example/options_example",
  }],
}
