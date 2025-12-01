package main

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	TRENCH  = '#'
	NOTHING = '.'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	steps := parseDigInput(f)
	fmt.Printf("Part one solution: %d\n", steps.AreaWithShoelace())

	partTwoSteps := DigSteps(utils.SliceMap(steps, func(s DigStep) DigStep {
		return s.PartTwoStep()
	}))
	fmt.Printf("Part two solution: %d\n", partTwoSteps.AreaWithShoelace())
}

type Grid struct {
	rowLen      int
	colLen      int
	polyCorners []utils.Coordinate
}

func NewGrid() Grid {
	return Grid{
		rowLen:      1,
		colLen:      1,
		polyCorners: []utils.Coordinate{},
	}
}

func (g *Grid) AddRow(idx int) {
	if idx == -1 {
		for i, corner := range g.polyCorners {
			g.polyCorners[i] = corner.MoveDir(utils.DOWN)
		}
	}
	g.rowLen++
}

func (g *Grid) AddCol(idx int) {
	if idx == -1 {
		for i, corner := range g.polyCorners {
			g.polyCorners[i] = corner.MoveDir(utils.RIGHT)
		}
	}
	g.colLen++
}

type DigStep struct {
	Dir      utils.Direction
	NumToDig int
	Color    string
}

func (step DigStep) PartTwoStep() DigStep {
	var dir utils.Direction
	switch step.Color[5] {
	case '0':
		dir = utils.RIGHT
	case '1':
		dir = utils.DOWN
	case '2':
		dir = utils.LEFT
	case '3':
		dir = utils.UP
	}

	numToDig, _ := strconv.ParseInt(step.Color[:5], 16, 0)

	return DigStep{
		Dir:      dir,
		NumToDig: int(numToDig),
		Color:    step.Color,
	}
}

type DigSteps []DigStep

func (steps DigSteps) getGrid() Grid {
	grid := NewGrid()

	coor := utils.NewCoordinate(0, 0)
	grid.polyCorners = append(grid.polyCorners, coor)

	for stepIdx, step := range steps {
		for i := 0; i < step.NumToDig; i++ {
			coor = coor.MoveDir(step.Dir)
			switch step.Dir {
			case utils.RIGHT:
				if coor.X >= grid.colLen {
					grid.AddCol(coor.X)
				}
			case utils.LEFT:
				if coor.X < 0 {
					grid.AddCol(coor.X)
					// -1 is now 0
					coor = coor.MoveDir(utils.RIGHT)
				}
			case utils.DOWN:
				if coor.Y >= grid.rowLen {
					grid.AddRow(coor.Y)
				}
			case utils.UP:
				if coor.Y < 0 {
					grid.AddRow(coor.Y)
					// -1 is now 0
					coor = coor.MoveDir(utils.DOWN)
				}
			}
		}
		if stepIdx < len(steps)-1 {
			grid.polyCorners = append(grid.polyCorners, coor)
		}
	}

	return grid
}

func (s DigSteps) AreaWithShoelace() int {
	// https://en.wikipedia.org/wiki/Shoelace_formula

	grid := s.getGrid()

	area := 0
	perimeter := 0

	addPerim := func(c1, c2 utils.Coordinate) {
		diff := c1.Sub(c2)
		// this ignores any change in the perim if it's negative (i.e. going left or up),
		// but it works somehow and I have no idea why
		perimeter += max(diff.X, diff.Y)
	}

	addArea := func(c1, c2 utils.Coordinate) {
		area += (c2.X * c1.Y) - (c1.X * c2.Y)
	}

	firstCoor := grid.polyCorners[0]
	lastCoor := firstCoor
	for _, coor := range grid.polyCorners[1:] {
		addPerim(coor, lastCoor)
		addArea(coor, lastCoor)
		lastCoor = coor
	}

	// do last section from lastCoor to first since it needs to loop back to the beginning
	addArea(firstCoor, lastCoor)
	area /= 2 // need to divide by 2 at the end of the shoelace formula
	addPerim(firstCoor, lastCoor)

	// my answers somehow ended always off by one, so add one lol
	return area + perimeter + 1
}

func parseDigInput(r io.Reader) DigSteps {
	steps := DigSteps{}

	utils.ExecutePerLine(r, func(line string) error {
		lineSplit := strings.Split(line, " ")

		step := DigStep{}

		switch lineSplit[0] {
		case "R":
			step.Dir = utils.RIGHT
		case "L":
			step.Dir = utils.LEFT
		case "U":
			step.Dir = utils.UP
		case "D":
			step.Dir = utils.DOWN
		}

		step.NumToDig, _ = strconv.Atoi(lineSplit[1])
		step.Color = lineSplit[2][2:8]

		steps = append(steps, step)

		return nil
	})

	return steps
}
