package utils

import (
	"math"
	"slices"
)

type ConnectionMap[K comparable] map[K]map[K]int

func (cMap ConnectionMap[K]) Betweeness() map[K]float64 {
	cb := make(map[K]float64)

	cMap.brandes(func(n K, stack *Stack[K], p map[K][]K, delta, sigma map[K]float64) {
		for stack.Len() > 0 {
			w := stack.Pop()
			for _, v := range p[w] {
				delta[v] += sigma[v] / sigma[w] * (1 + delta[w])
			}
			if w != n {
				if d := delta[w]; d != 0 {
					cb[w] += d
				}
			}
		}
	})

	return cb
}

func (cMap ConnectionMap[K]) EdgeBetweeness() map[K]map[K]float64 {
	cb := make(map[K]map[K]float64)

	cMap.brandes(func(n K, stack *Stack[K], p map[K][]K, delta, sigma map[K]float64) {
		for stack.Len() != 0 {
			w := stack.Pop()
			for _, v := range p[w] {
				c := sigma[v] / sigma[w] * (1 + delta[w])
				if _, ok := cb[v]; !ok {
					cb[v] = map[K]float64{}
				}
				cb[v][w] += c
				delta[v] += c
			}
		}
	})

	return cb
}

func (cMap ConnectionMap[K]) brandes(accumulate func(n K, stack *Stack[K], p map[K][]K, delta, sigma map[K]float64)) {
	// based off of gonum's implementation: https://github.com/gonum/gonum/blob/v0.14.0/graph/network/betweenness.go

	p := make(map[K][]K, len(cMap))
	sigma := make(map[K]float64, len(cMap))
	d := make(map[K]int, len(cMap))
	delta := make(map[K]float64, len(cMap))

	queue := NewQueue[K]()

	for n := range cMap {
		stack := NewStack[K]()

		// reset everything
		for w := range cMap {
			p[w] = p[w][:0]
			sigma[w] = 0
			d[w] = -1
		}
		sigma[n] = 1
		d[n] = 0

		queue.Push(n)
		for queue.Len() > 0 {
			v := queue.Pop()

			stack.Push(v)

			for neighbor := range cMap[v] {
				// neighbor found for first time
				if d[neighbor] < 0 {
					queue.Push(neighbor)
					d[neighbor] = d[v] + 1
				}
				// shortest path to neighbor from v
				if d[neighbor] == d[v]+1 {
					sigma[neighbor] += sigma[v]
					p[neighbor] = append(p[neighbor], v)
				}
			}
		}

		for v := range cMap {
			delta[v] = 0
		}

		accumulate(n, stack, p, delta, sigma)
	}
}

func (cMap ConnectionMap[K]) Dijkstra(source K) (map[K]int, map[K]K) {
	distances := make(map[K]int, len(cMap))
	pq := NewPriorityQueue[K, int]()
	prev := map[K]K{}

	for vertex := range cMap {
		distances[vertex] = math.MaxInt
	}
	distances[source] = 0

	pq.Init(distances)

	for pq.Len() > 0 {
		curNode, curNodeDist := pq.Pop()

		for neighbor, dist := range cMap[curNode] {
			alt := curNodeDist + dist
			if alt < distances[neighbor] {
				distances[neighbor] = alt
				pq.Update(neighbor, alt)
				prev[neighbor] = curNode
			}
		}
	}

	return distances, prev
}

func (cMap ConnectionMap[K]) DijkstraWithDest(source K, destination K) int {
	distances := make(map[K]int, len(cMap))
	pq := NewPriorityQueue[K, int]()

	for vertex := range cMap {
		distances[vertex] = math.MaxInt
	}
	distances[source] = 0

	for vertex, distance := range distances {
		pq.Push(vertex, distance)
	}

	for pq.Len() > 0 {
		curNode, curNodeDist := pq.Pop()

		if curNode == destination {
			break
		}

		for neighbor, dist := range cMap[curNode] {
			alt := curNodeDist + dist
			if alt < distances[neighbor] {
				distances[neighbor] = alt
				pq.Update(neighbor, alt)
			}
		}
	}

	return distances[destination]
}

func (cMap ConnectionMap[K]) LongestDijkstraWithDest(source K, destination K) (int, []K) {
	distances := make(map[K]int, len(cMap))
	pq := NewPriorityQueue[K, int]()
	pq.SetPriorityOrder(true)
	prev := map[K]K{}

	for vertex := range cMap {
		distances[vertex] = math.MinInt
	}
	distances[source] = 0

	for vertex, distance := range distances {
		pq.Push(vertex, distance)
	}

	for pq.Len() > 0 {
		curNode, curNodeDist := pq.Pop()

		for neighbor, dist := range cMap[curNode] {
			if nodeIsAlreadyInPath(prev, curNode, neighbor) {
				continue
			}

			alt := curNodeDist + dist
			if alt > distances[neighbor] {
				distances[neighbor] = alt
				pq.Update(neighbor, alt)
				prev[neighbor] = curNode
			}
		}
	}

	return distances[destination], reconstructPath(prev, source, destination)
}

func nodeIsAlreadyInPath[K comparable](prev map[K]K, source, node K) bool {
	curNode := source
	ok := true

	for ok {
		curNode, ok = prev[curNode]

		if ok && curNode == node {
			return true
		}
	}

	return false
}

func reconstructPath[K comparable](prev map[K]K, source, dest K) []K {
	path := []K{dest}

	curNode := dest
	for curNode != source {
		curNode = prev[curNode]
		path = append(path, curNode)
	}

	slices.Reverse(path)
	return path
}
