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

	hands := parseHands(f)

	sortHands(hands, false)
	fmt.Printf("Part one solutions: %d\n", multiplyWinnings(hands))

	sortHands(hands, true)
	fmt.Printf("Part two solutions: %d\n", multiplyWinnings(hands))
}

type Hand struct {
	Cards         []Card
	Wager         int
	Type          HandType
	TypeWithJoker HandType
}

func sortHands(hands []Hand, withJoker bool) {
	slices.SortFunc(hands, func(a, b Hand) int {
		var diff int
		if withJoker {
			diff = int(a.TypeWithJoker) - int(b.TypeWithJoker)
		} else {
			diff = int(a.Type) - int(b.Type)
		}

		if diff != 0 {
			return diff
		}

		for i := range a.Cards {
			aCard := a.Cards[i]
			bCard := b.Cards[i]

			if withJoker {
				if aCard == Jack {
					aCard = -1
				}

				if bCard == Jack {
					bCard = -1
				}
			}

			if aCard == bCard {
				continue
			}

			if aCard > bCard {
				return -1
			} else {
				return 1
			}
		}

		return 0
	})
}

func multiplyWinnings(hands []Hand) int {
	winnings := 0
	for i, hand := range hands {
		winnings += (hand.Wager * (len(hands) - i))
	}
	return winnings
}

func parseHands(r io.Reader) []Hand {
	hands := []Hand{}

	utils.ExecutePerLine(r, func(line string) error {
		cards, wager, _ := strings.Cut(line, " ")

		wagerInt, err := strconv.Atoi(wager)
		if err != nil {
			return fmt.Errorf("error parsing wager %q: %w", wager, err)
		}

		cardsSlice := []Card{}
		for _, c := range cards {
			cardsSlice = append(cardsSlice, cardFromRune(c))
		}

		hands = append(hands, Hand{
			Cards:         cardsSlice,
			Wager:         wagerInt,
			Type:          calcHandType(cardsSlice, false),
			TypeWithJoker: calcHandType(cardsSlice, true),
		})

		return nil
	})

	return hands
}
