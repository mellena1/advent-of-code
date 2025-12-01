package main

import (
	"fmt"
	"io"
	"math"
	"slices"
	"strings"
	"sync"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	almanac := parseAlmanac(f)

	partOneAnswer := math.MaxInt
	for _, seed := range almanac.Seeds {
		loc := almanac.GetSeedLocation(seed)
		if loc < partOneAnswer {
			partOneAnswer = loc
		}
	}
	fmt.Printf("Part one solution: %d\n", partOneAnswer)

	perStartSeedMins := make([]int, len(almanac.Seeds)/2)
	wg := sync.WaitGroup{}
	for i := 0; i < len(almanac.Seeds); i += 2 {
		wg.Add(1)
		go func(startSeedIdx, startSeed, numSeeds int) {
			lowest := math.MaxInt
			for j := startSeed; j < startSeed+numSeeds; j++ {
				loc := almanac.GetSeedLocation(j)
				if loc < lowest {
					lowest = loc
				}
			}
			perStartSeedMins[startSeedIdx/2] = lowest
			wg.Done()
		}(i, almanac.Seeds[i], almanac.Seeds[i+1])
	}
	wg.Wait()
	partTwoAnswer := slices.Min(perStartSeedMins)
	fmt.Printf("Part two solution: %d\n", partTwoAnswer)
}

type XToYMap []Mapping

type Mapping struct {
	DestRangeStart   int
	SourceRangeStart int
	RangeLen         int
}

type Almanac struct {
	Seeds []int
	Maps  []XToYMap
}

func (a *Almanac) GetSeedLocation(seed int) int {
	curNum := seed

	for _, xToYMap := range a.Maps {
		for _, mapping := range xToYMap {
			src := mapping.SourceRangeStart
			if curNum >= src && curNum < src+mapping.RangeLen {
				diffFromStart := curNum - src
				curNum = mapping.DestRangeStart + diffFromStart
				break
			}
		}
	}

	return curNum
}

func parseAlmanac(f io.Reader) Almanac {
	almanac := Almanac{
		Maps: []XToYMap{},
	}

	utils.ExecutePerLine(f, func(line string) error {
		// ignore blank lines
		if len(strings.TrimSpace(line)) == 0 {
			return nil
		}

		// parse the seeds
		if strings.HasPrefix(line, "seeds: ") {
			seedsStr, _ := strings.CutPrefix(line, "seeds: ")

			seeds, err := utils.StrSliceToIntSlice(strings.Fields(seedsStr))
			if err != nil {
				return fmt.Errorf("error parsing seeds %q: %w", line, err)
			}

			almanac.Seeds = seeds
			return nil
		}

		// start up a new x-to-y map
		if strings.HasSuffix(line, "map:") {
			almanac.Maps = append(almanac.Maps, XToYMap{})
			return nil
		}

		// parse the number lines
		nums, err := utils.StrSliceToIntSlice(strings.Fields(line))
		if err != nil {
			return fmt.Errorf("error parsing mapping %q: %w", line, err)
		}

		curMapIdx := len(almanac.Maps) - 1
		almanac.Maps[curMapIdx] = append(almanac.Maps[curMapIdx], Mapping{
			DestRangeStart:   nums[0],
			SourceRangeStart: nums[1],
			RangeLen:         nums[2],
		})

		return nil
	})

	return almanac
}
