package utils

import (
	"fmt"
)

type Coordinate struct {
	X int
	Y int
}

func NewCoordinate(x int, y int) Coordinate {
	return Coordinate{X: x, Y: y}
}

func (c Coordinate) Add(c2 Coordinate) Coordinate {
	return NewCoordinate(c.X+c2.X, c.Y+c2.Y)
}

func (c Coordinate) Sub(c2 Coordinate) Coordinate {
	return NewCoordinate(c.X-c2.X, c.Y-c2.Y)
}

func (c Coordinate) MoveDir(dir Direction) Coordinate {
	return c.Add(Coordinate(dir))
}

func (c Coordinate) String() string {
	return fmt.Sprintf("(%d, %d)", c.X, c.Y)
}

func (c Coordinate) StepsToCoordinate(c2 Coordinate) int {
	xDiff := c.X - c2.X
	if xDiff < 0 {
		xDiff *= -1
	}

	yDiff := c.Y - c2.Y
	if yDiff < 0 {
		yDiff *= -1
	}

	return xDiff + yDiff
}

type Direction Coordinate

var (
	UP    = Direction(NewCoordinate(0, -1))
	DOWN  = Direction(NewCoordinate(0, 1))
	LEFT  = Direction(NewCoordinate(-1, 0))
	RIGHT = Direction(NewCoordinate(1, 0))
)

func (d Direction) String() string {
	switch d {
	case UP:
		return "UP"
	case DOWN:
		return "DOWN"
	case LEFT:
		return "LEFT"
	case RIGHT:
		return "RIGHT"
	}
	return ""
}

type Number interface {
	int | float64
}

type Coordinate3D[T Number] struct {
	X T
	Y T
	Z T
}

func NewCoordinate3D[T Number](x, y, z T) Coordinate3D[T] {
	return Coordinate3D[T]{
		X: x,
		Y: y,
		Z: z,
	}
}

func (c Coordinate3D[T]) Translate(x, y, z T) Coordinate3D[T] {
	return NewCoordinate3D(c.X+x, c.Y+y, c.Z+z)
}

func (c Coordinate3D[T]) String() string {
	return fmt.Sprintf("(%v, %v, %v)", c.X, c.Y, c.Z)
}
