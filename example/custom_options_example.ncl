let sroto = import "sroto.ncl" in

sroto.File "custom_options_example.proto" "custom_options_example" {
  SQLTableOptions = sroto.Message {
    table_name = sroto.StringField 1 [],
    table_tags = sroto.Field sroto.WKT.Struct 2 [],
    table_bin_data = sroto.BytesField 3 [],
    # Obviously using StringValues doesn't really make sense for custom
    # options, but the example is here for illustrative purposes.
    prev_table_name = sroto.Field sroto.WKT.StringValue 4 [],
    next_table_name = sroto.Field sroto.WKT.StringValue 5 [],
  } [],
  sql_table = sroto.CustomMessageOption "SQLTableOptions" 6072,
  SQLType = sroto.Enum {
    BIGINT = 1,
    TEXT = 2,
  } [],
  sql_type = sroto.CustomFieldOption "SQLType" 6073,
} []
