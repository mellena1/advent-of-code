package utils

import (
	"bufio"
	"fmt"
	"io"
	"os"
)

func ReadFile(name string) *os.File {
	f, err := os.Open(name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to open file: %s\n", err)
		os.Exit(1)
	}
	return f
}

func ExecutePerLine(r io.Reader, f func(line string) error) {
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		line := scanner.Text()

		err := f(line)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error in parsing func: %s", err)
			os.Exit(1)
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "error reading file: %s", err)
		os.Exit(1)
	}
}
