package main

import (
	"fmt"
	"strconv"
	"unicode"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	partOneSum := 0
	partTwoSum := 0

	utils.ExecutePerLine(f, func(line string) error {
		num, err := getNumFromLine(line, false)
		if err != nil {
			return fmt.Errorf("unexpected error parsing line p1: %s, err: %s", line, err)
		}
		partOneSum += num

		num2, err := getNumFromLine(line, true)
		if err != nil {
			return fmt.Errorf("unexpected error parsing line p2: %s, err: %s", line, err)
		}
		partTwoSum += num2

		return nil
	})

	fmt.Printf("Part 1 answer: %d\n", partOneSum)
	fmt.Printf("Part 2 answer: %d\n", partTwoSum)
}

func getNumFromLine(line string, lookForWords bool) (int, error) {
	numberMap := map[string]rune{
		"one":   '1',
		"two":   '2',
		"three": '3',
		"four":  '4',
		"five":  '5',
		"six":   '6',
		"seven": '7',
		"eight": '8',
		"nine":  '9',
	}

	digits := make([]rune, 2)

	for i, r := range line {
		if unicode.IsDigit(r) {
			if digits[0] == 0 {
				digits[0] = r
			}
			digits[1] = r

			// if this char is a digit, no reason to look for words
			continue
		}

		// need at least three letters for a word number
		if !lookForWords || i < 2 {
			continue
		}

		// starting from the back, look for 3, 4, or 5 letter word numbers
		// if you find one, use it as the value
		for j := i - 2; j >= 0 && j >= i-4; j-- {
			if val, ok := numberMap[line[j:i+1]]; ok {
				if digits[0] == 0 {
					digits[0] = val
				}
				digits[1] = val
				break
			}
		}
	}

	return strconv.Atoi(string(digits))
}
