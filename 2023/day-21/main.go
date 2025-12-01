package main

import (
	"fmt"
	"io"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	START utils.Char = 'S'
	OPEN  utils.Char = '.'
	ROCK  utils.Char = '#'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)

	fmt.Printf("Part one solution: %d\n", grid.AvailableSpotsFromSteps(64))

	points := []int{}
	for i := 0; i < 3; i++ {
		points = append(points, grid.AvailableSpotsFromSteps(65+131*i))
		grid = grid.expand()
	}
	fmt.Printf("Part two solution: %d\n", utils.NevilleInterpolation([]int{0, 1, 2}, points, (26501365-65)/131))
}

type Grid [][]utils.Char

func (g Grid) String() string {
	s := ""

	for _, row := range g {
		for _, v := range row {
			s += string(v)
		}
		s += "\n"
	}

	return s
}

func (g Grid) AvailableSpotsFromSteps(maxSteps int) int {
	cMap := g.toConnectionMap()
	distances, _ := cMap.Dijkstra(g.findStart())

	s := 0
	for _, d := range distances {
		if d >= 0 && d <= maxSteps && d%2 == maxSteps%2 {
			s++
		}
	}
	return s
}

func (g Grid) findStart() utils.Coordinate {
	// start is always in the middle of the grid for the input/samples
	return utils.NewCoordinate(len(g[0])/2, len(g)/2)
}

func (g Grid) toConnectionMap() utils.ConnectionMap[utils.Coordinate] {
	cMap := utils.ConnectionMap[utils.Coordinate]{}

	for i, row := range g {
		for j, v := range row {
			if v == ROCK {
				continue
			}

			coor := utils.NewCoordinate(j, i)
			cMap[coor] = map[utils.Coordinate]int{}

			for k := -1; k <= 1; k++ {
				if i == 0 {
					continue
				}

				yCoor := coor.Y + k
				if yCoor >= 0 && yCoor < len(g) {
					if g[yCoor][coor.X] != ROCK {
						cMap[coor][utils.NewCoordinate(coor.X, yCoor)] = 1
					}
				}

				xCoor := coor.X + k
				if xCoor >= 0 && xCoor < len(g[coor.Y]) {
					if g[coor.Y][xCoor] != ROCK {
						cMap[coor][utils.NewCoordinate(xCoor, coor.Y)] = 1
					}
				}
			}
		}
	}

	return cMap
}

func (g Grid) expand() Grid {
	newGrid := make(Grid, len(g)+2*len(g))
	for i := range newGrid {
		newGrid[i] = make([]utils.Char, len(g[0])+2*len(g[0]))
	}

	for rowIdx := range newGrid {
		for i := 0; i < len(newGrid[0]); i += len(g[0]) {
			copy(newGrid[rowIdx][i:], g[rowIdx%len(g)])
		}
	}

	return newGrid
}

func parseGrid(r io.Reader) Grid {
	grid := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		grid = append(grid, []utils.Char(line))
		return nil
	})

	return grid
}
