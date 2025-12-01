package main

import (
	"fmt"
	"io"
	"slices"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

type Axis utils.Char

const (
	XAxis Axis = 'X'
	YAxis Axis = 'Y'
	ZAxis Axis = 'Z'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	bricks := parseBricks(f)
	bricks.MoveAllDown()
	fmt.Printf("Part one solution: %d\n", bricks.NumCanBeDisintegrated())
	fmt.Printf("Part two solution: %d\n", bricks.NumBricksThatWouldFall())
}

type Bricks []Brick

func (b Bricks) NumCanBeDisintegrated() int {
	num := 0
	bricksWithoutI := make(Bricks, len(b)-1)

	for i := range b {
		copy(bricksWithoutI[:i], b[:i])
		copy(bricksWithoutI[i:], b[i+1:])

		canBeRemoved := true
		for _, brick := range bricksWithoutI {
			if brick.CanMoveDown(bricksWithoutI) {
				canBeRemoved = false
				break
			}
		}
		if canBeRemoved {
			num++
		}
	}
	return num
}

func (b Bricks) NumBricksThatWouldFall() int {
	num := 0
	bricksWithoutI := make(Bricks, len(b)-1)

	for i := range b {
		copy(bricksWithoutI[:i], b[:i])
		copy(bricksWithoutI[i:], b[i+1:])

		num += bricksWithoutI.MoveAllDown()
	}
	return num
}

func (b Bricks) MoveAllDown() int {
	slices.SortFunc(b, func(a, b Brick) int {
		return a.Start.Z - b.Start.Z
	})

	numMovedDown := 0
	for i, brick := range b {
		countedMove := false
		for brick.CanMoveDown(b) {
			brick = brick.Add(ZAxis, -1)
			b[i] = brick
			if !countedMove {
				numMovedDown++
				countedMove = true
			}
		}
	}

	return numMovedDown
}

type Brick struct {
	Start utils.Coordinate3D[int]
	End   utils.Coordinate3D[int]
	Axis  Axis
}

func (b Brick) ForEachCoor(f func(c utils.Coordinate3D[int]) bool) {
	switch b.Axis {
	case XAxis:
		for x := b.Start.X; x <= b.End.X; x++ {
			shouldBreak := f(utils.NewCoordinate3D(x, b.Start.Y, b.Start.Z))
			if shouldBreak {
				return
			}
		}
	case YAxis:
		for y := b.Start.Y; y <= b.End.Y; y++ {
			shouldBreak := f(utils.NewCoordinate3D(b.Start.X, y, b.Start.Z))
			if shouldBreak {
				return
			}
		}
	case ZAxis:
		for z := b.Start.Z; z <= b.End.Z; z++ {
			shouldBreak := f(utils.NewCoordinate3D(b.Start.X, b.Start.Y, z))
			if shouldBreak {
				return
			}
		}
	default:
		// case where the block is 1x1
		f(b.Start)
	}
}

func (b Brick) Add(axis Axis, num int) Brick {
	newBrick := Brick{
		Axis: b.Axis,
	}

	switch axis {
	case XAxis:
		newBrick.Start = b.Start.Translate(num, 0, 0)
		newBrick.End = b.End.Translate(num, 0, 0)
	case YAxis:
		newBrick.Start = b.Start.Translate(0, num, 0)
		newBrick.End = b.End.Translate(0, num, 0)
	case ZAxis:
		newBrick.Start = b.Start.Translate(0, 0, num)
		newBrick.End = b.End.Translate(0, 0, num)
	}

	return newBrick
}

func (b Brick) Intersects(c utils.Coordinate3D[int]) bool {
	return c.X >= b.Start.X && c.X <= b.End.X && c.Y >= b.Start.Y && c.Y <= b.End.Y && c.Z >= b.Start.Z && c.Z <= b.End.Z
}

func (b Brick) CanMoveDown(bricks Bricks) bool {
	movedBrick := b.Add(ZAxis, -1)

	if movedBrick.Start.Z < 1 {
		return false
	}

	noIntersections := true
	movedBrick.ForEachCoor(func(c utils.Coordinate3D[int]) bool {
		for _, otherBrick := range bricks {
			if otherBrick == b {
				continue
			}

			if otherBrick.Intersects(c) {
				noIntersections = false
				return true
			}
		}

		return false
	})

	return noIntersections
}

func parseBricks(r io.Reader) Bricks {
	bricks := Bricks{}

	utils.ExecutePerLine(r, func(line string) error {
		startCoor, endCoor, _ := strings.Cut(line, "~")

		start, err := strCoorTo3DCoor(startCoor)
		if err != nil {
			return err
		}
		end, err := strCoorTo3DCoor(endCoor)
		if err != nil {
			return err
		}

		newBrick := Brick{
			Start: start,
			End:   end,
		}

		if start.X != end.X {
			newBrick.Axis = XAxis
		}
		if start.Y != end.Y {
			newBrick.Axis = YAxis
		}
		if start.Z != end.Z {
			newBrick.Axis = ZAxis
		}

		bricks = append(bricks, newBrick)

		return nil
	})

	return bricks
}

func strCoorTo3DCoor(s string) (utils.Coordinate3D[int], error) {
	nums, err := utils.StrSliceToIntSlice(strings.Split(s, ","))
	if err != nil {
		return utils.Coordinate3D[int]{}, err
	}

	return utils.NewCoordinate3D(nums[0], nums[1], nums[2]), nil
}
