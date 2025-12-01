package main

import (
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/mellena1/advent-of-code-2023/utils"
)

const (
	X = 'x'
	M = 'm'
	A = 'a'
	S = 's'
)

const (
	GREATER_THAN = '>'
	LESS_THAN    = '<'
)

func main() {
	f := utils.ReadFile("input.txt")
	defer f.Close()

	workflows, parts := parseWorkflowsAndParts(f)
	workflowMap := workflows.toMap()

	partOneSum := 0
	for _, p := range parts {
		if p.isAccepted(workflows, workflowMap) {
			partOneSum += p.sum()
		}
	}
	fmt.Printf("Part one solution: %d\n", partOneSum)
	fmt.Printf("Part two solution: %d\n", workflows.getNumOfAcceptedPaths())
}

type numRange struct {
	min int
	max int
}

type ranges struct {
	x numRange
	m numRange
	a numRange
	s numRange
}

func (r ranges) numberOfPermutations() int {
	return (r.x.max - r.x.min + 1) * (r.m.max - r.m.min + 1) * (r.a.max - r.a.min + 1) * (r.s.max - r.s.min + 1)
}

func (r ranges) containsRange(r2 ranges) bool {
	return r.x.min <= r2.x.min && r.x.max >= r2.x.max &&
		r.m.min <= r2.m.min && r.m.max >= r2.m.max &&
		r.a.min <= r2.a.min && r.a.max >= r2.a.max &&
		r.s.min <= r2.s.min && r.s.max >= r2.s.max
}

type Condition struct {
	key  utils.Char
	cond utils.Char
	num  int
}

func (c Condition) isTrue(p Part) bool {
	if c.cond == GREATER_THAN {
		switch c.key {
		case X:
			return p.x > c.num
		case M:
			return p.m > c.num
		case A:
			return p.a > c.num
		case S:
			return p.s > c.num
		}
	}

	switch c.key {
	case X:
		return p.x < c.num
	case M:
		return p.m < c.num
	case A:
		return p.a < c.num
	case S:
		return p.s < c.num
	}

	return false
}

func (c Condition) isPossibleInRanges(ranges ranges, wantedOutcome bool) (bool, ranges) {
	if c.cond == GREATER_THAN && wantedOutcome {
		switch c.key {
		case X:
			if ranges.x.min <= c.num {
				ranges.x.min = c.num + 1
			}
			return ranges.x.max > c.num, ranges
		case M:
			if ranges.m.min <= c.num {
				ranges.m.min = c.num + 1
			}
			return ranges.m.max > c.num, ranges
		case A:
			if ranges.a.min <= c.num {
				ranges.a.min = c.num + 1
			}
			return ranges.a.max > c.num, ranges
		case S:
			if ranges.s.min <= c.num {
				ranges.s.min = c.num + 1
			}
			return ranges.s.max > c.num, ranges
		}
	} else if c.cond == LESS_THAN && wantedOutcome {
		switch c.key {
		case X:
			if ranges.x.max >= c.num {
				ranges.x.max = c.num - 1
			}
			return ranges.x.min < c.num, ranges
		case M:
			if ranges.m.max >= c.num {
				ranges.m.max = c.num - 1
			}
			return ranges.m.min < c.num, ranges
		case A:
			if ranges.a.max >= c.num {
				ranges.a.max = c.num - 1
			}
			return ranges.a.min < c.num, ranges
		case S:
			if ranges.s.max >= c.num {
				ranges.s.max = c.num - 1
			}
			return ranges.s.min < c.num, ranges
		}
	} else if c.cond == GREATER_THAN && !wantedOutcome {
		switch c.key {
		case X:
			if ranges.x.max > c.num {
				ranges.x.max = c.num
			}
			return ranges.x.min <= c.num, ranges
		case M:
			if ranges.m.max > c.num {
				ranges.m.max = c.num
			}
			return ranges.m.min <= c.num, ranges
		case A:
			if ranges.a.max > c.num {
				ranges.a.max = c.num
			}
			return ranges.a.min <= c.num, ranges
		case S:
			if ranges.s.max > c.num {
				ranges.s.max = c.num
			}
			return ranges.s.min <= c.num, ranges
		}
	} else if c.cond == LESS_THAN && !wantedOutcome {
		switch c.key {
		case X:
			if ranges.x.min < c.num {
				ranges.x.min = c.num
			}
			return ranges.x.max >= c.num, ranges
		case M:
			if ranges.m.min < c.num {
				ranges.m.min = c.num
			}
			return ranges.m.max >= c.num, ranges
		case A:
			if ranges.a.min < c.num {
				ranges.a.min = c.num
			}
			return ranges.a.max >= c.num, ranges
		case S:
			if ranges.s.min < c.num {
				ranges.s.min = c.num
			}
			return ranges.s.max >= c.num, ranges
		}
	}

	return false, ranges
}

func (c Condition) String() string {
	return fmt.Sprintf("%s%s%d", c.key, c.cond, c.num)
}

type WorkflowStep struct {
	condition *Condition
	dest      string
}

func (ws WorkflowStep) String() string {
	s := ""
	if ws.condition != nil {
		s += ws.condition.String() + ":"
	}
	return s + ws.dest
}

type Workflow struct {
	name  string
	steps []WorkflowStep
}

func (w Workflow) String() string {
	s := w.name + "{"
	for i, step := range w.steps {
		s += step.String()

		if i < len(w.steps)-1 {
			s += ","
		}
	}

	return s + "}"
}

type Workflows []Workflow

func (w Workflows) toMap() map[string]Workflow {
	m := map[string]Workflow{}

	for _, flow := range w {
		m[flow.name] = flow
	}

	return m
}

func (w Workflows) getNumOfAcceptedPaths() int {
	workflowMap := w.toMap()

	pathRanges := ranges{
		x: numRange{1, 4000},
		m: numRange{1, 4000},
		a: numRange{1, 4000},
		s: numRange{1, 4000},
	}

	possibleRanges := []ranges{}

	var traverse func(workflow Workflow, stepIdx int, curRanges ranges)
	traverse = func(workflow Workflow, stepIdx int, curRanges ranges) {
		step := workflow.steps[stepIdx]
		if step.condition == nil {
			switch step.dest {
			case "A":
				possibleRanges = append(possibleRanges, curRanges)
				return
			case "R":
				return
			default:
				traverse(workflowMap[step.dest], 0, curRanges)
				return
			}
		}

		// if cond true
		if isPossible, newRanges := step.condition.isPossibleInRanges(curRanges, true); isPossible {
			switch step.dest {
			case "A":
				possibleRanges = append(possibleRanges, newRanges)
			case "R":
			default:
				traverse(workflowMap[step.dest], 0, newRanges)
			}
		}

		//if cond false
		if isPossible, newRanges := step.condition.isPossibleInRanges(curRanges, false); isPossible {
			traverse(workflow, stepIdx+1, newRanges)
		}
	}

	traverse(workflowMap["in"], 0, pathRanges)

	dedupPossibleRanges := []ranges{}
	for i, r := range possibleRanges {
		unique := true
		for j, r2 := range possibleRanges {
			if i == j {
				continue
			}
			if r2.containsRange(r) {
				unique = false
				break
			}
		}
		if unique {
			dedupPossibleRanges = append(dedupPossibleRanges, r)
		}
	}

	numAcceptedPerms := 0
	for _, r := range dedupPossibleRanges {
		numAcceptedPerms += r.numberOfPermutations()
	}

	return numAcceptedPerms
}

type Part struct {
	x int
	m int
	a int
	s int
}

func (p Part) isAccepted(workflows Workflows, workflowMap map[string]Workflow) bool {
	return checkWorkflow(p, workflowMap["in"], workflowMap)
}

func (p Part) sum() int {
	return p.x + p.m + p.a + p.s
}

func checkWorkflow(p Part, workflow Workflow, workflowMap map[string]Workflow) bool {
	for _, step := range workflow.steps {
		if step.condition == nil || step.condition.isTrue(p) {
			switch step.dest {
			case "A":
				return true
			case "R":
				return false
			default:
				return checkWorkflow(p, workflowMap[step.dest], workflowMap)
			}
		}
	}

	return false
}

func parseWorkflowsAndParts(r io.Reader) (Workflows, []Part) {
	workflows := Workflows{}
	parts := []Part{}
	parseWorkflows := true

	utils.ExecutePerLine(r, func(line string) error {
		if line == "" {
			parseWorkflows = false
			return nil
		}

		if parseWorkflows {
			name, rest, _ := strings.Cut(line, "{")
			steps := strings.Split(rest[:len(rest)-1], ",")

			workflow := Workflow{
				name:  name,
				steps: []WorkflowStep{},
			}

			for _, step := range steps {
				if !strings.Contains(step, ":") {
					workflow.steps = append(workflow.steps, WorkflowStep{
						condition: nil,
						dest:      step,
					})
					continue
				}

				cond, dest, _ := strings.Cut(step, ":")
				num, err := strconv.Atoi(cond[2:])
				if err != nil {
					return fmt.Errorf("failed to parse num %q: %w", cond[2:], err)
				}

				workflow.steps = append(workflow.steps, WorkflowStep{
					condition: &Condition{
						key:  utils.Char(cond[0]),
						cond: utils.Char(cond[1]),
						num:  num,
					},
					dest: dest,
				})
			}

			workflows = append(workflows, workflow)
			return nil
		}

		part := Part{}
		vals := strings.Split(line[1:len(line)-1], ",")
		for _, v := range vals {
			k, numStr, _ := strings.Cut(v, "=")
			num, err := strconv.Atoi(numStr)
			if err != nil {
				return fmt.Errorf("failed to parse num %q: %w", numStr, err)
			}

			switch utils.Char(k[0]) {
			case X:
				part.x = num
			case M:
				part.m = num
			case A:
				part.a = num
			case S:
				part.s = num
			}
		}
		parts = append(parts, part)

		return nil
	})

	return workflows, parts
}
