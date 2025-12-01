package main

import "slices"

type HandType int

const (
	FiveOfAKind HandType = iota
	FourOfAKind
	FullHouse
	ThreeOfAKind
	TwoPair
	OnePair
	HighCard
)

func (t HandType) String() string {
	switch t {
	case FiveOfAKind:
		return "Five of a kind"
	case FourOfAKind:
		return "Four of a kind"
	case FullHouse:
		return "Full house"
	case ThreeOfAKind:
		return "Three of a kind"
	case TwoPair:
		return "Two pair"
	case OnePair:
		return "One pair"
	case HighCard:
		return "High card"
	}

	return ""
}

func calcHandType(cards []Card, withJoker bool) HandType {
	cardCount := make([]int, 13)
	jokers := 0

	for _, c := range cards {
		if withJoker && c == Jack {
			jokers++
			continue
		}
		cardCount[c]++
	}

	// reverse sort the counts
	slices.SortFunc(cardCount, func(a, b int) int {
		return b - a
	})

	if jokers > 0 {
		cardCount[0] += jokers
	}

	if cardCount[0] == 5 {
		return FiveOfAKind
	}

	if cardCount[0] == 4 {
		return FourOfAKind
	}

	if cardCount[0] == 3 {
		if cardCount[1] == 2 {
			return FullHouse
		}
		return ThreeOfAKind
	}

	if cardCount[0] == 2 {
		if cardCount[1] == 2 {
			return TwoPair
		}
		return OnePair
	}

	return HighCard
}
