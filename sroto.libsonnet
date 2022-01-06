local isSrotoType(v, sroto_type) =
    std.isObject(v) && std.objectHasAll(v, "sroto_type")
    && v.sroto_type == sroto_type;
local isEnum(v) = isSrotoType(v, "enum");
local isEnumValue(v) = isSrotoType(v, "enum_value");
local isField(v) = isSrotoType(v, "field");
local isFile(v) = isSrotoType(v, "file");
local isMessage(v) = isSrotoType(v, "message");
local isOneof(v) = isSrotoType(v, "oneof");
local isMethod(v) = isSrotoType(v, "method");
local isService(v) = isSrotoType(v, "service");
local isCustomOption(v) = isSrotoType(v, "custom_option");

local _SENTINEL_OPTION =  {__sentinel__: true};
local Decl(sroto_type) = {
    sroto_type:: sroto_type,
    help: "",
    options: [_SENTINEL_OPTION],
};

local makeWKT(name, filename_root) = {
    name: name,
    package: "google.protobuf",
    filename: "google/protobuf/%s.proto" % [filename_root],
};

local normalizeType(type) =
    if std.isString(type) then {name: type} else type;

local transformObjectValues(v, func) = (
    assert std.isObject(v);
    local fields = [  // array of tuple of (key, value, visible)
        [k, func(k, v[k]), std.objectHas(v, k)]
        for k in std.objectFieldsAll(v)
        if !std.isFunction(v[k])
    ];
    local hiddenFields = [[x[0], x[1]] for x in fields if !x[2]];
    local foldFunc(x, obj) = obj {[x[0]]:: x[1]};
    v + std.foldr(foldFunc, hiddenFields, {[x[0]]: x[1] for x in fields if x[2]})
);

local recurseTransform(v, func, currPackage) = (
    if (
        // No need to perform transforms on objects outside of the
        // current package.
        std.isObject(v)
        && std.objectHas(v, "package")
        && v.package != currPackage
    ) then v
    else
        local x = func(v);
        if std.isObject(x) then
            transformObjectValues(
                x, function(a, b) recurseTransform(b, func, currPackage),
            )
        else if std.isArray(x) then
            [recurseTransform(a, func, currPackage) for a in x]
        else x
);

local transformReservedArr(reserved_arr) = (
    local reserved_ranges = [
        {start: r, end: r}
        for r in reserved_arr
        if std.isNumber(r)
    ] + [
        {start: r[0], end: r[1]}
        for r in reserved_arr
        if std.isArray(r) && std.isNumber(r[1])
    ] + [
        {start: r[0], end: null}
        for r in reserved_arr
        if std.isArray(r) && r[1] == "max"
    ];
    local reserved_names = [
        r for r in reserved_arr if std.isString(r)
    ];
    assert std.length(reserved_arr) == (
        std.length(reserved_ranges) + std.length(reserved_names)
    );
    {
        reserved_ranges: reserved_ranges,
        reserved_names: reserved_names,
    }
);

local addNames(x) =
    if isFile(x) || isEnum(x) || isMessage(x) || isOneof(x) || isService(x) then
        transformObjectValues(x, function(k, v)
            if std.isObject(v) && std.objectHasAll(v, "sroto_type") then
                {name: k} + v
            else v
        )
    else x;

{
    File(name, package, file):: (
        local addPackages(x) = 
            if (
                (isEnum(x) || isMessage(x) || isService(x) || isCustomOption(x))
                && !std.objectHasAll(x, "package")
            ) then 
                x {package: package, filename: name}
            else x;
        local normalizeOptionValue(x) =
            if isEnumValue(x) then $.EnumValueLiteral(x.name)
            else if std.isObject(x) then
                transformObjectValues(
                    x, function(a, b) normalizeOptionValue(b)
                )
            else if std.isArray(x) then
                [normalizeOptionValue(a) for a in x]
            else x;
        local normalizeOption(x) =
            if std.length(x) == 1 then
                {
                    type: {name: std.objectFields(x)[0]},
                    value: normalizeOptionValue(std.objectValues(x)[0]),
                }
            else x {
                type: normalizeType(x.type),
                value: normalizeOptionValue(x.value),
            };
        local cleanOptions(x) =
            if std.isObject(x) && std.objectHas(x, "options") then
                if std.find(_SENTINEL_OPTION, x.options) == [0] then
                    transformObjectValues(x, function(k, v)
                        if k == "options" then [
                            normalizeOption(o)
                            for o in std.slice(v, 1, std.length(v), 1)
                        ] else v
                    )
                else error |||
                    `options` has been overwritten in '%s'.
                    
                    Be sure to write: `options+: ...`. If you'd like to overwrite a
                    particular option, simply append a new value for that option.

                    `options` value: %s
                ||| % [if std.objectHas(x, "name") then x.name else x.filename, x.options]
            else x;

        // add package attribute to top-level messages
        // set names for all named types
        // check and clean options array
        local f = std.foldl(
            function(curr, func) recurseTransform(curr, func, package),
            [addPackages, addNames, cleanOptions],
            file {sroto_type:: "file"},
        );
        f {
            name: name,
            package: package,
            options: [_SENTINEL_OPTION],
            manifestSrotoIR():: local f = self; cleanOptions({
                name: name,
                package: package,
                enums: [e.manifestSrotoIR() for e in std.objectValues(f) if isEnum(e)],
                messages: [m.manifestSrotoIR() for m in std.objectValues(f) if isMessage(m)],
                services: [s.manifestSrotoIR() for s in std.objectValues(f) if isService(s)],
                custom_options: [o.manifestSrotoIR() for o in std.objectValues(f) if isCustomOption(o)],
                options: f.options,
            }),
        }
    ),
    Enum(values):: (
        local enum = Decl("enum") {
            reserved: [],
            manifestSrotoIR():: local e = self; {
                name: e.name,
                help: e.help,
                values: 
                    if std.isObject(values) then
                        std.sort([
                            e[n] for n in std.objectFields(values)
                        ], function(x) x.number)
                    else e.values,
                options: e.options,
            } + transformReservedArr(e.reserved),
        };
        if std.isObject(values) then addNames({
            [n]: (
                if isEnumValue(values[n]) then values[n]
                else $.EnumValue(values[n])
            ) for n in std.objectFields(values)
        } + enum)
        else {values: values} + enum
    ),
    EnumValue(number):: Decl("enum_value") {
        number: number,
    },
    Message(decls):: Decl("message") + decls {
        reserved: [],
        manifestSrotoIR():: local m = self; {
            name: m.name,
            help: m.help,
            enums: [
                m[n].manifestSrotoIR()
                for n in std.objectFields(decls)
                if isEnum(m[n])
            ],
            messages: [
                m[n].manifestSrotoIR()
                for n in std.objectFields(decls)
                if isMessage(m[n])
            ],
            fields: std.sort([
                m[n].manifestSrotoIR()
                for n in std.objectFields(decls)
                if isField(m[n])
            ], function(x) x.number),
            oneofs: [
                m[n].manifestSrotoIR()
                for n in std.objectFields(decls)
                if isOneof(m[n])
            ],
            options: m.options,
        } + transformReservedArr(m.reserved),
    },
    Oneof(fields):: Decl("oneof") + fields {
        manifestSrotoIR():: local o = self; {
            name: o.name,
            help: o.help,
            fields: [o[n].manifestSrotoIR() for n in std.objectFields(fields)],
            options: o.options,
        },
    },
    local BaseField(number) = Decl("field") {
        number: number,
        repeated: false,
        optional: false,

        // hook to append options after field generation
        getOptions():: self.options,
        manifestSrotoIR():: local f = self; assert !f.repeated || !f.optional; f {
            repeated:: f.repeated,
            optional:: f.optional,
            label: (
                if f.repeated then "repeated"
                else if f.optional then "optional"
                else ""
            ),
            options: f.getOptions(),
        },
    },
    Field(type, number):: BaseField(number) {type: normalizeType(type)},
    // LazilyTypedField can pull the type from either:
    //  1. The `type` attribute
    //  2. The `getType` method
    LazilyTypedField(number):: BaseField(number) {
        getType():: self.type,
        manifestSrotoIR():: local f = self; super.manifestSrotoIR() {
            type: normalizeType(f.getType()),
        },
    },

    // Built-in types.
    DoubleField(number):: self.Field("double", number),
    FloatField(number):: self.Field("float", number),
    Int64Field(number):: self.Field("int64", number),
    Uint64Field(number):: self.Field("uint64", number),
    Int32Field(number):: self.Field("int32", number),
    Fixed64Field(number):: self.Field("fixed64", number),
    Fixed32Field(number):: self.Field("fixed32", number),
    BoolField(number):: self.Field("bool", number),
    StringField(number):: self.Field("string", number),
    BytesField(number):: self.Field("bytes", number),
    Uint32Field(number):: self.Field("uint32", number),
    Sfixed32Field(number):: self.Field("sfixed32", number),
    Sfixed64Field(number):: self.Field("sfixed64", number),
    Sint32Field(number):: self.Field("sint32", number),
    Sint64Field(number):: self.Field("sint64", number),

    Service(methods):: Decl("service") + methods {
        manifestSrotoIR():: local s = self; {
            name: s.name,
            help: s.help,
            methods: [s[n] for n in std.objectFields(methods)],
            options: s.options,
        },
    },
    Method(input_type, output_type, client_streaming, server_streaming):: Decl("method") {
        input_type: normalizeType(input_type),
        output_type: normalizeType(output_type),
        client_streaming: client_streaming,
        server_streaming: server_streaming,
    },
    UnaryMethod(input_type, output_type)::
        self.Method(input_type, output_type, false, false),

    local CustomOption(type, number, option_type) = {
        sroto_type:: "custom_option",
        help: "",
        number: number,
        type: normalizeType(type),
        option_type: option_type,
        repeated: false,
        manifestSrotoIR():: local o = self; o {
            repeated:: o.repeated,
            label: if o.repeated then "repeated" else "",
        },
    },
    CustomFileOption(type, number):: CustomOption(type, number, "file_option"),
    CustomEnumOption(type, number):: CustomOption(type, number, "enum_option"),
    CustomEnumValueOption(type, number):: CustomOption(type, number, "enum_value_option"),
    CustomMessageOption(type, number):: CustomOption(type, number, "message_option"),
    CustomFieldOption(type, number):: CustomOption(type, number, "field_option"),
    CustomOneofOption(type, number):: CustomOption(type, number, "oneof_option"),
    CustomServiceOption(type, number):: CustomOption(type, number, "service_option"),
    CustomMethodOption(type, number):: CustomOption(type, number, "method_option"),

    // BytesLiteral and EnumValueLiteral use a bit of a hack.
    // Neither can really be represented in pure JSON that directly maps to the
    // format read by protoc. Bytes can be represented as an array of numbers
    // in JSON which is then rendered as a string with a hex escape sequence.
    // Enum value literals are rendered in protobuf as the enum value name,
    // without quotes.
    // So to do this, we make an object with "reserved" as a key, which should
    // be an impossible field name in messages (as "reserved" is a keyword).
    BytesLiteral(value)::
        if std.isString(value) then value
        else {
            reserved: "__bytes_literal__",
            value: value,
        },
    EnumValueLiteral(name):: {
        reserved: "__enum_value_literal__",
        name: name,
    },

    // MapLiteral takes an object and turns it into a protobuf map.
    // If the key type is not a string, creating the map will have to be done
    // by the client.
    MapLiteral(map):: [
        {key: k, value: map[k]} for k in std.objectFields(map)
    ],

    // Well-known types
    WKT:: {
        local type(name, filename_root) = {
            name: name,
            package: "google.protobuf",
            filename: "google/protobuf/%s.proto" % [filename_root],
        },
        local enum(name, filename_root, enum) =
            type(name, filename_root) + enum,
        Any:: type("Any", "any"),
        Api:: type("Api", "api"),
        BoolValue:: type("BoolValue", "wrappers"),
        BytesValue:: type("BytesValue", "wrappers"),
        DoubleValue:: type("DoubleValue", "wrappers"),
        Duration:: type("Duration", "duration"),
        Empty:: type("Empty", "empty"),
        Enum:: type("Enum", "type"),
        EnumValue:: type("EnumValue", "type"),
        Field:: type("Field", "type") {
            Cardinality:: enum("Field.Cardinality", "type", {
                CARDINALITY_UNKNOWN::
                    $.EnumValueLiteral("CARDINALITY_UNKNOWN"),
                CARDINALITY_OPTIONAL::
                    $.EnumValueLiteral("CARDINALITY_OPTIONAL"),
                CARDINALITY_REQUIRED::
                    $.EnumValueLiteral("CARDINALITY_REQUIRED"),
                CARDINALITY_REPEATED::
                    $.EnumValueLiteral("CARDINALITY_REPEATED"),
            }),
            Kind:: enum("Field.Kind", "type", {
                TYPE_UNKNOWN:: $.EnumValueLiteral("TYPE_UNKNOWN"),
                TYPE_DOUBLE:: $.EnumValueLiteral("TYPE_DOUBLE"),
                TYPE_FLOAT:: $.EnumValueLiteral("TYPE_FLOAT"),
                TYPE_INT64:: $.EnumValueLiteral("TYPE_INT64"),
                TYPE_UINT64:: $.EnumValueLiteral("TYPE_UINT64"),
                TYPE_INT32:: $.EnumValueLiteral("TYPE_INT32"),
                TYPE_FIXED64:: $.EnumValueLiteral("TYPE_FIXED64"),
                TYPE_FIXED32:: $.EnumValueLiteral("TYPE_FIXED32"),
                TYPE_BOOL:: $.EnumValueLiteral("TYPE_BOOL"),
                TYPE_STRING:: $.EnumValueLiteral("TYPE_STRING"),
                TYPE_GROUP:: $.EnumValueLiteral("TYPE_GROUP"),
                TYPE_MESSAGE:: $.EnumValueLiteral("TYPE_MESSAGE"),
                TYPE_BYTES:: $.EnumValueLiteral("TYPE_BYTES"),
                TYPE_UINT32:: $.EnumValueLiteral("TYPE_UINT32"),
                TYPE_ENUM:: $.EnumValueLiteral("TYPE_ENUM"),
                TYPE_SFIXED32:: $.EnumValueLiteral("TYPE_SFIXED32"),
                TYPE_SFIXED64:: $.EnumValueLiteral("TYPE_SFIXED64"),
                TYPE_SINT32:: $.EnumValueLiteral("TYPE_SINT32"),
                TYPE_SINT64:: $.EnumValueLiteral("TYPE_SINT64"),
            }),
        },
        FieldMask:: type("FieldMask", "field_mask"),
        FloatValue:: type("FloatValue", "wrappers"),
        Int32Value:: type("Int32Value", "wrappers"),
        Int64Value:: type("Int64Value", "wrappers"),
        ListValue:: type("ListValue", "struct"),
        Method:: type("Method", "api"),
        Mixin:: type("Mixin", "api"),
        NullValue:: enum("NullValue", "struct", {
            NULL_VALUE:: $.EnumValueLiteral("NULL_VALUE"),
        }),
        Option:: type("Option", "type"),
        SourceContext:: type("SourceContext", "source_context"),
        StringValue:: type("StringValue", "wrappers"),
        Struct:: type("Struct", "struct"),
        Syntax:: enum("Syntax", "type", {
            SYNTAX_PROTO2:: $.EnumValueLiteral("SYNTAX_PROTO2"),
            SYNTAX_PROTO3:: $.EnumValueLiteral("SYNTAX_PROTO3"),
        }),
        Timestamp:: type("Timestamp", "timestamp"),
        Type:: type("Type", "type"),
        UInt32Value:: type("UInt32Value", "wrappers"),
        UInt64Value:: type("UInt64Value", "wrappers"),
        Value:: type("Value", "struct"),

        local simpleLiteral(value) =
            if value == null then null else {value: value},
        BoolValueLiteral(value):: simpleLiteral(value),
        BytesValueLiteral(value)::
            if value == null then null else {value: $.BytesLiteral(value)},
        DoubleValueLiteral(value):: simpleLiteral(value),
        FloatValueLiteral(value):: simpleLiteral(value),
        Int32ValueLiteral(value):: simpleLiteral(value),
        Int64ValueLiteral(value):: simpleLiteral(value),
        StringValueLiteral(value):: simpleLiteral(value),
        UInt32ValueLiteral(value):: simpleLiteral(value),
        UInt64ValueLiteral(value):: simpleLiteral(value),

        ListValueLiteral(values)::
            if values == null then null else {values: [
                $.WKT.ValueLiteral(v) for v in values
            ]},
        StructLiteral(value)::
            if value == null then null else {fields: $.MapLiteral({
                [k]: $.WKT.ValueLiteral(value[k])
                for k in std.objectFields(value)
            })},
        ValueLiteral(value)::
            if value == null then {null_value: $.WKT.NullValue.NULL_VALUE}
            else if std.isNumber(value) then {number_value: value}
            else if std.isString(value) then {string_value: value}
            else if std.isBoolean(value) then {bool_value: value}
            else if std.isObject(value) then {
                struct_value: $.WKT.StructLiteral(value),
            }
            else if std.isArray(value) then {
                list_value: $.WKT.ListValueLiteral(value)
            }
            else error "invalid type",
    },
}
