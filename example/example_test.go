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
			_ = f.Close()
		}
	}
}

func TestExamples(t *testing.T) {
	// We also use the examples in README.md as goldens.
	testCases := []struct {
		name    string
		pattern string
	}{
		{"Jsonnet", "*.jsonnet"},
		{"Nickel", "*.ncl"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			files, err := filepath.Glob(tc.pattern)
			if err != nil {
				panic(err)
			}
			if len(files) == 0 {
				t.Skipf("no %s files found", tc.name)
			}

			// Process each file individually so we can see which one fails
			for _, file := range files {
				t.Run(filepath.Base(file), func(t *testing.T) {
					fileDir := t.TempDir()
					sroto.RunSrotoc([]string{file, "--proto_out=" + fileDir})
					outDirFS := os.DirFS(fileDir)
					expectedDirFS := os.DirFS(".")

					err := fs.WalkDir(outDirFS, ".", func(path string, d fs.DirEntry, err error) error {
						if err != nil {
							return err
						}
						if d.IsDir() {
							return nil
						}
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
				})
			}
		})
	}
}

func TestNickelJsonnetParity(t *testing.T) {
	// Verify that matching .ncl and .jsonnet files produce identical .proto output
	jsonnetFiles, err := filepath.Glob("*.jsonnet")
	if err != nil {
		t.Fatal(err)
	}

	for _, jsonnetFile := range jsonnetFiles {
		// Find corresponding .ncl file
		nickelFile := jsonnetFile[:len(jsonnetFile)-len(".jsonnet")] + ".ncl"
		if _, err := os.Stat(nickelFile); os.IsNotExist(err) {
			// No corresponding nickel file, skip
			continue
		}

		t.Run(filepath.Base(jsonnetFile), func(t *testing.T) {
			// Generate proto from Jsonnet
			jsonnetDir := t.TempDir()
			sroto.RunSrotoc([]string{jsonnetFile, "--proto_out=" + jsonnetDir})

			// Generate proto from Nickel
			nickelDir := t.TempDir()
			sroto.RunSrotoc([]string{nickelFile, "--proto_out=" + nickelDir})

			// Compare all generated files
			jsonnetFS := os.DirFS(jsonnetDir)
			nickelFS := os.DirFS(nickelDir)

			err := fs.WalkDir(jsonnetFS, ".", func(path string, d fs.DirEntry, err error) error {
				if err != nil {
					return err
				}
				if d.IsDir() {
					return nil
				}

				jsonnetContent, err := fs.ReadFile(jsonnetFS, path)
				if err != nil {
					return err
				}

				nickelContent, err := fs.ReadFile(nickelFS, path)
				if err != nil {
					return err
				}

				if !bytes.Equal(jsonnetContent, nickelContent) {
					t.Errorf("output mismatch for %q\nJsonnet: %q\nNickel:  %q",
						path, jsonnetContent, nickelContent)
				}
				return nil
			})
			if err != nil {
				t.Fatal(err)
			}
		})
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
