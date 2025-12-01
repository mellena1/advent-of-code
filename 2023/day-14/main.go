package main

import (
	"fmt"
	"io"
	"slices"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	ROCK    = 'O'
	BLOCKER = '#'
	EMPTY   = '.'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)

	partOneGrid := grid.copy()
	partOneGrid = partOneGrid.shiftNorth()
	fmt.Printf("Part one solution: %d\n", partOneGrid.calcTotalLoad())

	partTwoGrid := grid.copy()
	cache := GridCache{}
	numCycles := 1_000_000_000
	for i := 0; i < numCycles; i++ {
		prevLenOfCache := len(cache)

		partTwoGrid = partTwoGrid.cycle(cache)

		// we hit a cycle
		if len(cache) == prevLenOfCache {
			break
		}
	}

	preCycle, cycle := cache.getGraphOfCycle(grid)

	if numCycles < len(preCycle) {
		fmt.Printf("Part two solution: %d\n", preCycle[numCycles].calcTotalLoad())
	} else {
		idx := (numCycles - len(preCycle)) % len(cycle)
		fmt.Printf("Part two solution: %d\n", cycle[idx].calcTotalLoad())
	}
}

type GridCache map[string]Grid

func (c GridCache) getGraphOfCycle(firstGrid Grid) ([]Grid, []Grid) {
	allPossibleGrids := []Grid{firstGrid}

	gridCompare := func(g Grid) func(g2 Grid) bool {
		gridString := g.String()
		return func(g2 Grid) bool {
			return gridString == g2.String()
		}
	}

	for _, v := range c {
		if slices.ContainsFunc(allPossibleGrids, gridCompare(v)) {
			continue
		}

		allPossibleGrids = append(allPossibleGrids, v)
	}

	orderedGrids := []Grid{}
	curGrid := firstGrid

	for !slices.ContainsFunc(orderedGrids, gridCompare(curGrid)) {
		orderedGrids = append(orderedGrids, curGrid)

		nextGrid := c[curGrid.String()]
		nextGridDedupIdx := slices.IndexFunc(allPossibleGrids, gridCompare(nextGrid))
		nextGrid = allPossibleGrids[nextGridDedupIdx]

		curGrid = nextGrid
	}

	// curGrid is now where the cycle is
	cycleIdx := slices.IndexFunc(orderedGrids, gridCompare(curGrid))

	// return everything before the cycle, and then the cycle
	return orderedGrids[:cycleIdx], orderedGrids[cycleIdx:]
}

type Grid []Row

func (g Grid) String() string {
	s := ""
	for i, row := range g {
		s += string(row)
		if i < len(g)-1 {
			s += "\n"
		}
	}
	return s
}

func (g Grid) copy() Grid {
	newGrid := make(Grid, len(g))
	for i, row := range g {
		newRow := make(Row, len(row))
		copy(newRow, row)
		newGrid[i] = newRow
	}
	return newGrid
}

func (g Grid) cycle(cache GridCache) Grid {
	strGrid := g.String()
	if cachedG, ok := cache[strGrid]; ok {
		return cachedG
	}

	newGrid := g.copy().shiftNorth().shiftWest().shiftSouth().shiftEast()

	cache[strGrid] = newGrid

	return newGrid
}

func (g Grid) shiftNorth() Grid {
	for i := 1; i < len(g); i++ {
		for j, c := range g[i] {
			if c != ROCK {
				continue
			}

			for y := i - 1; y >= 0; y-- {
				if g[y][j] == EMPTY {
					g[y][j] = ROCK
					g[y+1][j] = EMPTY
				} else {
					break
				}
			}
		}
	}

	return g
}

func (g Grid) shiftSouth() Grid {
	for i := len(g) - 2; i >= 0; i-- {
		for j, c := range g[i] {
			if c != ROCK {
				continue
			}

			for y := i + 1; y < len(g); y++ {
				if g[y][j] == EMPTY {
					g[y][j] = ROCK
					g[y-1][j] = EMPTY
				} else {
					break
				}
			}
		}
	}

	return g
}

func (g Grid) shiftEast() Grid {
	for _, row := range g {
		for j := len(row) - 2; j >= 0; j-- {
			if row[j] != ROCK {
				continue
			}

			for x := j + 1; x < len(row); x++ {
				if row[x] == EMPTY {
					row[x] = ROCK
					row[x-1] = EMPTY
				} else {
					break
				}
			}
		}
	}

	return g
}

func (g Grid) shiftWest() Grid {
	for _, row := range g {
		for j := 1; j < len(row); j++ {
			if row[j] != ROCK {
				continue
			}

			for x := j - 1; x >= 0; x-- {
				if row[x] == EMPTY {
					row[x] = ROCK
					row[x+1] = EMPTY
				} else {
					break
				}
			}
		}
	}

	return g
}

func (g Grid) calcTotalLoad() int {
	load := 0
	for i, row := range g {
		for _, c := range row {
			if c == ROCK {
				load += len(g) - i
			}
		}
	}
	return load
}

type Row []utils.Char

func (r Row) String() string {
	s := ""
	for _, c := range r {
		s += string(c)
	}
	return s
}

func parseGrid(r io.Reader) Grid {
	grid := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		grid = append(grid, Row(line))
		return nil
	})

	return grid
}
