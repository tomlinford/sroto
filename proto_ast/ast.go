package proto_ast

import (
	"fmt"
	"sort"
	"strings"
)

type File struct {
	Name         string
	Package      string
	Syntax       string
	Imports      []string
	Declarations []Declaration
	Options      []Option
}

func (f *File) Print() string {
	body := &body{}
	body.addLine("// Generated by srotoc. DO NOT EDIT!")
	body.addLine("")
	body.addLine(fmt.Sprintf("syntax = %q;\n", f.Syntax))
	body.addLine(fmt.Sprintf("package %s;\n", f.Package))
	if len(f.Options) > 0 {
		addLongOptions(body, f.Options)
		body.addLine("")
	}
	if len(f.Imports) > 0 {
		for _, fileImport := range f.Imports {
			body.addLine(fmt.Sprintf("import %q;", fileImport))
		}
		body.addLine("")
	}
	for i := range f.Declarations {
		if i > 0 {
			body.addLine("")
		}
		addDecl(body, &f.Declarations[i], false)
	}
	body.addLine("")
	return body.String()
}

type DeclarationType int

const (
	Message = iota + 1
	Field
	Enum
	EnumValue
	Extension
	Oneof
	Service
	Method
)

type Declaration struct {
	Name           string
	Help           string
	Type           DeclarationType
	Number         int            // Valid for Field and EnumValue
	Declarations   []Declaration  // Invalid for Field, EnumValue, and Method declarations
	Options        []Option       // Invalid for Extension declarations
	FieldDetails   *FieldDetails  // Extra data for Field declarations
	MethodDetails  *MethodDetails // Extra data for Method declarations
	ReservedRanges []ReservedRange
	ReservedNames  []string
}

type Option struct {
	Name  string
	Path  string // Only valid if attached to a Field or EnumValue
	Value any
}

type EnumValueLiteral string

const (
	MaxFieldNumber     = 536870911  // 2^29 - 1
	MaxEnumValueNumber = 2147483647 // 2^32
)

type ReservedRange struct {
	Start int  // inclusive
	End   *int // inclusive, nil means max
}

func (r *ReservedRange) render(declType DeclarationType) string {
	if r.End == nil {
		return fmt.Sprintf("reserved %d to max;", r.Start)
	}
	if r.Start == *r.End {
		return fmt.Sprintf("reserved %d;", r.Start)
	}
	return fmt.Sprintf("reserved %d to %d;", r.Start, *r.End)
}

type FieldDetails struct {
	Type  string
	Label string
}

type MethodDetails struct {
	InputType       string
	OutputType      string
	ClientStreaming bool
	ServerStreaming bool
}

type body struct {
	indent int
	lines  []line
}

func (b *body) addLineWithBlock(open, close string) *body {
	newBlock := &block{close: close, body: body{indent: b.indent + 1}}
	b.lines = append(b.lines, line{content: open, block: newBlock})
	return &newBlock.body
}

func (b *body) addLine(content string) {
	b.lines = append(b.lines, line{content: content})
}

func (b *body) String() string {
	sb := &strings.Builder{}
	indent := strings.Repeat("    ", b.indent)
	for i, line := range b.lines {
		if i > 0 {
			sb.WriteByte('\n')
		}
		writeLine(sb, &line, indent)
	}
	return sb.String()
}

func writeLine(sb *strings.Builder, l *line, indent string) {
	if l.content == "" && l.block == nil {
		return
	}
	sb.WriteString(indent)
	sb.WriteString(l.content)
	if l.block == nil {
		return
	}

	// control when we collapse. Don't collapse for:
	//  1. message, enum, extend, oneof, or service blocks
	//  2. (google.api.http) option blocks (for readability)
	//  3. if collapsing would cause column length to exceed 79 chars
	start, rest, _ := strings.Cut(l.content, " ")
	collapse := false
	switch start {
	case "message", "enum", "extend", "oneof", "service":
	default:
		second, _, _ := strings.Cut(rest, " ")
		if second != "(google.api.http)" {
			collapsedLen := len(indent) + len(l.content) + l.block.collapsedLen()
			if collapsedLen < 80 {
				collapse = true
			}
		}
	}
	if collapse {
		for i, line := range l.block.body.lines {
			if i > 0 {
				sb.WriteByte(' ')
			}
			writeLine(sb, &line, "")
		}
	} else {
		sb.WriteByte('\n')
		sb.WriteString(l.block.body.String())
		sb.WriteByte('\n')
		sb.WriteString(indent)
	}
	sb.WriteString(l.block.close)
}

type line struct {
	content string // includes start of block (eg. { or [)
	block   *block
}

type block struct {
	close string
	body  body
}

func (b *block) collapsedLen() int {
	l := len(b.close)
	for _, line := range b.body.lines {
		l += len(line.content)
		if line.block != nil {
			l += line.block.collapsedLen()
		}
	}
	return l
}

func addDecl(body *body, decl *Declaration, newLineIfHelp bool) {
	help := strings.TrimSpace(decl.Help)
	if help != "" {
		if newLineIfHelp {
			body.addLine("")
		}
		for _, line := range strings.Split(help, "\n") {
			if line == "" {
				body.addLine("//")
			} else {
				body.addLine("// " + line)
			}
		}
	}
	switch decl.Type {
	case Message, Enum, Extension, Oneof, Service:
		addBlockDecl(body, decl)
	case Field, EnumValue, Method:
		addLineDecl(body, decl)
	}
}

func addBlockDecl(body *body, decl *Declaration) {
	blockName := map[DeclarationType]string{
		Message:   "message",
		Enum:      "enum",
		Extension: "extend",
		Oneof:     "oneof",
		Service:   "service",
	}[decl.Type]
	inner := body.addLineWithBlock(blockName+" "+decl.Name+" {", "}")
	if len(decl.Options) > 0 {
		addLongOptions(inner, decl.Options)
		inner.addLine("")
	}
	for i := range decl.Declarations {
		addDecl(inner, &decl.Declarations[i], i > 0)
	}
	if len(decl.ReservedRanges) > 0 || len(decl.ReservedNames) > 0 {
		inner.addLine("")
	}
	for _, rr := range decl.ReservedRanges {
		inner.addLine(rr.render(decl.Type))
	}
	for _, rn := range decl.ReservedNames {
		inner.addLine(fmt.Sprintf("reserved %q;", rn))
	}
}

func addLineDecl(body *body, decl *Declaration) {
	switch decl.Type {
	case EnumValue:
		prefix := fmt.Sprintf("%s = %d", decl.Name, decl.Number)
		if len(decl.Options) == 0 {
			body.addLine(prefix + ";")
		} else {
			inner := body.addLineWithBlock(prefix+" [", "];")
			addShortOptions(inner, decl.Options)
		}
	case Field:
		label := decl.FieldDetails.Label
		if len(label) > 0 {
			label = label + " "
		}
		prefix := fmt.Sprintf("%s%s %s = %d", label, decl.FieldDetails.Type, decl.Name, decl.Number)
		if len(decl.Options) == 0 {
			body.addLine(prefix + ";")
		} else {
			inner := body.addLineWithBlock(prefix+" [", "];")
			addShortOptions(inner, decl.Options)
		}
	case Method:
		details := decl.MethodDetails
		inputType := methodType(details.InputType, details.ClientStreaming)
		outputType := methodType(details.OutputType, details.ServerStreaming)
		prefix := "rpc " + decl.Name + "(" + inputType + ") returns (" + outputType + ")"
		if len(decl.Options) == 0 {
			body.addLine(prefix + ";")
		} else {
			inner := body.addLineWithBlock(prefix+" {", "};")
			addLongOptions(inner, decl.Options)
		}
	}
}

func addShortOptions(body *body, options []Option) {
	for i, o := range options {
		path := ""
		if len(o.Path) > 0 {
			path = "." + path
		}
		prefix := o.Name
		if strings.Contains(o.Name, ".") || path != "" {
			prefix = "(" + o.Name + ")" + path
		}
		suffix := ""
		if i < len(options)-1 {
			suffix = ","
		}
		addOptionValue(body, o.Value, prefix+" = ", suffix)
	}
}

func addLongOptions(body *body, options []Option) {
	for _, o := range options {
		if o.Path != "" {
			panic("cannot have path specified for long option")
		}
		var prefix string
		if strings.Contains(o.Name, ".") {
			prefix = fmt.Sprintf("option (%s) = ", o.Name)
		} else {
			prefix = fmt.Sprintf("option %s = ", o.Name)
		}
		addOptionValue(body, o.Value, prefix, ";")
	}
}

func addOptionValue(body *body, value any, prefix, suffix string) {
	switch optionValue := value.(type) {
	case bool, float64, int, EnumValueLiteral:
		body.addLine(prefix + fmt.Sprint(optionValue) + suffix)
	case []byte, string:
		body.addLine(prefix + fmt.Sprintf("%q", optionValue) + suffix)
	case map[string]any:
		inner := body.addLineWithBlock(prefix+"{", "}"+suffix)
		keys := make([]string, 0, len(optionValue))
		for k := range optionValue {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for i, k := range keys {
			value := optionValue[k]
			suffix := ""
			if i < len(optionValue)-1 {
				suffix = ","
			}
			addOptionValue(inner, value, k+": ", suffix)
		}
	case []any:
		inner := body.addLineWithBlock(prefix+"[", "]"+suffix)
		for i, value := range optionValue {
			suffix := ""
			if i < len(optionValue)-1 {
				suffix = (",")
			}
			addOptionValue(inner, value, "", suffix)
		}
	default:
		panic(fmt.Sprintf("unknown type %T", value))
	}
}

func methodType(typeName string, streaming bool) string {
	if streaming {
		return "stream " + typeName
	}
	return typeName
}
