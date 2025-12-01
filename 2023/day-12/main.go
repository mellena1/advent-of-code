package main

import (
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

type SpringState utils.Char

func (s SpringState) String() string {
	return utils.Char(s).String()
}

const (
	WORKING  SpringState = '.'
	BROKEN   SpringState = '#'
	QUESTION SpringState = '?'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	lines := parseLines(f)
	partOne := 0
	for _, l := range lines {
		partOne += l.PossibleArrangements()
	}
	fmt.Printf("Part one solution: %d\n", partOne)

	partTwo := 0
	for _, l := range lines {
		s := l.Unfold().PossibleArrangements()
		partTwo += s
	}
	fmt.Printf("Part two solution: %d\n", partTwo)
}

type LineOfSprings struct {
	springs []SpringState
	groups  []int
}

func (l LineOfSprings) PossibleArrangements() int {
	return bruteForceCombos(l.springs, l.groups, map[string]int{})
}

func (l LineOfSprings) Unfold() LineOfSprings {
	unfolded := LineOfSprings{
		springs: []SpringState{},
		groups:  []int{},
	}
	for i := 0; i < 5; i++ {
		unfolded.springs = append(unfolded.springs, l.springs...)
		if i < 4 {
			unfolded.springs = append(unfolded.springs, QUESTION)
		}
		unfolded.groups = append(unfolded.groups, l.groups...)
	}
	return unfolded
}

func (l *LineOfSprings) DedupDots() {
	l.springs = dedupDots(l.springs)
}

func (l LineOfSprings) String() string {
	s := ""
	for _, spring := range l.springs {
		s += string(spring)
	}
	s += " ("
	for i, group := range l.groups {
		s += strconv.Itoa(group)
		if i < len(l.groups)-1 {
			s += ", "
		}
	}
	return s + ")"
}

var dotsRegex = regexp.MustCompile(`\.{2,}`)

func dedupDots(s []SpringState) []SpringState {
	newSprings := dotsRegex.ReplaceAllString(string(s), ".")
	return []SpringState(newSprings)
}

func bruteForceCombos(springs []SpringState, groups []int, cache map[string]int) int {
	total := 0

	cacheKey := fmt.Sprintf("%s|%v", springs, groups)

	if v, ok := cache[cacheKey]; ok {
		return v
	}

	if len(springs) == 0 {
		if len(groups) == 0 {
			return 1
		} else {
			return 0
		}
	}

	switch springs[0] {
	case WORKING:
		return bruteForceCombos(springs[1:], groups, cache)
	case BROKEN:
		if len(groups) == 0 || groups[0] > len(springs) {
			return 0
		}

		for i := 1; i < groups[0]; i++ {
			if springs[i] == WORKING {
				return 0
			}
		}

		if len(springs) > groups[0] {
			if springs[groups[0]] == BROKEN {
				return 0
			}
			return bruteForceCombos(springs[groups[0]+1:], groups[1:], cache)
		} else {
			return bruteForceCombos(springs[groups[0]:], groups[1:], cache)
		}
	case QUESTION:
		springs[0] = WORKING
		total += bruteForceCombos(springs, groups, cache)

		springs[0] = BROKEN
		total += bruteForceCombos(springs, groups, cache)

		springs[0] = QUESTION
	}

	cache[cacheKey] = total

	return total
}

func parseLines(r io.Reader) []LineOfSprings {
	lines := []LineOfSprings{}
	utils.ExecutePerLine(r, func(line string) error {
		springs, groups, _ := strings.Cut(line, " ")

		groupsInts, err := utils.StrSliceToIntSlice(strings.FieldsFunc(groups, func(r rune) bool {
			return r == ','
		}))
		if err != nil {
			return fmt.Errorf("failed to parse groups %q: %w", groups, err)
		}

		newLineOfSprings := LineOfSprings{
			springs: []SpringState(springs),
			groups:  groupsInts,
		}
		newLineOfSprings.DedupDots()

		lines = append(lines, newLineOfSprings)

		return nil
	})
	return lines
}
