package example_test

import (
	"bytes"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/tomlinford/sroto"
)

func TestPopulateExamplesUpToDate(t *testing.T) {
	// This is just to check that `go generate` has been run since files in README.md
	// were updated.
	fileData, err := os.ReadFile("../README.md")
	if err != nil {
		panic(err)
	}
	fileRegexp := regexp.MustCompile("(?s)```[^\\n]+\\n// filename: ([^\\n]+)\n\n(([^`]|`[^`])+)```")
	for _, arr := range fileRegexp.FindAllSubmatch(fileData, -1) {
		if b, err := os.ReadFile(string(arr[1])); err != nil {
			t.Error(err)
		} else if !bytes.Equal(b, arr[2]) {
			t.Errorf(
				"output for %q doesn't match\nwant: %q\ngot:  %q\n(re-run go generate)",
				arr[1], arr[2], b)
		}
		if f, err := os.Open(string(arr[1])); err != nil {
			t.Error(err)
		} else {
			f.Close()
		}
	}
}

func TestExamples(t *testing.T) {
	// We also use the examples in README.md as goldens.
	dir := t.TempDir()
	jsonnetFiles, err := filepath.Glob("*.jsonnet")
	if err != nil {
		panic(err)
	}
	if len(jsonnetFiles) == 0 {
		panic("no jsonnet files found")
	}
	sroto.RunSrotoc(append(jsonnetFiles, "--proto_out="+dir))
	outDirFS := os.DirFS(dir)
	expectedDirFS := os.DirFS(".")
	filesFound := 0
	err = fs.WalkDir(outDirFS, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			panic(err)
		}
		if d.IsDir() {
			return nil
		}
		filesFound++
		out, err := fs.ReadFile(outDirFS, path)
		if err != nil {
			return err
		}
		expected, err := fs.ReadFile(expectedDirFS, path)
		if err != nil {
			return err
		}
		if !bytes.Equal(out, expected) {
			t.Errorf("output for %q doesn't match\nwant: %q\ngot:  %q", path, expected, out)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if filesFound != 7 { // sanity check
		t.Error("didn't find the right number of files")
	}
}

func TestProtocSucceeds(t *testing.T) {
	protoFiles, err := filepath.Glob("*.proto")
	if err != nil {
		t.Fatal(err)
	}
	args := append(protoFiles, "-I.", "-I=internal/vendor", "-o", "/dev/stdout")
	cmd := exec.Command("protoc", args...)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		t.Fatal(err)
	}
}
