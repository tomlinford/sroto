package proto_ast

import (
	"fmt"
	"sort"
	"strings"
)

type codeWriter struct {
	b      strings.Builder
	indent int
}

func (w *codeWriter) printfLn(format string, a ...interface{}) {
	line := fmt.Sprintf(format, a...)
	if len(line) > 0 {
		w.printIndent()
		w.b.WriteString(line)
	}
	w.b.WriteByte('\n')
}

func (w *codeWriter) println(a ...interface{}) {
	if len(a) > 0 {
		w.printIndent()
	}
	fmt.Fprintln(&w.b, a...)
}

func (w *codeWriter) printIndent() {
	w.b.WriteString(strings.Repeat("    ", w.indent))
}

type File struct {
	Name         string
	Package      string
	Syntax       string
	Imports      []string
	Declarations []Declaration
	Options      []Option
}

func (f *File) Print() string {
	w := &codeWriter{}
	w.println("// Generated by srotoc. DO NOT EDIT!")
	w.println()
	w.printfLn("syntax = %q;\n", f.Syntax)
	w.printfLn("package %s;\n", f.Package)
	if len(f.Options) > 0 {
		fprintLongOptions(w, f.Options)
		w.println()
	}
	if len(f.Imports) > 0 {
		for _, fileImport := range f.Imports {
			w.printfLn("import %q;", fileImport)
		}
		w.println()
	}
	for i, decl := range f.Declarations {
		if i > 0 {
			w.println()
		}
		decl.fprint(w, false)
	}
	return w.b.String()
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
	Value interface{}
}

type EnumValueLiteral string

func fprintOptionValue(w *codeWriter, value interface{}) {
	switch optionValue := value.(type) {
	case bool, float64, int:
		fmt.Fprint(&w.b, optionValue)
	case string:
		fmt.Fprintf(&w.b, "%q", optionValue)
	case EnumValueLiteral:
		fmt.Fprint(&w.b, optionValue)
	case map[string]interface{}:
		fmt.Fprintln(&w.b, "{")
		w.indent += 1
		keys := make([]string, 0, len(optionValue))
		for k := range optionValue {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		type messageEntry struct {
			name  string
			value interface{}
		}
		expanded := []messageEntry{}
		for _, k := range keys {
			value := optionValue[k]
			if s, ok := value.([]interface{}); ok {
				// TODO: test this
				for _, v := range s {
					expanded = append(expanded, messageEntry{k, v})
				}
			} else {
				expanded = append(expanded, messageEntry{k, value})
			}
		}
		for i, k := range expanded {
			w.printIndent()
			fmt.Fprintf(&w.b, "%s: ", k.name)
			fprintOptionValue(w, k.value)
			if i < len(expanded)-1 {
				w.b.WriteString(",")
			}
			fmt.Fprintln(&w.b)
		}
		w.indent -= 1
		w.printIndent()
		w.b.WriteByte('}')
	default:
		panic(fmt.Sprintf("unknown type %T", value))
	}
}

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

func (d *Declaration) fprint(w *codeWriter, newLineIfHelp bool) {
	help := strings.TrimSpace(d.Help)
	if help != "" {
		if newLineIfHelp {
			w.println()
		}
		for _, line := range strings.Split(help, "\n") {
			if line == "" {
				w.println("//")
			} else {
				w.printfLn("// %s", line)
			}
		}
	}
	switch d.Type {
	case Message, Enum, Extension, Oneof, Service:
		d.fprintBlock(w)
	case Field, EnumValue, Method:
		d.fprintLineDecl(w)
	}
}

func (d *Declaration) fprintBlock(w *codeWriter) {
	blockName := map[DeclarationType]string{
		Message:   "message",
		Enum:      "enum",
		Extension: "extend",
		Oneof:     "oneof",
		Service:   "service",
	}[d.Type]
	w.println(blockName, d.Name, "{")
	w.indent += 1
	if len(d.Options) > 0 {
		fprintLongOptions(w, d.Options)
		fmt.Fprintln(&w.b)
	}
	for i, decl := range d.Declarations {
		decl.fprint(w, i > 0)
	}
	if len(d.ReservedRanges) > 0 || len(d.ReservedNames) > 0 {
		w.println()
	}
	for _, rr := range d.ReservedRanges {
		w.println(rr.render(d.Type))
	}
	for _, rn := range d.ReservedNames {
		w.printfLn("reserved %q;", rn)
	}
	w.indent -= 1
	w.println("}")
}

func (d *Declaration) fprintLineDecl(w *codeWriter) {
	w.printIndent()
	switch d.Type {
	case EnumValue:
		fmt.Fprintf(&w.b, "%s = %d", d.Name, d.Number)
		fprintShortOptionsWithBlock(w, d.Options)
	case Field:
		label := d.FieldDetails.Label
		if len(label) > 0 {
			label = label + " "
		}
		fmt.Fprintf(&w.b, "%s%s %s = %d", label, d.FieldDetails.Type, d.Name, d.Number)
		fprintShortOptionsWithBlock(w, d.Options)
	case Method:
		details := d.MethodDetails
		inputType := methodType(details.InputType, details.ClientStreaming)
		outputType := methodType(details.OutputType, details.ServerStreaming)
		fmt.Fprintf(&w.b, "rpc %s(%s) returns (%s)", d.Name, inputType, outputType)
		if len(d.Options) > 0 {
			fmt.Fprintln(&w.b, " {")
			w.indent++
			fprintLongOptions(w, d.Options)
			w.indent--
			w.printIndent()
			w.b.WriteString("}")
		}
	}
	fmt.Fprintln(&w.b, ";")
}

func fprintShortOptionsWithBlock(w *codeWriter, options []Option) {
	if len(options) == 0 {
		return
	}
	fmt.Fprintln(&w.b, " [")
	w.indent += 1
	for i, o := range options {
		w.printIndent()
		path := ""
		if len(o.Path) > 0 {
			path = "." + path
		}
		if strings.Contains(o.Name, ".") || path != "" {
			fmt.Fprintf(&w.b, "(%s)%s = ", o.Name, path)
		} else {
			fmt.Fprintf(&w.b, "%s = ", o.Name)
		}
		fprintOptionValue(w, o.Value)
		if i < len(options)-1 {
			w.b.WriteString(",")
		}
		fmt.Fprintln(&w.b)
	}
	w.indent -= 1
	w.printIndent()
	w.b.WriteString("]")
}

func fprintLongOptions(w *codeWriter, options []Option) {
	for _, o := range options {
		if o.Path != "" {
			panic("cannot have path specified for long option")
		}
		w.printIndent()
		if strings.Contains(o.Name, ".") {
			fmt.Fprintf(&w.b, "option (%s) = ", o.Name)
		} else {
			fmt.Fprintf(&w.b, "option %s = ", o.Name)
		}
		fprintOptionValue(w, o.Value)
		fmt.Fprintln(&w.b, ";")
	}
}

func methodType(typeName string, streaming bool) string {
	if streaming {
		return "stream " + typeName
	}
	return typeName
}