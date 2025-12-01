package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
	"github.com/shopspring/decimal"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	hailstones := parseHailstones(f)
	fmt.Printf("Part one solution: %d\n", hailstones.NumIntersections2D(200000000000000, 400000000000000))

	threeHailstones, err := findThreeHailstones(hailstones)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	rock := findRock(threeHailstones)
	fmt.Println(rock)
	fmt.Printf("Part two solution: %d\n", rock.Pos.X+rock.Pos.Y+rock.Pos.Z)
}

type Hailstones []Hailstone

func (h Hailstones) NumIntersections2D(minPos, maxPos int) int {
	type intersection struct {
		h1Idx int
		h2Idx int
		t1    float64
		t2    float64
	}

	possibleIntersections := []intersection{}

	for i, h1 := range h {
		for j, h2 := range h {
			if i <= j {
				continue
			}

			t1, t2, doIntersect := intersectionOf2DVectors([]int{h1.Pos.X, h1.Pos.Y}, []int{h1.Vel.X, h1.Vel.Y}, []int{h2.Pos.X, h2.Pos.Y}, []int{h2.Vel.X, h2.Vel.Y})
			if !doIntersect || t1 < 0 || t2 < 0 {
				continue
			}

			pos := h1.PosAtTime(t1)
			if int(pos.X) < minPos || int(pos.X) > maxPos || int(pos.Y) < minPos || int(pos.Y) > maxPos {
				continue
			}

			possibleIntersections = append(possibleIntersections, intersection{h1Idx: i, h2Idx: j, t1: t1, t2: t2})
		}
	}

	return len(possibleIntersections)
}

type Velocities utils.Coordinate3D[int]

func (v Velocities) Equal(v2 Velocities) bool {
	return v.X == v2.X && v.Y == v2.Y && v.Z == v2.Z
}

type Hailstone struct {
	Pos utils.Coordinate3D[int]
	Vel Velocities
}

func (h Hailstone) PosAtTime(t float64) utils.Coordinate3D[float64] {
	return utils.NewCoordinate3D(float64(h.Pos.X)+float64(h.Vel.X)*t, float64(h.Pos.Y)+float64(h.Vel.Y)*t, float64(h.Pos.Z)+float64(h.Vel.Z)*t)
}

func parseHailstones(r io.Reader) Hailstones {
	hailstones := []Hailstone{}

	utils.ExecutePerLine(r, func(line string) error {
		pos, vel, _ := strings.Cut(line, " @ ")

		posInts, err := posOrVelToInts(pos)
		if err != nil {
			return err
		}

		velInts, err := posOrVelToInts(vel)
		if err != nil {
			return err
		}

		hailstones = append(hailstones, Hailstone{
			Pos: utils.NewCoordinate3D(posInts[0], posInts[1], posInts[2]),
			Vel: Velocities(utils.NewCoordinate3D(velInts[0], velInts[1], velInts[2])),
		})

		return nil
	})

	return hailstones
}

func posOrVelToInts(s string) ([]int, error) {
	spl := strings.Split(s, ",")
	tSpl := utils.SliceMap(spl, func(v string) string {
		return strings.TrimSpace(v)
	})
	return utils.StrSliceToIntSlice(tSpl)
}

func intersectionOf2DVectors(p1 []int, v1 []int, p2 []int, v2 []int) (float64, float64, bool) {
	// https://math.stackexchange.com/a/406895
	c := []int{p2[0] - p1[0], p2[1] - p1[1]}

	dt := float64(c[1]*v2[0] - c[0]*v2[1])
	du := float64(v1[0]*c[1] - v1[1]*c[0])
	d := float64(v1[1]*v2[0] - v1[0]*v2[1])

	return dt / d, du / d, d != 0
}

func findThreeHailstones(hailstones Hailstones) (Hailstones, error) {
	for i := 0; i < len(hailstones)-2; i++ {
		a := hailstones[i]
		for j := i + 1; j < len(hailstones)-1; j++ {
			b := hailstones[j]
			if a.Vel.Equal(b.Vel) {
				continue
			}
			for k := j + 1; k < len(hailstones); k++ {
				c := hailstones[k]
				if a.Vel.Equal(c.Vel) || b.Vel.Equal(c.Vel) {
					continue
				}
				return Hailstones{a, b, c}, nil
			}
		}
	}
	return nil, fmt.Errorf("no matches found")
}

func gaussElim(m [][]decimal.Decimal) {
	for i := 0; i < len(m); i++ {
		factor := m[i][i]
		for j := 0; j < len(m[i]); j++ {
			m[i][j] = m[i][j].DivRound(factor, 100)
		}

		for k := 0; k < len(m); k++ {
			if k == i {
				continue
			}

			factor2 := m[k][i].Neg()
			for j := 0; j < len(m[k]); j++ {
				m[k][j] = m[k][j].Add(factor2.Mul(m[i][j]))
			}
		}
	}
}

func findRock(hailstones Hailstones) Hailstone {
	// used https://github.com/DeadlyRedCube/AdventOfCode/blob/1f9d0a3e3b7e7821592244ee51bce5c18cf899ff/2023/AOC2023/D24.h#L66-L294 as the baseline for figuring out the math
	// basically you need 3 hailstones to calc what the rock's vector should look like, since you get 9 equations with 9 vars, which is solvable
	// the problem with those 3 is you have v*t[i] in each equation, which makes them unsolvable with linear algebra. you can solve for t[i] in each,
	// and use that to substitute values for t[i] into each, giving you equations with 6 vars total, and you can do some algebra to rearrange them to end
	// with linear equations. m below is the outcome of doing so and putting it into a matrix, and then we can use gaussian elimination to solve.
	// we need to use BigDecimal to maintain enough precision because the numbers are so large.

	a := hailstones[0]
	b := hailstones[1]
	c := hailstones[2]

	m := [][]int{
		{b.Vel.Y - a.Vel.Y, a.Vel.X - b.Vel.X, 0, a.Pos.Y - b.Pos.Y, b.Pos.X - a.Pos.X, 0, a.Pos.Y*a.Vel.X - b.Pos.Y*b.Vel.X + b.Pos.X*b.Vel.Y - a.Pos.X*a.Vel.Y},
		{c.Vel.Y - a.Vel.Y, a.Vel.X - c.Vel.X, 0, a.Pos.Y - c.Pos.Y, c.Pos.X - a.Pos.X, 0, a.Pos.Y*a.Vel.X - c.Pos.Y*c.Vel.X + c.Pos.X*c.Vel.Y - a.Pos.X*a.Vel.Y},
		{b.Vel.Z - a.Vel.Z, 0, a.Vel.X - b.Vel.X, a.Pos.Z - b.Pos.Z, 0, b.Pos.X - a.Pos.X, a.Vel.X*a.Pos.Z - b.Vel.X*b.Pos.Z + b.Pos.X*b.Vel.Z - a.Pos.X*a.Vel.Z},
		{c.Vel.Z - a.Vel.Z, 0, a.Vel.X - c.Vel.X, a.Pos.Z - c.Pos.Z, 0, c.Pos.X - a.Pos.X, a.Vel.X*a.Pos.Z - c.Vel.X*c.Pos.Z + c.Pos.X*c.Vel.Z - a.Pos.X*a.Vel.Z},
		{0, b.Vel.Z - a.Vel.Z, a.Vel.Y - b.Vel.Y, 0, a.Pos.Z - b.Pos.Z, b.Pos.Y - a.Pos.Y, a.Pos.Z*a.Vel.Y - b.Pos.Z*b.Vel.Y + b.Vel.Z*b.Pos.Y - a.Vel.Z*a.Pos.Y},
		{0, c.Vel.Z - a.Vel.Z, a.Vel.Y - c.Vel.Y, 0, a.Pos.Z - c.Pos.Z, c.Pos.Y - a.Pos.Y, a.Pos.Z*a.Vel.Y - c.Pos.Z*c.Vel.Y + c.Vel.Z*c.Pos.Y - a.Vel.Z*a.Pos.Y},
	}

	mBig := utils.SliceMap(m, func(s []int) []decimal.Decimal {
		return utils.SliceMap(s, func(v int) decimal.Decimal {
			return decimal.NewFromInt(int64(v))
		})
	})

	gaussElim(mBig)

	x := []decimal.Decimal{
		mBig[0][6],
		mBig[1][6],
		mBig[2][6],
		mBig[3][6],
		mBig[4][6],
		mBig[5][6],
	}

	decimalToInt := func(d decimal.Decimal) int {
		return int(d.Round(0).IntPart())
	}

	return Hailstone{
		Pos: utils.NewCoordinate3D(decimalToInt(x[0]), decimalToInt(x[1]), decimalToInt(x[2])),
		Vel: Velocities(utils.NewCoordinate3D(decimalToInt(x[3]), decimalToInt(x[4]), decimalToInt(x[5]))),
	}
}
