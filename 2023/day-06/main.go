package main

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const accelIncreasePerMS = 1

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	races, partTwoRace := parseRaces(f)

	partOneAnswer := 1
	for _, race := range races {
		partOneAnswer *= race.waysToBeatRace()
	}
	fmt.Printf("Part one answer: %d\n", partOneAnswer)

	fmt.Printf("Part two answer: %d\n", partTwoRace.waysToBeatRace())
}

type Race struct {
	Milliseconds      int
	RecordMillimeters int
}

func (r Race) holdingIsFaster(milliseconds int) bool {
	accel := milliseconds * accelIncreasePerMS
	dist := accel * (r.Milliseconds - milliseconds)
	return dist > r.RecordMillimeters
}

func (r Race) waysToBeatRace() int {
	numFaster := 0
	for i := 1; i < r.Milliseconds; i++ {
		if r.holdingIsFaster(i) {
			numFaster++
		}
	}
	return numFaster
}

// []Race is for part 1, Race is for part 2
func parseRaces(f io.Reader) ([]Race, Race) {
	var times []int
	var distances []int
	var partTwoRace Race

	utils.ExecutePerLine(f, func(line string) error {
		var err error
		if strings.HasPrefix(line, "Time:") {
			times, err = parseNumsFromLine(line)

			numStr, _ := strings.CutPrefix(line, "Time:")
			combinedNum, err := combineNumsToOne(numStr)
			if err != nil {
				return fmt.Errorf("error combine nums %q: %w", numStr, err)
			}
			partTwoRace.Milliseconds = combinedNum
		} else if strings.HasPrefix(line, "Distance:") {
			distances, err = parseNumsFromLine(line)

			numStr, _ := strings.CutPrefix(line, "Distance:")
			combinedNum, err := combineNumsToOne(numStr)
			if err != nil {
				return fmt.Errorf("error combine nums %q: %w", numStr, err)
			}
			partTwoRace.RecordMillimeters = combinedNum
		}
		if err != nil {
			return fmt.Errorf("error parsing line %q: %w", line, err)
		}

		return nil
	})

	races := make([]Race, len(times))

	for i := range times {
		races[i] = Race{
			Milliseconds:      times[i],
			RecordMillimeters: distances[i],
		}
	}

	return races, partTwoRace
}

func parseNumsFromLine(line string) ([]int, error) {
	_, afterColon, _ := strings.Cut(line, ":")

	return utils.StrSliceToIntSlice(strings.Fields(afterColon))
}

func combineNumsToOne(s string) (int, error) {
	numStrNoSpace := strings.ReplaceAll(s, " ", "")
	return strconv.Atoi(numStrNoSpace)
}
