package sroto_ir

import (
	"reflect"
	"sort"
	"strings"

	"github.com/pascaldekloe/name"
	"github.com/tomlinford/sroto/proto_ast"
)

type Type struct {
	// One of:
	//  1. Base type (eg. int64, bytes, etc.)
	//  2. Locally defined type (eg. an enum declared in message scope or same file)
	//  3. Name of imported message or extension (which is the name of the field)
	Name string `json:"name"`

	// Optional fields -- only if type is imported
	Filename string `json:"filename"`
	Package  string `json:"package"`
}

func (t *Type) fullName() string {
	if t.Package == "" {
		return t.Name
	}
	return t.Package + "." + t.Name
}

type Option struct {
	Type  Type        `json:"type"`
	Path  string      `json:"path"`
	Value interface{} `json:"value"`
}

type ReservedRange struct {
	Start int  `json:"start"` // inclusive
	End   *int `json:"end"`   // inclusive, nil means max
}

type File struct {
	Name          string         `json:"name"`
	Package       string         `json:"package"`
	Enums         []Enum         `json:"enums"`
	Messages      []Message      `json:"messages"`
	Services      []Service      `json:"services"`
	CustomOptions []CustomOption `json:"custom_options"`
	Options       []Option       `json:"options"`
}

type Enum struct {
	Name           string          `json:"name"`
	Help           string          `json:"help"`
	Values         []EnumValue     `json:"values"`
	Options        []Option        `json:"options"`
	ReservedRanges []ReservedRange `json:"reserved_ranges"`
	ReservedNames  []string        `json:"reserved_names"`
}

func (e *Enum) toDeclaration() *proto_ast.Declaration {
	zeroValueFound := false
	for _, v := range e.Values {
		if v.Number == 0 {
			zeroValueFound = true
			break
		}
	}
	if !zeroValueFound {
		e.Values = append([]EnumValue{{
			Name:   strings.ToUpper(name.SnakeCase(e.Name + "Unspecified")),
			Number: 0,
		}}, e.Values...)
	}
	enumValueDecls := make([]proto_ast.Declaration, len(e.Values))
	for i, value := range e.Values {
		enumValueDecls[i] = *value.toDeclaration()
	}
	return &proto_ast.Declaration{
		Name:           e.Name,
		Help:           e.Help,
		Type:           proto_ast.Enum,
		Declarations:   enumValueDecls,
		Options:        mergeOptions(e.Options),
		ReservedRanges: mergeReservedRanges(e.ReservedRanges, proto_ast.Enum),
		ReservedNames:  mergeReservedNames(e.ReservedNames),
	}
}

type EnumValue struct {
	Name    string   `json:"name"`
	Help    string   `json:"help"`
	Number  int      `json:"number"`
	Options []Option `json:"options"`
}

func (v *EnumValue) toDeclaration() *proto_ast.Declaration {
	return &proto_ast.Declaration{
		Name:    v.Name,
		Help:    v.Help,
		Type:    proto_ast.EnumValue,
		Number:  v.Number,
		Options: mergeOptions(v.Options),
	}
}

type Message struct {
	Name           string          `json:"name"`
	Help           string          `json:"help"`
	Enums          []Enum          `json:"enums"`
	Messages       []Message       `json:"messages"`
	Oneofs         []Oneof         `json:"oneofs"`
	Fields         []Field         `json:"fields"`
	Options        []Option        `json:"options"`
	ReservedRanges []ReservedRange `json:"reserved_ranges"`
	ReservedNames  []string        `json:"reserved_names"`
}

func (m *Message) toDeclaration() *proto_ast.Declaration {
	enumDecls := make([]proto_ast.Declaration, len(m.Enums))
	for i, enum := range m.Enums {
		enumDecls[i] = *enum.toDeclaration()
	}
	messageDecls := make([]proto_ast.Declaration, len(m.Messages))
	for i, message := range m.Messages {
		messageDecls[i] = *message.toDeclaration()
	}
	oneofDecls := make([]proto_ast.Declaration, len(m.Oneofs))
	for i, oneof := range m.Oneofs {
		oneofDecls[i] = *oneof.toDeclaration()
	}
	fieldDecls := make([]proto_ast.Declaration, len(m.Fields))
	for i, field := range m.Fields {
		fieldDecls[i] = *field.toDeclaration()
	}
	decls := enumDecls
	decls = append(decls, messageDecls...)
	decls = append(decls, oneofDecls...)
	decls = append(decls, fieldDecls...)
	return &proto_ast.Declaration{
		Name:           m.Name,
		Help:           m.Help,
		Type:           proto_ast.Message,
		Declarations:   decls,
		Options:        mergeOptions(m.Options),
		ReservedRanges: mergeReservedRanges(m.ReservedRanges, proto_ast.Message),
		ReservedNames:  mergeReservedNames(m.ReservedNames),
	}
}

type Field struct {
	Name    string   `json:"name"`
	Help    string   `json:"help"`
	Number  int      `json:"number"`
	Type    Type     `json:"type"`
	Label   string   `json:"label"`
	Options []Option `json:"options"`
}

func (f *Field) toDeclaration() *proto_ast.Declaration {
	return &proto_ast.Declaration{
		Name:    f.Name,
		Help:    f.Help,
		Type:    proto_ast.Field,
		Number:  f.Number,
		Options: mergeOptions(f.Options),
		FieldDetails: &proto_ast.FieldDetails{
			Type:  f.Type.fullName(),
			Label: f.Label,
		},
	}
}

type Oneof struct {
	Name    string   `json:"name"`
	Help    string   `json:"help"`
	Fields  []Field  `json:"fields"`
	Options []Option `json:"options"`
}

func (o *Oneof) toDeclaration() *proto_ast.Declaration {
	fieldDecls := make([]proto_ast.Declaration, len(o.Fields))
	for i, field := range o.Fields {
		fieldDecls[i] = *field.toDeclaration()
	}
	return &proto_ast.Declaration{
		Name:         o.Name,
		Help:         o.Help,
		Type:         proto_ast.Oneof,
		Declarations: fieldDecls,
		Options:      mergeOptions(o.Options),
	}
}

type Service struct {
	Name    string   `json:"name"`
	Help    string   `json:"help"`
	Methods []Method `json:"methods"`
	Options []Option `json:"options"`
}

func (s *Service) toDeclaration() *proto_ast.Declaration {
	methodDecls := make([]proto_ast.Declaration, len(s.Methods))
	for i, method := range s.Methods {
		methodDecls[i] = *method.toDeclaration()
	}
	return &proto_ast.Declaration{
		Name:         s.Name,
		Help:         s.Help,
		Type:         proto_ast.Service,
		Declarations: methodDecls,
		Options:      mergeOptions(s.Options),
	}
}

type Method struct {
	Name            string   `json:"name"`
	Help            string   `json:"help"`
	InputType       Type     `json:"input_type"`
	OutputType      Type     `json:"output_type"`
	ClientStreaming bool     `json:"client_streaming"`
	ServerStreaming bool     `json:"server_streaming"`
	Options         []Option `json:"options"`
}

func (m *Method) toDeclaration() *proto_ast.Declaration {
	return &proto_ast.Declaration{
		Name:    m.Name,
		Help:    m.Help,
		Type:    proto_ast.Method,
		Options: mergeOptions(m.Options),
		MethodDetails: &proto_ast.MethodDetails{
			InputType:       m.InputType.fullName(),
			OutputType:      m.OutputType.fullName(),
			ClientStreaming: m.ClientStreaming,
			ServerStreaming: m.ServerStreaming,
		},
	}
}

//go:generate enumer -type=OptionType -json -transform=snake
type OptionType int

const (
	FileOption OptionType = iota + 1
	MessageOption
	FieldOption
	OneofOption
	EnumOption
	EnumValueOption
	ServiceOption
	MethodOption
)

type CustomOption struct {
	Name       string     `json:"name"`
	Help       string     `json:"help"`
	Number     int        `json:"number"`
	Type       Type       `json:"type"`
	OptionType OptionType `json:"option_type"`
	Label      string     `json:"label"`
}

var extendFullNameMap = map[OptionType]string{
	FileOption:      "google.protobuf.FileOptions",
	MessageOption:   "google.protobuf.MessageOptions",
	FieldOption:     "google.protobuf.FieldOptions",
	OneofOption:     "google.protobuf.OneofOptions",
	EnumOption:      "google.protobuf.EnumOptions",
	EnumValueOption: "google.protobuf.EnumValueOptions",
	ServiceOption:   "google.protobuf.ServiceOptions",
	MethodOption:    "google.protobuf.MethodOptions",
}

func (o *CustomOption) toDeclaration() *proto_ast.Declaration {
	extendFullName := extendFullNameMap[o.OptionType]
	return &proto_ast.Declaration{
		Name: extendFullName,
		Help: "",
		Type: proto_ast.Extension,
		Declarations: []proto_ast.Declaration{{
			Name:   o.Name,
			Help:   o.Help,
			Type:   proto_ast.Field,
			Number: o.Number,
			FieldDetails: &proto_ast.FieldDetails{
				Type:  o.Type.fullName(),
				Label: o.Label,
			},
		}},
	}
}

func (f *File) ToAST() *proto_ast.File {
	declarations := []proto_ast.Declaration{}
	for _, customOption := range f.CustomOptions {
		declarations = append(declarations, *customOption.toDeclaration())
	}
	for _, enum := range f.Enums {
		declarations = append(declarations, *enum.toDeclaration())
	}
	for _, message := range f.Messages {
		declarations = append(declarations, *message.toDeclaration())
	}
	for _, service := range f.Services {
		declarations = append(declarations, *service.toDeclaration())
	}
	astFile := &proto_ast.File{
		Name:         f.Name,
		Package:      f.Package,
		Syntax:       "proto3",
		Imports:      f.imports(),
		Declarations: declarations,
		Options:      mergeOptions(f.Options),
	}
	return astFile
}

func (f *File) imports() []string {
	m := make(map[string]struct{})
	visit(reflect.ValueOf(*f), func(v interface{}) {
		if typ, ok := v.(Type); ok && typ.Filename != "" && typ.Filename != f.Name {
			m[typ.Filename] = struct{}{}
		} else if _, ok := v.(CustomOption); ok {
			m["google/protobuf/descriptor.proto"] = struct{}{}
		}
	})
	imports := make([]string, 0, len(m))
	for k := range m {
		imports = append(imports, k)
	}
	sort.Strings(imports)
	return imports
}

func visit(v reflect.Value, f func(interface{})) {
	f(v.Interface())
	switch v.Type().Kind() {
	case reflect.Struct:
		for i := 0; i < v.NumField(); i++ {
			visit(v.Field(i), f)
		}
	case reflect.Slice:
		for i := 0; i < v.Len(); i++ {
			visit(v.Index(i), f)
		}
	}
}

// Fold options preferring the ones that appear later.
// Ex: [{Type: "foo", Value: {"bar": 1, "baz": 2}}, {Type: "foo", Value: {"bar": 3}}]
//   becomes: {Type: "foo", Value: {"bar": 3, "baz": 2}}
// Note this only merges options where the top level value is a message
// literal. If the latter value is not a message literal, the latter value
// takes precedence. This also applies to repeated options, as repeated options
// are represented as arrays.
func mergeOptions(options []Option) []proto_ast.Option {
	pathsExpanded := make([]Option, len(options))
	for i, option := range options {
		pathsExpanded[i] = Option{
			Type: option.Type,
			Value: normalizeToProtoAST(
				expandPath(option.Path, option.Value),
			),
		}
	}

	optionMap := map[Type]interface{}{}
	for _, option := range pathsExpanded {
		value := option.Value
		if right, ok := option.Value.(map[string]interface{}); ok {
			if left, ok := optionMap[option.Type].(map[string]interface{}); ok {
				value = mergeMessageLiterals(left, right)
			}
		}
		optionMap[option.Type] = value
	}
	fullNameToType := map[string]Type{}
	for _, option := range options {
		fullNameToType[option.Type.fullName()] = option.Type
	}
	sortedFullNames := make([]string, 0, len(optionMap))
	for typ := range optionMap {
		sortedFullNames = append(sortedFullNames, typ.fullName())
	}
	sort.Strings(sortedFullNames)

	result := make([]proto_ast.Option, 0, len(sortedFullNames))
	for _, fullName := range sortedFullNames {
		option := proto_ast.Option{
			Name:  fullName,
			Value: optionMap[fullNameToType[fullName]],
		}
		if s, ok := option.Value.([]interface{}); ok {
			// expand out top level arrays -- it means the option itself
			// was repeated.
			for _, v := range s {
				option.Value = v
				result = append(result, option)
			}
		} else {
			result = append(result, option)
		}
	}
	return result
}

// ("foo.bar", 1) -> {"foo": {"bar": 1}}
func expandPath(path string, value interface{}) interface{} {
	if path == "" {
		return value
	}
	items := strings.Split(path, ".")
	for i := len(items) - 1; i >= 0; i-- {
		value = map[string]interface{}{items[i]: value}
	}
	return value
}

// bytes literals will come in the form:
// {"reserved": "__bytes_literal__", "value": [...]}
// enum value literals will come in the form:
// {"reserved": "__enum_value_literal__", "name": "{name}"}
// some objects or arrays may have nil values, those will be removed
func normalizeToProtoAST(value interface{}) interface{} {
	if m, ok := value.(map[string]interface{}); ok {
		if m["reserved"] == "__enum_value_literal__" {
			return proto_ast.EnumValueLiteral(m["name"].(string))
		}
		if m["reserved"] == "__bytes_literal__" {
			arr := m["value"].([]interface{})
			bytes := make([]byte, len(arr))
			for i, v := range arr {
				fv := v.(float64)
				bytes[i] = byte(fv)
				if fv != float64(bytes[i]) {
					panic("json bytes must be an array of numbers in the 0 to 255 range")
				}
			}
			return bytes
		}
		newValue := map[string]interface{}{}
		for k, v := range m {
			if v != nil {
				newValue[k] = normalizeToProtoAST(v)
			}
		}
		return newValue
	}
	if s, ok := value.([]interface{}); ok {
		newValue := make([]interface{}, len(s))
		for i, v := range s {
			if v != nil {
				newValue[i] = normalizeToProtoAST(v)
			}
		}
		return newValue
	}
	return value
}

func mergeMessageLiterals(left, right map[string]interface{}) map[string]interface{} {
	result := map[string]interface{}{}
	for k, v := range left {
		if l, ok := v.(map[string]interface{}); ok {
			if r, ok := right[k]; ok {
				if r, ok := r.(map[string]interface{}); ok {
					result[k] = mergeMessageLiterals(l, r)
				}
			} // else case shouldn't be possible, but if it happens r will overwite l later
		}
	}
	for k, v := range right {
		_, leftResult := result[k]
		if _, ok := v.(map[string]interface{}); !ok || !leftResult {
			result[k] = v
		}
	}
	return result
}

func mergeReservedRanges(rrs []ReservedRange,
	declType proto_ast.DeclarationType) []proto_ast.ReservedRange {

	switch declType {
	case proto_ast.Message, proto_ast.Enum:
	default:
		panic("invalid declaration to have a reserved range")
	}
	if len(rrs) == 0 {
		return []proto_ast.ReservedRange{}
	}
	max := proto_ast.MaxFieldNumber
	if declType == proto_ast.Enum {
		max = proto_ast.MaxEnumValueNumber
	}
	sorted := sortByStart(rrs)
	sort.Sort(sorted)
	result := []proto_ast.ReservedRange{}
	for _, rr := range sorted {
		if rr.Start > max {
			panic("start is higher than max")
		}
		if rr.End != nil {
			if *rr.End > max {
				panic("end is higher than max")
			}
			if *rr.End < rr.Start {
				panic("start should be less than end")
			}
			if *rr.End == max {
				rr.End = nil
			}
		}
		if len(result) > 0 {
			prev := &result[len(result)-1]
			if prev.End == nil || rr.Start <= *prev.End {
				panic("cannot have overlapping ranges")
			}
			if prev.End != nil && rr.Start == *prev.End+1 {
				prev.End = rr.End
				continue
			}
		}
		result = append(result, proto_ast.ReservedRange{
			Start: rr.Start,
			End:   rr.End,
		})
	}
	return result
}

type sortByStart []ReservedRange

func (a sortByStart) Len() int           { return len(a) }
func (a sortByStart) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a sortByStart) Less(i, j int) bool { return a[i].Start < a[j].Start }

func mergeReservedNames(rns []string) []string {
	seen := map[string]struct{}{}
	for _, n := range rns {
		if _, ok := seen[n]; ok {
			panic("reserved name specified multiple times")
		}
		seen[n] = struct{}{}
	}
	result := make([]string, 0, len(seen))
	for k := range seen {
		result = append(result, k)
	}
	sort.Strings(result)
	return result
}
