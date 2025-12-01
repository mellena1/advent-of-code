package main

import (
	"fmt"
	"io"
	"slices"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	EQUAL = '='
	DASH  = '-'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	seq := parseInitSequence(f)
	fmt.Printf("Part one solution: %d\n", seq.SumOfHashes())

	fmt.Printf("Part two solution: %d\n", seq.FocusingPower())
}

type Step []utils.Char

func (s Step) Hash() int {
	h := 0

	for _, c := range s {
		h += int(c)
		h *= 17
		h %= 256
	}

	return h
}

type StepLabelAndAction struct {
	Label       Step
	Action      utils.Char
	FocalLength int
}

func (s Step) LabelAndAction() StepLabelAndAction {
	strS := string(s)
	strEqual := string([]rune{EQUAL})
	if strings.Contains(strS, strEqual) {
		split := strings.Split(strS, strEqual)
		focalLength, err := strconv.Atoi(split[1])
		if err != nil {
			panic("bad focal length")
		}
		return StepLabelAndAction{
			Label:       Step(split[0]),
			Action:      EQUAL,
			FocalLength: focalLength,
		}
	}

	strDash := string([]rune{DASH})
	label, _ := strings.CutSuffix(strS, strDash)
	return StepLabelAndAction{
		Label:       Step(label),
		Action:      DASH,
		FocalLength: -1,
	}
}

type InitSequence []Step

func (seq InitSequence) SumOfHashes() int {
	sum := 0
	for _, s := range seq {
		sum += s.Hash()
	}
	return sum
}

type Lens struct {
	Label       string
	FocalLength int
}

type Boxes [][]Lens

func NewBoxes() Boxes {
	boxes := make(Boxes, 256)
	for i := range boxes {
		boxes[i] = []Lens{}
	}
	return boxes
}

func (b Boxes) findLabelIdx(boxIdx int, label string) int {
	return slices.IndexFunc(b[boxIdx], func(l Lens) bool { return l.Label == label })
}

func (b Boxes) AddOrReplaceLabel(boxIdx int, label string, focalLength int) {
	idx := b.findLabelIdx(boxIdx, label)

	if idx >= 0 {
		b[boxIdx][idx].FocalLength = focalLength
		return
	}

	b[boxIdx] = append(b[boxIdx], Lens{
		Label:       label,
		FocalLength: focalLength,
	})
}

func (b Boxes) RemoveLabel(boxIdx int, label string) {
	idx := b.findLabelIdx(boxIdx, label)

	if idx < 0 {
		return
	}

	b[boxIdx] = append(b[boxIdx][:idx], b[boxIdx][idx+1:]...)
}

func (seq InitSequence) FocusingPower() int {
	boxes := NewBoxes()

	for _, step := range seq {
		labelAndAction := step.LabelAndAction()
		hash := labelAndAction.Label.Hash()

		switch labelAndAction.Action {
		case DASH:
			boxes.RemoveLabel(hash, string(labelAndAction.Label))
		case EQUAL:
			boxes.AddOrReplaceLabel(hash, string(labelAndAction.Label), labelAndAction.FocalLength)
		}
	}

	focusingPower := 0
	for i, lenses := range boxes {
		if len(lenses) == 0 {
			continue
		}

		for j, lens := range lenses {
			focusingPower += ((i + 1) * (j + 1) * lens.FocalLength)
		}
	}

	return focusingPower
}

func parseInitSequence(r io.Reader) InitSequence {
	seq := InitSequence{}

	utils.ExecutePerLine(r, func(line string) error {
		commaSep := strings.Split(line, ",")
		for _, step := range commaSep {
			seq = append(seq, Step(step))
		}

		return nil
	})

	return seq
}
