package utils

// Char is just a rune that implements Stringer so that printing out runes is nicer
type Char rune

func (c Char) String() string {
	return string(c)
}
