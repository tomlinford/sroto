package main

import (
	"os"

	"github.com/tomlinford/sroto"
)

func main() {
	sroto.RunSrotoc(os.Args[1:])
}
