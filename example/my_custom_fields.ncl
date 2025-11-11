let sroto = import "sroto.ncl" in

{
  UUIDField = fun number => sroto.StringField number & {
    # note we're doing merging with `&` to add options -- we don't want to
    # overwrite any existing options (and sroto will check for this)
    options = [
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
  },
}
