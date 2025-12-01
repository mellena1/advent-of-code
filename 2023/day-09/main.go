package main

import (
	"fmt"
	"io"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	reading := parseOasis(f)

	partOneSum := 0
	for _, r := range reading {
		partOneSum += r.GetNextNumber()
	}
	fmt.Printf("Part one solution: %d\n", partOneSum)

	partTwoSum := 0
	for _, r := range reading {
		partTwoSum += r.GetPrevNumber()
	}
	fmt.Printf("Part two solution: %d\n", partTwoSum)
}

type OasisReading []int

func (o OasisReading) GetNextNumber() int {
	return o.nevilleInterpolation(len(o))
}

func (o OasisReading) GetPrevNumber() int {
	return o.nevilleInterpolation(-1)
}

func (o OasisReading) nevilleInterpolation(x int) int {
	xs := make([]int, len(o))
	for i := range o {
		xs[i] = i
	}
	return utils.NevilleInterpolation(xs, o, x)
}

func parseOasis(r io.Reader) []OasisReading {
	readings := []OasisReading{}

	utils.ExecutePerLine(r, func(line string) error {
		reading, err := utils.StrSliceToIntSlice(strings.Fields(line))
		if err != nil {
			return fmt.Errorf("failed to parse line %q: %w", line, err)
		}

		readings = append(readings, reading)

		return nil
	})

	return readings
}
