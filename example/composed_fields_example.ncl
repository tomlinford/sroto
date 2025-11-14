# Example demonstrating field composition with options at multiple levels
#
# This example shows how to create reusable custom field types by composing
# fields with options. Each layer adds its own options while preserving options
# from previous layers using the @ (array concatenation) operator.
#
# Key pattern: Each composed function accepts an 'opts' parameter that allows
# callers to add additional options, which are concatenated with the function's
# own options using the @ operator.

let sroto = import "sroto.ncl" in

# Layer 1: Base custom field with validation options
# Creates a string field with configurable min/max length validation.
# The 'opts' parameter allows callers to add additional options beyond
# the length validation provided by this function.
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
# Composes StringFieldWithValidation with fixed length (36 chars) and adds
# UUID format validation. Inherits the min/max length options from Layer 1.
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
# Composes UUIDField and adds the REQUIRED field behavior annotation.
# Inherits both the length validation from Layer 1 and UUID validation from Layer 2.
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
