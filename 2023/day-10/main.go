package main

import (
	"fmt"
	"io"
	"slices"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	grid, sLocation := parseGrid(f)

	loop := findLoop(grid, sLocation)

	fmt.Printf("Part one solution: %d\n", loop.furthestFromStart())
	fmt.Printf("Part two solution: %d\n", grid.findAreaInsideLoop(loop))
}

type Node struct {
	attachedNodes []*Node
	coor          utils.Coordinate
	r             rune
}

func NewNode(coor utils.Coordinate, r rune) *Node {
	return &Node{
		attachedNodes: []*Node{},
		coor:          coor,
		r:             r,
	}
}

func (n *Node) nextNode(last *Node) *Node {
	for _, attached := range n.attachedNodes {
		if attached != last {
			return attached
		}
	}
	// should never get here
	return nil
}

func (n *Node) furthestFromStart() int {
	lastLeft, lastRight := n, n
	left, right := n.attachedNodes[0], n.attachedNodes[1]

	steps := 1
	for left != right {
		newLeft := left.nextNode(lastLeft)
		lastLeft, left = left, newLeft

		newRight := right.nextNode(lastRight)
		lastRight, right = right, newRight

		steps++
	}

	return steps
}

type Direction utils.Coordinate

var (
	LEFT  = Direction(utils.NewCoordinate(-1, 0))
	RIGHT = Direction(utils.NewCoordinate(1, 0))
	UP    = Direction(utils.NewCoordinate(0, -1))
	DOWN  = Direction(utils.NewCoordinate(0, 1))
)

var PossibleNextPipes = map[Direction][]rune{
	UP:    {'F', '7', '|'},
	DOWN:  {'L', 'J', '|'},
	LEFT:  {'F', 'L', '-'},
	RIGHT: {'7', 'J', '-'},
}

var PipeAttachments = map[rune][]Direction{
	'|': {UP, DOWN},
	'-': {LEFT, RIGHT},
	'L': {UP, RIGHT},
	'J': {LEFT, UP},
	'7': {LEFT, DOWN},
	'F': {RIGHT, DOWN},
	'S': {UP, DOWN, LEFT, RIGHT},
}

func findLoop(grid Grid, startingLocation utils.Coordinate) *Node {
	sNode := NewNode(startingLocation, grid.get(startingLocation).r)
	foundLoop := false

	var dfs func(curNode *Node, coor utils.Coordinate, lastCoor utils.Coordinate) bool
	dfs = func(curNode *Node, coor utils.Coordinate, lastCoor utils.Coordinate) bool {
		if foundLoop {
			return false
		}

		gridNode := grid.get(coor)

		for _, direction := range PipeAttachments[gridNode.r] {
			newCoor := utils.NewCoordinate(coor.X+direction.X, coor.Y+direction.Y)

			if newCoor.X < 0 || newCoor.X >= len(grid[0]) || newCoor.Y < 0 || newCoor.Y >= len(grid) {
				// out of bounds
				continue
			}
			if newCoor.X == lastCoor.X && newCoor.Y == lastCoor.Y {
				// don't go backwards
				continue
			}

			neighbor := grid.get(newCoor)

			if neighbor.r == 'S' {
				foundLoop = true
				curNode.attachedNodes = append(curNode.attachedNodes, sNode)
				sNode.attachedNodes = append(sNode.attachedNodes, curNode)
				return true
			}

			if slices.Contains(PossibleNextPipes[direction], neighbor.r) {
				newNode := NewNode(newCoor, neighbor.r)
				foundS := dfs(newNode, newCoor, coor)

				if foundS {
					curNode.attachedNodes = append(curNode.attachedNodes, newNode)
					newNode.attachedNodes = append(newNode.attachedNodes, curNode)
					return true
				}
			}
		}

		return false
	}

	dfs(sNode, startingLocation, utils.NewCoordinate(-1, -1))

	sNode.r = findPipeUnderS(sNode)

	return sNode
}

func findPipeUnderS(sNode *Node) rune {
	sDirections := []Direction{}

	for _, attachment := range sNode.attachedNodes {
		dir := findDirection(sNode.coor, attachment.coor)
		sDirections = append(sDirections, dir)
	}
OUTER:
	for pipe, directions := range PipeAttachments {
		for _, d := range directions {
			if !slices.Contains(sDirections, d) {
				continue OUTER
			}
		}
		return pipe
	}

	panic("invalid pipe arrangement")
}

func isCorner(r rune) bool {
	switch r {
	case 'L', 'J', '7', 'F':
		return true
	}
	return false
}

type Grid [][]GridNode

func (g Grid) get(coor utils.Coordinate) *GridNode {
	return &g[coor.Y][coor.X]
}

func (g Grid) markLoopNodes(startNode *Node) {
	g.get(startNode.coor).inLoop = true

	lastNode := startNode
	curNode := startNode.attachedNodes[0]
	for curNode != startNode {
		g.get(curNode.coor).inLoop = true

		newNode := curNode.nextNode(lastNode)
		lastNode, curNode = curNode, newNode
	}
}

var Rotations = map[rune]map[Direction]Direction{
	'7': {
		DOWN:  LEFT,
		RIGHT: UP,
	},
	'J': {
		LEFT: UP,
		DOWN: RIGHT,
	},
	'L': {
		LEFT: DOWN,
		UP:   RIGHT,
	},
	'F': {
		RIGHT: DOWN,
		UP:    LEFT,
	},
}

func (g Grid) findAreaInsideLoop(startNode *Node) int {
	g.markLoopNodes(startNode)

	// replace S with actual val
	g.get(startNode.coor).r = startNode.r

	// should always be a F
	leftCorner := g.findTopLeft(startNode)

	lastNode := leftCorner
	curNode := leftCorner
	for _, attach := range curNode.attachedNodes {
		if attach.coor.X > curNode.coor.X {
			curNode = attach
			break
		}
	}

	markNodesAsTouched := func(curNode *Node, dir Direction) {
		switch dir {
		case DOWN:
			for i := curNode.coor.Y + 1; i < len(g); i++ {
				gNode := g.get(utils.NewCoordinate(curNode.coor.X, i))

				if gNode.inLoop {
					break
				}

				gNode.isInLoop = true
			}
		case UP:
			for i := curNode.coor.Y - 1; i >= 0; i-- {
				gNode := g.get(utils.NewCoordinate(curNode.coor.X, i))

				if gNode.inLoop {
					break
				}

				gNode.isInLoop = true
			}
		case LEFT:
			for i := curNode.coor.X - 1; i >= 0; i-- {
				gNode := g.get(utils.NewCoordinate(i, curNode.coor.Y))

				if gNode.inLoop {
					break
				}

				gNode.isInLoop = true
			}
		case RIGHT:
			for i := curNode.coor.X + 1; i < len(g[curNode.coor.Y]); i++ {
				gNode := g.get(utils.NewCoordinate(i, curNode.coor.Y))

				if gNode.inLoop {
					break
				}

				gNode.isInLoop = true
			}
		}
	}

	curInsideDirection := DOWN

	for curNode != leftCorner {
		markNodesAsTouched(curNode, curInsideDirection)

		if isCorner(curNode.r) {
			curInsideDirection = Rotations[curNode.r][curInsideDirection]
			markNodesAsTouched(curNode, curInsideDirection)
		}

		newNode := curNode.nextNode(lastNode)
		lastNode, curNode = curNode, newNode
	}

	area := 0
	for i := 0; i < len(g); i++ {
		for j := 0; j < len(g[i]); j++ {
			gNode := g.get(utils.NewCoordinate(j, i))
			if gNode.isInLoop {
				area++
			}
		}
	}

	return area
}

func (g Grid) findTopLeft(loop *Node) *Node {
	for i := 0; i < len(g); i++ {
		for j := 0; j < len(g[i]); j++ {
			if g[i][j].inLoop {
				lastNode := loop
				curNode := loop.attachedNodes[0]
				if loop.coor.X == j && loop.coor.Y == i && isCorner(loop.r) {
					return loop
				}

				for lastNode != curNode {
					if curNode.coor.X == j && curNode.coor.Y == i && isCorner(curNode.r) {
						return curNode
					}

					nextNode := curNode.nextNode(lastNode)
					lastNode, curNode = curNode, nextNode
				}
			}
		}
	}

	panic("there should be a top left node")
}

type GridNode struct {
	r        rune
	isInLoop bool
	inLoop   bool
}

func findDirection(c1, c2 utils.Coordinate) Direction {
	return Direction{
		X: c2.X - c1.X,
		Y: c2.Y - c1.Y,
	}
}

func parseGrid(r io.Reader) (Grid, utils.Coordinate) {
	grid := Grid{}
	var coor utils.Coordinate

	y := 0
	utils.ExecutePerLine(r, func(line string) error {
		nodes := make([]GridNode, len(line))
		for i, r := range line {
			nodes[i] = GridNode{
				r:        r,
				isInLoop: false,
			}
			if r == 'S' {
				coor = utils.NewCoordinate(i, y)
			}
		}
		y++

		grid = append(grid, nodes)
		return nil
	})

	return grid, coor
}
