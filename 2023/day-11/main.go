package main

import (
	"fmt"
	"io"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	GALAXY = '#'
	SPACE  = '.'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)

	// part one
	galaxies := grid.findGalaxies(1)
	fmt.Printf("Part one solution: %d\n", sumAllStepsToGalaxies(galaxies))

	// part two
	galaxiesP2 := grid.findGalaxies(999_999)
	fmt.Printf("Part two solution: %d\n", sumAllStepsToGalaxies(galaxiesP2))
}

func sumAllStepsToGalaxies(galaxies []Galaxy) int {
	steps := 0
	for i, g := range galaxies {
		for j := i + 1; j < len(galaxies); j++ {
			steps += g.stepsToOtherGalaxy(galaxies[j])
		}
	}
	return steps
}

type Galaxy struct {
	Coor utils.Coordinate
}

func (g Galaxy) stepsToOtherGalaxy(g2 Galaxy) int {
	return g.Coor.StepsToCoordinate(g2.Coor)
}

type Grid [][]utils.Char

func (g Grid) String() string {
	s := ""
	for i := 0; i < len(g); i++ {
		for j := 0; j < len(g[i]); j++ {
			s += string(g[i][j])
		}
		s += "\n"
	}
	// rm extra newline
	return s[:len(s)-1]
}

func (g Grid) emptyRowsAndColIdxs() ([]int, []int) {
	// assumes that the grid is a square
	emptyRowIdxs := []int{}
	emptyColIdxs := []int{}
	for i := 0; i < len(g); i++ {
		emptyRow := true
		emptyCol := true
		for j := 0; j < len(g[0]); j++ {
			if g[i][j] == GALAXY {
				emptyRow = false
			}
			if g[j][i] == GALAXY {
				emptyCol = false
			}
		}
		if emptyRow {
			emptyRowIdxs = append(emptyRowIdxs, i)
		}
		if emptyCol {
			emptyColIdxs = append(emptyColIdxs, i)
		}
	}

	return emptyRowIdxs, emptyColIdxs
}

func (g Grid) findGalaxies(numSpaceToAdd int) []Galaxy {
	emptyRowIdxs, emptyColIdxs := g.emptyRowsAndColIdxs()

	galaxies := []Galaxy{}
	for i, row := range g {
		for j, val := range row {
			if val == GALAXY {
				// calc offsets for space expansion
				rowsToAdd := 0
				for _, emptyRowIdx := range emptyRowIdxs {
					if i < emptyRowIdx {
						break
					}
					rowsToAdd += numSpaceToAdd
				}
				colsToAdd := 0
				for _, emptyColIdx := range emptyColIdxs {
					if j < emptyColIdx {
						break
					}
					colsToAdd += numSpaceToAdd
				}

				galaxies = append(galaxies, Galaxy{
					Coor: utils.NewCoordinate(j+colsToAdd, i+rowsToAdd),
				})
			}
		}
	}
	return galaxies
}

func parseGrid(r io.Reader) Grid {
	grid := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		grid = append(grid, []utils.Char(line))
		return nil
	})

	return grid
}
