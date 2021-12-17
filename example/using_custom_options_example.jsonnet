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
