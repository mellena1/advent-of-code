package main

import (
	"fmt"
	"io"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	VERT_SPLITTER    utils.Char = '|'
	HORIZ_SPLITTER   utils.Char = '-'
	EMPTY            utils.Char = '.'
	CLOCKWISE_MIRROR utils.Char = '/'
	COUNTER_MIRROR   utils.Char = '\\'
)

type Direction utils.Coordinate

var (
	UP    = Direction(utils.NewCoordinate(0, -1))
	DOWN  = Direction(utils.NewCoordinate(0, 1))
	LEFT  = Direction(utils.NewCoordinate(-1, 0))
	RIGHT = Direction(utils.NewCoordinate(1, 0))
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid := parseGrid(f)
	fmt.Printf("Part one solution: %d\n", grid.CountEnergized(utils.NewCoordinate(0, 0), RIGHT))
	fmt.Printf("Part two solution: %d\n", grid.MaxEnergizedFromAllStartingPoints())
}

var SpaceInteractions = map[utils.Char]map[Direction][]Direction{
	VERT_SPLITTER: {
		RIGHT: {UP, DOWN},
		LEFT:  {UP, DOWN},
		UP:    {UP},
		DOWN:  {DOWN},
	},
	HORIZ_SPLITTER: {
		RIGHT: {RIGHT},
		LEFT:  {LEFT},
		UP:    {LEFT, RIGHT},
		DOWN:  {LEFT, RIGHT},
	},
	EMPTY: {
		RIGHT: {RIGHT},
		LEFT:  {LEFT},
		UP:    {UP},
		DOWN:  {DOWN},
	},
	CLOCKWISE_MIRROR: {
		RIGHT: {UP},
		LEFT:  {DOWN},
		UP:    {RIGHT},
		DOWN:  {LEFT},
	},
	COUNTER_MIRROR: {
		RIGHT: {DOWN},
		LEFT:  {UP},
		UP:    {LEFT},
		DOWN:  {RIGHT},
	},
}

type Grid [][]utils.Char

func (g Grid) CountEnergized(startingCoor utils.Coordinate, startingDirection Direction) int {
	energized := make([][]bool, len(g))
	for i := range energized {
		energized[i] = make([]bool, len(g[0]))
	}

	type CoorAndDirection struct {
		Coor utils.Coordinate
		Dir  Direction
	}

	var traverse func(coor utils.Coordinate, direction Direction, touched map[CoorAndDirection]bool)
	traverse = func(coor utils.Coordinate, direction Direction, touched map[CoorAndDirection]bool) {
		x := coor.X
		y := coor.Y

		if x < 0 || y < 0 || x >= len(g[0]) || y >= len(g) {
			return
		}

		// avoid cycles
		coorAndDir := CoorAndDirection{Coor: coor, Dir: direction}
		if _, ok := touched[coorAndDir]; ok {
			return
		}
		touched[coorAndDir] = true

		energized[y][x] = true

		newDirections := SpaceInteractions[g[y][x]][direction]
		for _, newDir := range newDirections {
			traverse(coor.Add(utils.Coordinate(newDir)), newDir, touched)
		}
	}

	traverse(startingCoor, startingDirection, map[CoorAndDirection]bool{})

	sum := 0
	for _, row := range energized {
		for _, isEnergized := range row {
			if isEnergized {
				sum++
			}
		}
	}
	return sum
}

func (g Grid) MaxEnergizedFromAllStartingPoints() int {
	maxConfig := 0

	for x := range g[0] {
		if count := g.CountEnergized(utils.NewCoordinate(x, 0), DOWN); count > maxConfig {
			maxConfig = count
		}
		if count := g.CountEnergized(utils.NewCoordinate(x, len(g)-1), UP); count > maxConfig {
			maxConfig = count
		}
	}

	for y := range g {
		if count := g.CountEnergized(utils.NewCoordinate(0, y), RIGHT); count > maxConfig {
			maxConfig = count
		}
		if count := g.CountEnergized(utils.NewCoordinate(len(g[0])-1, y), LEFT); count > maxConfig {
			maxConfig = count
		}
	}

	return maxConfig
}

func parseGrid(r io.Reader) Grid {
	grid := Grid{}

	utils.ExecutePerLine(r, func(line string) error {
		grid = append(grid, []utils.Char(line))
		return nil
	})

	return grid
}
