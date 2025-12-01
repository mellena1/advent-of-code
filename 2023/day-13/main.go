package main

import (
	"fmt"
	"io"
	"slices"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	ASH  = '.'
	ROCK = '#'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	patterns := parsePatterns(f)

	partOneSum := 0
	for _, p := range patterns {
		partOneSum += p.VerticalReflection()
		partOneSum += (p.HorizontalReflection() * 100)
	}
	fmt.Printf("Part one solution: %d\n", partOneSum)

	partTwoSum := 0
	for _, p := range patterns {
		partTwoSum += p.VerticalReflectionWithSmudge()
		partTwoSum += (p.HorizontalReflectionWithSmudge() * 100)
	}
	fmt.Printf("Part two solution: %d\n", partTwoSum)
}

type Pattern [][]utils.Char

func (p Pattern) HorizontalReflection() int {
	numRows := len(p)
	for mirrorRow := 0; mirrorRow < numRows-1; mirrorRow++ {
		isMirrored := true
		numAbove := mirrorRow + 1
		numBelow := numRows - mirrorRow - 1
		numToLookAt := min(numAbove, numBelow)
		for i := 0; i < numToLookAt; i++ {
			if !slices.Equal(p[mirrorRow-i], p[mirrorRow+i+1]) {
				isMirrored = false
				break
			}
		}
		if isMirrored {
			return numAbove
		}
	}
	return 0
}

func (p Pattern) HorizontalReflectionWithSmudge() int {
	numRows := len(p)
	for mirrorRow := 0; mirrorRow < numRows-1; mirrorRow++ {
		numWrong := 0
		numAbove := mirrorRow + 1
		numBelow := numRows - mirrorRow - 1
		numToLookAt := min(numAbove, numBelow)
		for i := 0; i < numToLookAt; i++ {
			numWrong += numDifferentInRows(p[mirrorRow-i], p[mirrorRow+i+1])
			if numWrong > 1 {
				break
			}
		}
		if numWrong == 1 {
			return numAbove
		}
	}
	return 0
}

func (p Pattern) VerticalReflection() int {
	numCols := len(p[0])
	for mirrorCol := 0; mirrorCol < numCols-1; mirrorCol++ {
		isMirrored := true
		numLeft := mirrorCol + 1
		numRight := numCols - mirrorCol - 1
		numToLookAt := min(numLeft, numRight)
		for _, row := range p {
			for i := 0; i < numToLookAt; i++ {
				if row[mirrorCol-i] != row[mirrorCol+i+1] {
					isMirrored = false
					break
				}
			}
			if !isMirrored {
				break
			}
		}
		if isMirrored {
			return numLeft
		}
	}
	return 0
}

func (p Pattern) VerticalReflectionWithSmudge() int {
	numCols := len(p[0])
	for mirrorCol := 0; mirrorCol < numCols-1; mirrorCol++ {
		numWrong := 0
		numLeft := mirrorCol + 1
		numRight := numCols - mirrorCol - 1
		numToLookAt := min(numLeft, numRight)
	OUTER:
		for _, row := range p {
			for i := 0; i < numToLookAt; i++ {
				if row[mirrorCol-i] != row[mirrorCol+i+1] {
					numWrong++
				}
				if numWrong > 1 {
					break OUTER
				}
			}
		}
		if numWrong == 1 {
			return numLeft
		}
	}
	return 0
}

func (p Pattern) String() string {
	s := ""
	for i, line := range p {
		s += string(line)
		if i < len(p)-1 {
			s += "\n"
		}
	}
	return s
}

func numDifferentInRows(r1, r2 []utils.Char) int {
	numDiff := 0
	for i, c := range r1 {
		if c != r2[i] {
			numDiff++
		}
	}
	return numDiff
}

func parsePatterns(r io.Reader) []Pattern {
	patterns := []Pattern{}

	curPattern := Pattern{}
	utils.ExecutePerLine(r, func(line string) error {
		if line == "" {
			patterns = append(patterns, curPattern)
			curPattern = Pattern{}
			return nil
		}

		curPattern = append(curPattern, []utils.Char(line))
		return nil
	})
	if len(curPattern) > 0 {
		patterns = append(patterns, curPattern)
	}

	return patterns
}
