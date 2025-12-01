package main

import (
	"fmt"
	"io"
	"slices"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	graph := parseComponents(f)
	cMap := graph.toConnectionGraph()
	edgeBetweeness := cMap.EdgeBetweeness()
	threeEdgesToCut := findHighestThreeEdges(edgeBetweeness)
	for _, e := range threeEdgesToCut {
		graph.CutEdge(e)
	}
	firstCount, secondCount := graph.CountNodesInEachGroup()
	fmt.Printf("Part one solution: %d\n", firstCount*secondCount)
}

type ComponentGraph map[string][]string

func (g ComponentGraph) GraphViz() string {
	doneEdges := map[string]map[string]bool{}

	s := "graph {\n"

	for src, dsts := range g {
		for _, d := range dsts {
			if _, ok := doneEdges[d][src]; ok {
				continue
			}
			s += fmt.Sprintf("%s -- %s\n", src, d)
			if _, ok := doneEdges[src]; !ok {
				doneEdges[src] = map[string]bool{}
			}
			doneEdges[src][d] = true
		}
	}

	return s + "}"
}

func (g ComponentGraph) CutEdge(edge [2]string) {
	g[edge[0]] = slices.DeleteFunc(g[edge[0]], func(s string) bool {
		return s == edge[1]
	})
	g[edge[1]] = slices.DeleteFunc(g[edge[1]], func(s string) bool {
		return s == edge[0]
	})
}

func (g ComponentGraph) CountNodesInEachGroup() (int, int) {
	touched := map[string]bool{}

	var dfs func(n string) int
	dfs = func(n string) int {
		gCount := 1
		touched[n] = true

		for _, neighbor := range g[n] {
			if touched[neighbor] {
				continue
			}

			gCount += dfs(neighbor)
		}

		return gCount
	}

	nodes := []string{}
	for n := range g {
		nodes = append(nodes, n)
	}

	first := dfs(nodes[0])

	var second int
	for _, n := range nodes {
		if touched[n] {
			continue
		}
		second = dfs(n)
		break
	}

	return first, second
}

func (g ComponentGraph) toConnectionGraph() utils.ConnectionMap[string] {
	cMap := make(utils.ConnectionMap[string])

	for n, neighbors := range g {
		cMap[n] = map[string]int{}
		for _, neighbor := range neighbors {
			cMap[n][neighbor] = 1
		}
	}

	return cMap
}

func findHighestThreeEdges(betweeness map[string]map[string]float64) [][2]string {
	type edgeWithWeight struct {
		edge   [2]string
		weight float64
	}

	edgesToWeight := []edgeWithWeight{}

	for n, neighbors := range betweeness {
		for neighbor, weight := range neighbors {
			// check so we only get one per pair
			if neighbor < n {
				continue
			}
			edgesToWeight = append(edgesToWeight, edgeWithWeight{
				edge:   [2]string{n, neighbor},
				weight: weight,
			})
		}
	}

	slices.SortFunc(edgesToWeight, func(a, b edgeWithWeight) int {
		return int(b.weight - a.weight)
	})

	return utils.SliceMap(edgesToWeight, func(e edgeWithWeight) [2]string {
		return e.edge
	})[:3]
}

func parseComponents(r io.Reader) ComponentGraph {
	g := ComponentGraph{}

	utils.ExecutePerLine(r, func(line string) error {
		source, destsStr, _ := strings.Cut(line, ":")

		dests := strings.Split(strings.TrimSpace(destsStr), " ")

		for _, d := range dests {
			if _, ok := g[source]; !ok {
				g[source] = []string{}
			}
			g[source] = append(g[source], d)

			if _, ok := g[d]; !ok {
				g[d] = []string{}
			}
			g[d] = append(g[d], source)
		}

		return nil
	})

	return g
}
