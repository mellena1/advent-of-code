package main

import (
	"fmt"
	"io"
	"math"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)

	fmt.Printf("Part one solution: %d\n", grid.MinHeatLoss())
	fmt.Printf("Part two solution: %d\n", grid.MinHeatLossPart2())
}

type Grid [][]int

type connectionMapKey struct {
	Coor     utils.Coordinate
	Dir      utils.Direction
	numInDir int
}

func (g Grid) toConnectionMap() utils.ConnectionMap[connectionMapKey] {
	cMap := utils.ConnectionMap[connectionMapKey]{}
	directions := []utils.Direction{utils.UP, utils.DOWN, utils.LEFT, utils.RIGHT}

	cMap[connectionMapKey{
		Coor: utils.NewCoordinate(0, 0),
	}] = map[connectionMapKey]int{
		{utils.NewCoordinate(1, 0), utils.RIGHT, 1}: g[0][1],
		{utils.NewCoordinate(0, 1), utils.DOWN, 1}:  g[1][0],
	}

	for i, row := range g {
		for j := range row {
			if i == 0 && j == 0 {
				continue
			}
			coor := utils.NewCoordinate(j, i)
			for numInDir := 1; numInDir <= 3; numInDir++ {
				for _, dir := range directions {
					switch dir {
					case utils.DOWN:
						if i-numInDir < 0 {
							continue
						}
					case utils.UP:
						if i+numInDir >= len(g) {
							continue
						}
					case utils.RIGHT:
						if j-numInDir < 0 {
							continue
						}
					case utils.LEFT:
						if j+numInDir >= len(g[0]) {
							continue
						}
					}

					mapKey := connectionMapKey{
						Coor:     coor,
						Dir:      dir,
						numInDir: numInDir,
					}
					cMap[mapKey] = map[connectionMapKey]int{}

					// up
					if i-1 >= 0 {
						if dir == utils.UP && numInDir < 3 {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j, i-1),
								Dir:      utils.UP,
								numInDir: numInDir + 1,
							}
							cMap[mapKey][neighborMapKey] = g[i-1][j]
						} else if dir != utils.UP && dir != utils.DOWN {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j, i-1),
								Dir:      utils.UP,
								numInDir: 1,
							}
							cMap[mapKey][neighborMapKey] = g[i-1][j]
						}
					}
					// down
					if i+1 < len(g) {
						if dir == utils.DOWN && numInDir < 3 {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j, i+1),
								Dir:      utils.DOWN,
								numInDir: numInDir + 1,
							}
							cMap[mapKey][neighborMapKey] = g[i+1][j]
						} else if dir != utils.DOWN && dir != utils.UP {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j, i+1),
								Dir:      utils.DOWN,
								numInDir: 1,
							}
							cMap[mapKey][neighborMapKey] = g[i+1][j]
						}
					}
					// left
					if j-1 >= 0 {
						if dir == utils.LEFT && numInDir < 3 {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j-1, i),
								Dir:      utils.LEFT,
								numInDir: numInDir + 1,
							}
							cMap[mapKey][neighborMapKey] = g[i][j-1]
						} else if dir != utils.LEFT && dir != utils.RIGHT {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j-1, i),
								Dir:      utils.LEFT,
								numInDir: 1,
							}
							cMap[mapKey][neighborMapKey] = g[i][j-1]
						}
					}
					// right
					if j+1 < len(g[0]) {
						if dir == utils.RIGHT && numInDir < 3 {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j+1, i),
								Dir:      utils.RIGHT,
								numInDir: numInDir + 1,
							}
							cMap[mapKey][neighborMapKey] = g[i][j+1]
						} else if dir != utils.RIGHT && dir != utils.LEFT {
							neighborMapKey := connectionMapKey{
								Coor:     utils.NewCoordinate(j+1, i),
								Dir:      utils.RIGHT,
								numInDir: 1,
							}
							cMap[mapKey][neighborMapKey] = g[i][j+1]
						}
					}
				}
			}
		}
	}

	return cMap
}

func (g Grid) toConnectionMapPart2() utils.ConnectionMap[connectionMapKey] {
	cMap := utils.ConnectionMap[connectionMapKey]{}

	cMap[connectionMapKey{
		Coor: utils.NewCoordinate(0, 0),
	}] = map[connectionMapKey]int{
		{utils.NewCoordinate(1, 0), utils.RIGHT, 1}: g[0][1],
		{utils.NewCoordinate(0, 1), utils.DOWN, 1}:  g[1][0],
	}

	addConnections := func(mapKey connectionMapKey) {
		curDir := mapKey.Dir
		coor := mapKey.Coor
		numInDir := mapKey.numInDir

		// up
		upCoor := coor.MoveDir(utils.UP)
		if upCoor.Y >= 0 {
			if curDir == utils.UP {
				neighborMapKey := connectionMapKey{
					Coor:     upCoor,
					Dir:      utils.UP,
					numInDir: numInDir + 1,
				}
				cMap[mapKey][neighborMapKey] = g[upCoor.Y][upCoor.X]
			} else if curDir != utils.DOWN && numInDir >= 4 {
				neighborMapKey := connectionMapKey{
					Coor:     upCoor,
					Dir:      utils.UP,
					numInDir: 1,
				}
				cMap[mapKey][neighborMapKey] = g[upCoor.Y][upCoor.X]
			}
		}
		// down
		downCoor := coor.MoveDir(utils.DOWN)
		if downCoor.Y < len(g) {
			if curDir == utils.DOWN {
				neighborMapKey := connectionMapKey{
					Coor:     downCoor,
					Dir:      utils.DOWN,
					numInDir: numInDir + 1,
				}
				cMap[mapKey][neighborMapKey] = g[downCoor.Y][downCoor.X]
			} else if curDir != utils.UP && numInDir >= 4 {
				neighborMapKey := connectionMapKey{
					Coor:     downCoor,
					Dir:      utils.DOWN,
					numInDir: 1,
				}
				cMap[mapKey][neighborMapKey] = g[downCoor.Y][downCoor.X]
			}
		}
		// left
		leftCoor := coor.MoveDir(utils.LEFT)
		if leftCoor.X >= 0 {
			if curDir == utils.LEFT {
				neighborMapKey := connectionMapKey{
					Coor:     leftCoor,
					Dir:      utils.LEFT,
					numInDir: numInDir + 1,
				}
				cMap[mapKey][neighborMapKey] = g[leftCoor.Y][leftCoor.X]
			} else if curDir != utils.RIGHT && numInDir >= 4 {
				neighborMapKey := connectionMapKey{
					Coor:     leftCoor,
					Dir:      utils.LEFT,
					numInDir: 1,
				}
				cMap[mapKey][neighborMapKey] = g[leftCoor.Y][leftCoor.X]
			}
		}
		// right
		rightCoor := coor.MoveDir(utils.RIGHT)
		if rightCoor.X < len(g[0]) {
			if curDir == utils.RIGHT {
				neighborMapKey := connectionMapKey{
					Coor:     rightCoor,
					Dir:      utils.RIGHT,
					numInDir: numInDir + 1,
				}
				cMap[mapKey][neighborMapKey] = g[rightCoor.Y][rightCoor.X]
			} else if curDir != utils.LEFT && numInDir >= 4 {
				neighborMapKey := connectionMapKey{
					Coor:     rightCoor,
					Dir:      utils.RIGHT,
					numInDir: 1,
				}
				cMap[mapKey][neighborMapKey] = g[rightCoor.Y][rightCoor.X]
			}
		}
	}

	for i, row := range g {
		for j := range row {
			if i == 0 && j == 0 {
				continue
			}

			coor := utils.NewCoordinate(j, i)

			// coming from left
			for x := j - 1; x >= 0 && j-x <= 10; x-- {
				mapKey := connectionMapKey{
					Coor:     coor,
					Dir:      utils.RIGHT,
					numInDir: j - x,
				}
				cMap[mapKey] = map[connectionMapKey]int{}
				addConnections(mapKey)
			}

			// coming from right
			for x := j + 1; x < len(row) && x-j <= 10; x++ {
				mapKey := connectionMapKey{
					Coor:     coor,
					Dir:      utils.LEFT,
					numInDir: x - j,
				}
				cMap[mapKey] = map[connectionMapKey]int{}
				addConnections(mapKey)
			}

			// coming from up
			for y := i - 1; y >= 0 && i-y <= 10; y-- {
				mapKey := connectionMapKey{
					Coor:     coor,
					Dir:      utils.DOWN,
					numInDir: i - y,
				}
				cMap[mapKey] = map[connectionMapKey]int{}
				addConnections(mapKey)
			}

			// coming from down
			for y := i + 1; y < len(g) && y-i <= 10; y++ {
				mapKey := connectionMapKey{
					Coor:     coor,
					Dir:      utils.UP,
					numInDir: y - i,
				}
				cMap[mapKey] = map[connectionMapKey]int{}
				addConnections(mapKey)
			}
		}
	}

	return cMap
}

func (g Grid) MinHeatLoss() int {
	cMap := g.toConnectionMap()

	dist, _ := cMap.Dijkstra(connectionMapKey{
		Coor: utils.NewCoordinate(0, 0),
	})

	destCoor := utils.NewCoordinate(len(g)-1, len(g[0])-1)

	minDistDest := math.MaxInt
	for key, d := range dist {
		if d > 0 && key.Coor == destCoor && d < minDistDest {
			minDistDest = d
		}
	}

	return minDistDest
}

func (g Grid) MinHeatLossPart2() int {
	cMap := g.toConnectionMapPart2()

	source := connectionMapKey{
		Coor: utils.NewCoordinate(0, 0),
	}

	dist, _ := cMap.Dijkstra(source)

	destCoor := utils.NewCoordinate(len(g)-1, len(g[0])-1)

	minDistDest := math.MaxInt
	for key, d := range dist {
		if d > 0 && key.Coor == destCoor && d < minDistDest {
			minDistDest = d
		}
	}

	return minDistDest
}

//nolint:golint,unused
func (g Grid) printPath(source, destination connectionMapKey, prev map[connectionMapKey]connectionMapKey) {
	path := map[utils.Coordinate]connectionMapKey{}

	curNode := destination
	for curNode != source {
		path[curNode.Coor] = curNode
		curNode = prev[curNode]
	}
	path[source.Coor] = source

	for i, row := range g {
		for j, v := range row {
			if mapKey, ok := path[utils.NewCoordinate(j, i)]; ok {
				switch mapKey.Dir {
				case utils.UP:
					fmt.Print("^")
				case utils.DOWN:
					fmt.Print("v")
				case utils.LEFT:
					fmt.Print("<")
				case utils.RIGHT:
					fmt.Print(">")
				}
				continue
			}
			fmt.Print(v)
		}
		fmt.Println()
	}
}

func parseGrid(r io.Reader) Grid {
	grid := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		intSlice, err := utils.StrSliceToIntSlice(utils.SliceMap([]rune(line), func(v rune) string { return string(v) }))
		if err != nil {
			return fmt.Errorf("failed to parse line as int slice %q: %w", line, err)
		}

		grid = append(grid, intSlice)
		return nil
	})

	return grid
}
