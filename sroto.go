package sroto

import (
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/google/go-jsonnet"
	"github.com/tomlinford/sroto/sroto_ir"
)

//go:embed sroto.libsonnet
var JsonnetSources embed.FS

func RunSrotoc(args []string) {
	if len(args) == 0 {
		printHelp()
	}

	// arguments for jsonnet -> proto translation
	jPaths := []string{}
	protoOuts := []string{}
	jsonnetFiles := []string{}

	// arguments for protoc subcall
	doProtocSubcall := false
	protocArgs := []string{}
	protocArgSet := map[string]struct{}{}

	for _, arg := range args {
		if arg == "-h" || arg == "--help" {
			printHelp()
		}
		prevNumArgs := len(jPaths) + len(protoOuts)
		jPaths = appendArgIfSet(jPaths, arg, "-J")
		jPaths = appendArgIfSet(jPaths, arg, "--jpath=")
		protoOuts = appendArgIfSet(protoOuts, arg, "--proto_out=")
		if prevNumArgs == len(jPaths)+len(protoOuts) {
			// Argument was not parsed above
			if !strings.HasPrefix(arg, "-") && strings.HasSuffix(arg, ".jsonnet") {
				jsonnetFiles = append(jsonnetFiles, arg)
			} else {
				if strings.Contains(arg, "_out=") {
					doProtocSubcall = true
				}
				protocArgs = append(protocArgs, arg)
				protocArgSet[arg] = struct{}{}
			}
		}
	}
	if len(protoOuts) > 1 {
		log.Fatal("too many values set for argument --proto_out=")
	}
	if len(protoOuts) == 0 && len(jsonnetFiles) > 0 {
		log.Fatal("must set --proto_out if passing in .jsonnet files")
	}

	for filename, fileDataArr := range getIRFileData(jsonnetFiles, jPaths) {
		for _, fileData := range fileDataArr {
			// parse each file separately to enable better error reporting
			var irFile sroto_ir.File
			if err := json.Unmarshal(fileData, &irFile); err != nil {
				log.Fatal("parsing", filename, err)
			}
			outFilename := path.Join(protoOuts[0], irFile.Name)
			if err := os.MkdirAll(filepath.Dir(outFilename), 0777); err != nil {
				log.Fatal(err)
			}
			if err := os.WriteFile(outFilename, []byte(irFile.ToAST().Print()), 0666); err != nil {
				log.Fatal(err)
			}
			if _, ok := protocArgSet[irFile.Name]; !ok {
				protocArgs = append(protocArgs, irFile.Name)
				protocArgSet[irFile.Name] = struct{}{}
			}
		}
	}

	if doProtocSubcall {
		cmd := exec.Command("protoc", protocArgs...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			// will get a (*exec.Error) if `protoc` isn't found in $PATH.
			log.Fatal(err)
		}
	}
}

func appendArgIfSet(runningArgs []string, arg, argPrefix string) []string {
	if !strings.HasPrefix(arg, argPrefix) {
		return runningArgs
	}
	if len(arg) == len(argPrefix) {
		log.Fatalf("value for arg %q is unset", argPrefix)
	}
	return append(runningArgs, arg[len(argPrefix):])
}

type srotoJsonnetImporter struct {
	importer              jsonnet.Importer
	jsonnetSourceContents map[string]jsonnet.Contents
}

func (i *srotoJsonnetImporter) Import(importedFrom, importedPath string) (
	contents jsonnet.Contents, foundAt string, err error) {
	if contents, ok := i.jsonnetSourceContents[importedPath]; ok {
		return contents, importedPath, nil
	}
	contents, foundAt, err = i.importer.Import(importedFrom, importedPath)
	if err == nil {
		return contents, foundAt, err
	}
	if f, err := JsonnetSources.Open(importedPath); err == nil {
		defer f.Close()
		b := strings.Builder{}
		if _, err := io.Copy(&b, f); err != nil {
			panic(err) // should be impossible -- everything is in-memory
		}
		contents := jsonnet.MakeContents(b.String())
		i.jsonnetSourceContents[importedPath] = contents
		return contents, importedPath, nil
	}
	return contents, foundAt, err
}

func getIRFileData(jsonnetFiles, jPaths []string) map[string][]json.RawMessage {
	irFileData := map[string][]json.RawMessage{}
	if len(jsonnetFiles) == 0 {
		return irFileData
	}
	vm := jsonnet.MakeVM()
	vm.Importer(&srotoJsonnetImporter{
		importer:              jsonnet.Importer(&jsonnet.FileImporter{JPaths: jPaths}),
		jsonnetSourceContents: make(map[string]jsonnet.Contents),
	})
	jsonnetSnippet := generateJsonnetSnippet(jsonnetFiles)
	if jsonStr, err := vm.EvaluateAnonymousSnippet("-", jsonnetSnippet); err != nil {
		log.Fatal(err)
	} else if err := json.NewDecoder(strings.NewReader(jsonStr)).Decode(&irFileData); err != nil {
		log.Fatal(err)
	}
	return irFileData
}

func generateJsonnetSnippet(jsonnetFiles []string) string {
	sb := &strings.Builder{}
	for i, arg := range jsonnetFiles {
		fmt.Fprintf(sb, "local f%d = import %q;\n", i, arg)
	}
	sb.WriteString(`
local manifest(file) =
    if std.isArray(file)
    then [f.manifestSrotoIR() for f in file]
    else [file.manifestSrotoIR()];`)
	sb.WriteString("\n\n{\n")
	for i, arg := range jsonnetFiles {
		fmt.Fprintf(sb, "    %q: manifest(f%d),\n", arg, i)
	}
	sb.WriteString("}\n")
	return sb.String()
}

//go:embed cmd/srotoc/help.txt
var srotocHelp string

func printHelp() {
	out, err := exec.Command("protoc").CombinedOutput()
	if err != nil {
		log.Fatal(err)
	}
	// only show the options
	protocHelp := regexp.MustCompile(`(?s) +-.*`).Find(out)
	fmt.Print(srotocHelp)
	os.Stdout.Write(protocHelp)
}
