package main

import (
	"fmt"
	"io"
	"slices"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	PATH        = '.'
	FOREST      = '#'
	SLOPE_RIGHT = '>'
	SLOPE_LEFT  = '<'
	SLOPE_UP    = '^'
	SLOPE_DOWN  = 'v'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)
	cMap := grid.toConnectionMap()

	startCoor := utils.NewCoordinate(1, 0)
	destCoor := utils.NewCoordinate(len(grid[0])-2, len(grid)-1)

	steps, _ := cMap.LongestDijkstraWithDest(startCoor, destCoor)
	fmt.Printf("Part one solution: %d\n", steps)

	grid.removeSlopes()
	cMapP2 := grid.toConnectionMap()
	cMapP2 = dedupConnectionMap(cMapP2, startCoor)
	fmt.Printf("Part two solution: %d\n", LongestPath(cMapP2, startCoor, destCoor))
}

func LongestPath(cMap utils.ConnectionMap[utils.Coordinate], source, dest utils.Coordinate) int {
	longestPath := 0
	var dfs func(curNode utils.Coordinate, visited []utils.Coordinate, steps int)
	dfs = func(curNode utils.Coordinate, visited []utils.Coordinate, steps int) {
		if curNode == dest {
			if steps > longestPath {
				longestPath = steps
			}
			return
		}
		for neighbor, dist := range cMap[curNode] {
			if slices.Contains(visited, neighbor) {
				continue
			}

			dfs(neighbor, append(visited, curNode), steps+dist)
		}
	}

	dfs(source, []utils.Coordinate{}, 0)

	return longestPath
}

func dedupConnectionMap[K comparable](cMap utils.ConnectionMap[K], start K) utils.ConnectionMap[K] {
	intersections := []K{}

	for k, v := range cMap {
		if len(v) >= 3 {
			intersections = append(intersections, k)
		}
	}

	var findNextIntersection func(curNode K, prev K, numSteps int) (K, int)
	findNextIntersection = func(curNode, prev K, numSteps int) (K, int) {
		if len(cMap[curNode]) != 2 {
			return curNode, numSteps
		}

		var next K
		for neighbor := range cMap[curNode] {
			if neighbor == prev {
				continue
			}
			next = neighbor
			break
		}
		return findNextIntersection(next, curNode, numSteps+1)
	}

	newCMap := utils.ConnectionMap[K]{}
	for _, node := range intersections {
		newCMap[node] = map[K]int{}

		for neighbor := range cMap[node] {
			next, steps := findNextIntersection(neighbor, node, 1)
			newCMap[node][next] = steps

			if _, ok := newCMap[next]; !ok {
				newCMap[next] = map[K]int{}
			}
			newCMap[next][node] = steps
		}
	}

	return newCMap
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

	return s[:len(s)-1]
}

func (g Grid) StringWithPath(path []utils.Coordinate) string {
	s := ""

	for i, row := range g {
		for j, v := range row {
			if slices.Contains(path, utils.NewCoordinate(j, i)) {
				s += "O"
			} else {
				s += string(v)
			}
		}
		s += "\n"
	}

	return s[:len(s)-1]
}

func (g Grid) removeSlopes() {
	for i, row := range g {
		for j, v := range row {
			switch v {
			case PATH, FOREST:
			default:
				g[i][j] = PATH
			}
		}
	}
}

func (g Grid) toConnectionMap() utils.ConnectionMap[utils.Coordinate] {
	cMap := utils.ConnectionMap[utils.Coordinate]{}

	for i, row := range g {
		for j, v := range row {
			if v == FOREST {
				continue
			}

			coor := utils.NewCoordinate(j, i)
			cMap[coor] = map[utils.Coordinate]int{}

			switch v {
			case PATH:
				for k := -1; k <= 1; k++ {
					if k == 0 {
						continue
					}

					yCoor := coor.Y + k
					if yCoor >= 0 && yCoor < len(g) {
						if g[yCoor][coor.X] != FOREST {
							if (k == -1 && g[yCoor][coor.X] != SLOPE_DOWN) || (k == 1 && g[yCoor][coor.X] != SLOPE_UP) {
								cMap[coor][utils.NewCoordinate(coor.X, yCoor)] = 1
							}
						}
					}

					xCoor := coor.X + k
					if xCoor >= 0 && xCoor < len(g[coor.Y]) {
						if g[coor.Y][xCoor] != FOREST {
							if (k == -1 && g[coor.Y][xCoor] != SLOPE_RIGHT) || (k == 1 && g[coor.Y][xCoor] != SLOPE_LEFT) {
								cMap[coor][utils.NewCoordinate(xCoor, coor.Y)] = 1
							}
						}
					}
				}
			case SLOPE_RIGHT:
				cMap[coor][utils.NewCoordinate(coor.X+1, coor.Y)] = 1
			case SLOPE_LEFT:
				cMap[coor][utils.NewCoordinate(coor.X-1, coor.Y)] = 1
			case SLOPE_UP:
				cMap[coor][utils.NewCoordinate(coor.X, coor.Y-1)] = 1
			case SLOPE_DOWN:
				cMap[coor][utils.NewCoordinate(coor.X, coor.Y+1)] = 1
			}
		}
	}

	return cMap
}

func parseGrid(r io.Reader) Grid {
	g := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		g = append(g, []utils.Char(line))
		return nil
	})

	return g
}
