// Example demonstrating field composition with options at multiple levels
//
// This example shows how to create reusable custom field types by composing
// fields with options. Each layer adds its own options while preserving options
// from previous layers using the options+: syntax.
//
// Key pattern: Use options+: (not options:) to append options rather than
// replace them. This ensures options are accumulated across composition layers.

local sroto = import "sroto.libsonnet";

// Layer 1: Base custom field with validation options
// Creates a string field with configurable min/max length validation.
// Can be extended by callers using the options+: syntax.
local StringFieldWithValidation(number, min_len, max_len) =
  sroto.StringField(number) {
    options+: [{
      type: {
        name: 'rules',
        filename: 'validate/validate.proto',
        package: 'validate',
      },
      path: 'string',
      value: {
        min_len: min_len,
        max_len: max_len,
      },
    }],
  };

// Layer 2: UUID field built on validated string field
// Composes StringFieldWithValidation with fixed length (36 chars) and adds
// UUID format validation. Inherits the min/max length options from Layer 1.
local UUIDField(number) =
  StringFieldWithValidation(number, 36, 36) {
    options+: [{
      type: {
        name: 'rules',
        filename: 'validate/validate.proto',
        package: 'validate',
      },
      path: 'string.uuid',
      value: true,
    }],
  };

// Layer 3: Required UUID field built on UUID field
// Composes UUIDField and adds the REQUIRED field behavior annotation.
// Inherits both the length validation from Layer 1 and UUID validation from Layer 2.
local RequiredUUIDField(number) =
  UUIDField(number) {
    options+: [{
      type: {
        name: 'field_behavior',
        filename: 'google/api/field_behavior.proto',
        package: 'google.api',
      },
      value: [sroto.EnumValueLiteral('REQUIRED')],
    }],
  };

sroto.File('composed_fields_example.proto', 'composed_fields_example', {
  User: sroto.Message({
    // Uses base custom field
    nickname: StringFieldWithValidation(1, 3, 50),
    // Uses layer 2 (composed) custom field
    user_id: UUIDField(2),
    // Uses layer 3 (double composed) custom field
    tenant_id: RequiredUUIDField(3),
  }),
})
