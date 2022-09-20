package main

import (
	"os"
	"regexp"
)

func main() {
	fileData, err := os.ReadFile("../README.md")
	if err != nil {
		panic(err)
	}
	fileRegexp := regexp.MustCompile("(?s)```[^\\n]+\\n// filename: ([^\\n]+)\n\n(([^`]|`[^`])+)```")
	for _, arr := range fileRegexp.FindAllSubmatch(fileData, -1) {
		if err := os.WriteFile(string(arr[1]), arr[2], 0666); err != nil {
			panic(err)
		}
	}
}
