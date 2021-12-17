package sroto_ir

import (
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/tomlinford/sroto/proto_ast"
)

func TestMergeOptions(t *testing.T) {
	tests := []struct {
		name  string
		input []Option
		want  []proto_ast.Option
	}{
		{"simple", []Option{
			{Type: Type{Name: "foo"}, Value: map[string]interface{}{
				"bar": 1,
				"baz": 2,
			}},
			{Type: Type{Name: "foo"}, Value: map[string]interface{}{
				"bar": 3,
				"baz": 2,
			}},
		}, []proto_ast.Option{
			{Name: "foo", Value: map[string]interface{}{
				"bar": 3,
				"baz": 2,
			}},
		}},
		{"repeated top level", []Option{
			{Type: Type{Name: "foo"}, Value: []interface{}{1, 2}},
		}, []proto_ast.Option{
			{Name: "foo", Value: 1},
			{Name: "foo", Value: 2},
		}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			diff := cmp.Diff(tt.want, mergeOptions(tt.input))
			if diff != "" {
				t.Error(diff)
			}
		})
	}
}
