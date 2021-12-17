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
