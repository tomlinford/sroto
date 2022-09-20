package proto_ast

import (
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestFprintOptionValue(t *testing.T) {
	tests := []struct {
		name  string
		input any
		want  string
	}{
		{"int", 1, "1"},
		{"bool", true, "true"},
		{"string", "foo", `"foo"`},
		{"message", map[string]any{
			"foo": "bar",
			"baz": 1,
		}, "{\n    baz: 1,\n    foo: \"bar\"\n}"},
		{"nested", map[string]any{
			"foo": map[string]any{"bar": 1},
		}, "{\n    foo: {\n        bar: 1\n    }\n}"},
		{"repeated", map[string]any{
			"foo": []any{1, 2},
		}, "{\n    foo: 1,\n    foo: 2\n}"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := new(codeWriter)
			fprintOptionValue(w, tt.input)
			diff := cmp.Diff(tt.want, w.b.String())
			if diff != "" {
				t.Error(diff)
			}
		})
	}
}

func TestFilePrint(t *testing.T) {
	five := int(5)
	eight := int(8)
	f := File{
		Package: "foo",
		Syntax:  "proto3",
		Declarations: []Declaration{
			{
				Name: "EchoRequest",
				Help: "Request to send an echo back.",
				Type: Message,
				Declarations: []Declaration{
					{
						Name:   "message",
						Help:   "The message to get echoed.",
						Type:   Field,
						Number: 1,
						FieldDetails: &FieldDetails{
							Type: "string",
						},
					},
					{
						Name:   "priority",
						Help:   "The priority of the EchoRequest.",
						Type:   Field,
						Number: 2,
						FieldDetails: &FieldDetails{
							Type: "int64",
						},
					},
				},
				ReservedRanges: []ReservedRange{
					{5, &five},
					{6, &eight},
					{10, nil},
				},
				ReservedNames: []string{"foo"},
			},
		},
	}
	expected := `
// Generated by srotoc. DO NOT EDIT!

syntax = "proto3";

package foo;

// Request to send an echo back.
message EchoRequest {
    // The message to get echoed.
    string message = 1;

    // The priority of the EchoRequest.
    int64 priority = 2;

    reserved 5;
    reserved 6 to 8;
    reserved 10 to max;
    reserved "foo";
}
`[1:]
	actual := f.Print()
	if actual != expected {
		t.Errorf("got\n%q, want\n%q", actual, expected)
	}
}
