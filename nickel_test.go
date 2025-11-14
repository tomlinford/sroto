package sroto_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/tomlinford/sroto"
)

func TestNickelCLINotInstalled(t *testing.T) {
	// Test that we get a helpful error when nickel CLI is missing
	if _, err := exec.LookPath("nickel"); err == nil {
		t.Skip("nickel CLI is installed, skipping this test")
	}

	// Create a temp directory with a simple .ncl file
	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "test.ncl")
	content := `let sroto = import "sroto.ncl" in
sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    id = sroto.Int64Field 1,
  },
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	// Try to run srotoc - should fail gracefully
	defer func() {
		if r := recover(); r != nil {
			// Check that the panic message mentions nickel
			msg, ok := r.(string)
			if !ok {
				t.Errorf("panic value is not a string: %T: %v", r, r)
				return
			}
			if !strings.Contains(strings.ToLower(msg), "nickel") {
				t.Errorf("panic message doesn't mention nickel: %v", msg)
			}
		}
	}()

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})

	// If we get here without panic, the test should fail
	t.Error("expected panic when nickel CLI is not installed")
}

func TestNickelSyntaxError(t *testing.T) {
	// Test that syntax errors in .ncl files are reported properly
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "invalid.ncl")

	// Invalid Nickel syntax: missing closing brace
	content := `let sroto = import "sroto.ncl" in
sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    id = sroto.Int64Field 1,
  },
  # Missing closing brace here
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	// Try to run srotoc - should fail with syntax error
	defer func() {
		if r := recover(); r != nil {
			// Check that the error message is informative
			msg, ok := r.(string)
			if !ok {
				t.Errorf("panic value is not a string: %T: %v", r, r)
				return
			}
			if !strings.Contains(msg, "nickel") && !strings.Contains(msg, "invalid") {
				t.Logf("error message may not be informative enough: %v", msg)
			}
		} else {
			t.Error("expected panic for invalid Nickel syntax")
		}
	}()

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})
}

func TestNickelImportError(t *testing.T) {
	// Test that missing imports are reported properly
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "missing_import.ncl")

	// Reference a non-existent import
	content := `let sroto = import "sroto.ncl" in
let nonexistent = import "does_not_exist.ncl" in

sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    id = sroto.Int64Field 1,
  },
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	// Try to run srotoc - should fail with import error
	defer func() {
		if r := recover(); r != nil {
			msg, ok := r.(string)
			if !ok {
				t.Errorf("panic value is not a string: %T: %v", r, r)
				return
			}
			if !strings.Contains(strings.ToLower(msg), "import") &&
			   !strings.Contains(strings.ToLower(msg), "not found") {
				t.Logf("error message may not mention import error: %v", msg)
			}
		} else {
			t.Error("expected panic for missing import")
		}
	}()

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})
}

func TestNickelImportPathResolution(t *testing.T) {
	// Test that import paths are resolved correctly
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	// This test verifies that the import path logic in getNickelIRFileData works
	// We create a .ncl file that imports sroto.ncl from the repo root
	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "test.ncl")

	content := `let sroto = import "sroto.ncl" in

sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    id = sroto.Int64Field 1,
    name = sroto.StringField 2,
  },
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	// This should work because getNickelIRFileData adds parent directories to import path
	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})

	// Verify the output file was created
	expectedProto := filepath.Join(outDir, "test.proto")
	if _, err := os.Stat(expectedProto); os.IsNotExist(err) {
		t.Errorf("expected proto file not created: %s", expectedProto)
	}
}

func TestNickelReservedFields(t *testing.T) {
	// Test that reserved fields are correctly transformed
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "reserved.ncl")

	// Test shorthand reserved syntax
	content := `let sroto = import "sroto.ncl" in

sroto.File "test.proto" "test" {
  TestEnum = sroto.Enum {
    UNKNOWN = 0,
    FIRST = 1,
    THIRD = 3,
    reserved = [
      2,              # Single field number
      [10, 20],       # Range from 10 to 20
      [100, "max"],   # Range from 100 to max
      "DEPRECATED",   # Reserved name
    ],
  },
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})

	// Read the generated proto and verify reserved fields are present
	protoContent, err := os.ReadFile(filepath.Join(outDir, "test.proto"))
	if err != nil {
		t.Fatal(err)
	}

	protoStr := string(protoContent)
	// Check that reserved statements are present with specific patterns
	expectedPatterns := []string{
		"reserved",          // General reserved keyword
		"DEPRECATED",        // Reserved name
		"2",                 // Single field number
		"10",                // Start of range
		"20",                // End of range
	}
	for _, pattern := range expectedPatterns {
		if !strings.Contains(protoStr, pattern) {
			t.Errorf("generated proto doesn't contain expected pattern: %q\nFull proto:\n%s", pattern, protoStr)
		}
	}
}

func TestNickelWellKnownTypes(t *testing.T) {
	// Test that well-known types work correctly
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "wkt.ncl")

	content := `let sroto = import "sroto.ncl" in

sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    created_at = sroto.Field sroto.WKT.Timestamp 1 [],
    metadata = sroto.Field sroto.WKT.Struct 2 [],
    duration = sroto.Field sroto.WKT.Duration 3 [],
    value = sroto.Field sroto.WKT.Value 4 [],
  } [],
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})

	// Read the generated proto and verify WKT imports
	protoContent, err := os.ReadFile(filepath.Join(outDir, "test.proto"))
	if err != nil {
		t.Fatal(err)
	}

	protoStr := string(protoContent)
	// Check that WKT imports are present
	expectedImports := []string{
		"google/protobuf/timestamp.proto",
		"google/protobuf/struct.proto",
		"google/protobuf/duration.proto",
	}
	for _, imp := range expectedImports {
		if !strings.Contains(protoStr, imp) {
			t.Errorf("generated proto missing import: %s", imp)
		}
	}
}

func TestNickelComposedFields(t *testing.T) {
	// Test that composed fields with options work correctly
	if _, err := exec.LookPath("nickel"); err != nil {
		t.Skip("nickel CLI not installed")
	}

	dir := t.TempDir()
	nickelFile := filepath.Join(dir, "composed.ncl")

	// Test field composition with options at multiple levels
	content := `let sroto = import "sroto.ncl" in

# Layer 1: Base custom field with validation options
let StringFieldWithValidation = fun number min_length max_length opts =>
  sroto.StringField number ([{
    type = {
      name = "rules",
      filename = "validate/validate.proto",
      package = "validate",
    },
    path = "string",
    value = {
      min_len = min_length,
      max_len = max_length,
    },
  }] @ opts)
in

# Layer 2: UUID field built on validated string field
let UUIDField = fun number opts =>
  StringFieldWithValidation number 36 36 ([{
    type = {
      name = "rules",
      filename = "validate/validate.proto",
      package = "validate",
    },
    path = "string.uuid",
    value = true,
  }] @ opts)
in

# Layer 3: Required UUID field built on UUID field
let RequiredUUIDField = fun number opts =>
  UUIDField number ([{
    type = {
      name = "field_behavior",
      filename = "google/api/field_behavior.proto",
      package = "google.api",
    },
    value = [sroto.EnumValueLiteral "REQUIRED"],
  }] @ opts)
in

sroto.File "test.proto" "test" {
  TestMessage = sroto.Message {
    # Uses base custom field
    nickname = StringFieldWithValidation 1 3 50 [],
    # Uses layer 2 (composed) custom field
    user_id = UUIDField 2 [],
    # Uses layer 3 (double composed) custom field
    tenant_id = RequiredUUIDField 3 [],
  } [],
} []
`
	if err := os.WriteFile(nickelFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	outDir := t.TempDir()
	sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + outDir})

	// Read the generated proto and verify composed field options
	protoContent, err := os.ReadFile(filepath.Join(outDir, "test.proto"))
	if err != nil {
		t.Fatal(err)
	}

	protoStr := string(protoContent)

	// Verify imports for options are present
	expectedImports := []string{
		"validate/validate.proto",
		"google/api/field_behavior.proto",
	}
	for _, imp := range expectedImports {
		if !strings.Contains(protoStr, imp) {
			t.Errorf("generated proto missing import: %s", imp)
		}
	}

	// Verify that composed options are present
	// Layer 1: nickname should have min_len and max_len
	if !strings.Contains(protoStr, "min_len") || !strings.Contains(protoStr, "max_len") {
		t.Error("nickname field missing validation options")
	}

	// Layer 2: user_id should have UUID validation AND min/max len (from composition)
	if !strings.Contains(protoStr, "uuid") {
		t.Error("user_id field missing UUID validation")
	}

	// Layer 3: tenant_id should have REQUIRED, UUID, and min/max len (from double composition)
	if !strings.Contains(protoStr, "REQUIRED") {
		t.Error("tenant_id field missing REQUIRED option")
	}

	// Verify the field numbers are correct
	expectedPatterns := []string{
		"nickname = 1",
		"user_id = 2",
		"tenant_id = 3",
	}
	for _, pattern := range expectedPatterns {
		if !strings.Contains(protoStr, pattern) {
			t.Errorf("generated proto missing expected pattern: %q", pattern)
		}
	}
}
