package main

import (
	"fmt"
	"io"
	"slices"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	games := getGamesFromText(f)

	partOneSum := 0

	for _, game := range games {
		partOneSum += game.getScore()
	}
	fmt.Printf("Part one sum: %d\n", partOneSum)

	partTwoSum := calcNumberOfCardsWithCopies(games)
	fmt.Printf("Part two sum: %d\n", partTwoSum)
}

func getGamesFromText(f io.Reader) []Game {
	games := []Game{}

	utils.ExecutePerLine(f, func(line string) error {
		game, err := getGameFromLine(line)
		if err != nil {
			return fmt.Errorf("failed to get game from line %q: %s", line, err)
		}

		games = append(games, game)

		return nil
	})

	return games
}

func getGameFromLine(line string) (Game, error) {
	splitOnColon := strings.Split(line, ":")
	gameID, err := strconv.Atoi(strings.Fields(splitOnColon[0])[1])
	if err != nil {
		return Game{}, fmt.Errorf("invalid game id: %w", err)
	}

	splitOnBar := strings.Split(splitOnColon[1], "|")
	winningNumsStrs := strings.Fields(splitOnBar[0])
	playerNumsStrs := strings.Fields(splitOnBar[1])

	winningNums, err := utils.StrSliceToIntSlice(winningNumsStrs)
	if err != nil {
		return Game{}, fmt.Errorf("invalid winning nums: %w", err)
	}

	playerNums, err := utils.StrSliceToIntSlice(playerNumsStrs)
	if err != nil {
		return Game{}, fmt.Errorf("invalid player nums: %w", err)
	}

	return Game{
		ID:             gameID,
		WinningNumbers: winningNums,
		Numbers:        playerNums,
		score:          -1,
		matches:        -1,
	}, nil
}

func calcNumberOfCardsWithCopies(games []Game) int {
	// memoize how many cards each card gives you in total
	cardsGiven := make([]int, len(games))

	// recursively determine how many cards you end up with
	//	starting from card idx
	var calc func(idx int) int
	calc = func(idx int) int {
		if cardsGiven[idx] > 0 {
			return cardsGiven[idx]
		}

		matches := games[idx].getMatchingNums()

		numCards := 1

		for i := idx + 1; i < len(games) && i <= idx+matches; i++ {
			numCards += calc(i)
		}

		cardsGiven[idx] = numCards

		return numCards
	}

	numCards := 0
	for i := range games {
		numCards += calc(i)
	}

	return numCards
}

type Game struct {
	ID             int
	WinningNumbers []int
	Numbers        []int
	score          int
	matches        int
}

func (g *Game) getScore() int {
	// memoize score so we don't recalc every call
	if g.score >= 0 {
		return g.score
	}

	score := 0

	matches := g.getMatchingNums()
	if matches > 0 {
		// 2 to the power of (matches - 1)
		// if one match, 1, if two matches, 2, etc
		score = 1 << (matches - 1)
	}

	g.score = score
	return score
}

func (g *Game) getMatchingNums() int {
	// memoize matches so we don't recalc every call
	if g.matches >= 0 {
		return g.matches
	}

	matches := 0

	for _, n := range g.WinningNumbers {
		if slices.Contains(g.Numbers, n) {
			matches += 1
		}
	}

	g.matches = matches
	return matches
}
