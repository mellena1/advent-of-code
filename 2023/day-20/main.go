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

	modules := parseModules(f)
	modulesP2 := modules.copy()

	lowPulses := 0
	highPulses := 0

	for i := 0; i < 1000; i++ {
		l, h := countPulseAfterButtonPush(modules)
		lowPulses += l
		highPulses += h
	}
	fmt.Printf("Part one solution: %d\n", lowPulses*highPulses)

	freqs := findFrequencyOfPulsesFromMods(modulesP2, HighPulse, "tx", "nd", "pc", "vd")
	fmt.Printf("Part two solution: %d\n", utils.LeastCommonMultiple(freqs))
}

type ModulesMap map[string]Module

func (m ModulesMap) copy() ModulesMap {
	newM := make(ModulesMap, len(m))

	for k, v := range m {
		newM[k] = v.Copy()
	}

	return newM
}

// //nolint:golint,unused
func (m ModulesMap) graphViz() string {
	s := "digraph {\n"

	for mName, mod := range m {
		for _, o := range mod.Outputs() {
			s += fmt.Sprintf("%s -> %s\n", mName, o)
		}
	}

	return s + "\n}"
}

func parseModules(r io.Reader) ModulesMap {
	inputs := map[string][]string{}
	outputs := map[string][]string{}

	utils.ExecutePerLine(r, func(line string) error {
		modName, outputsStr, _ := strings.Cut(line, " -> ")

		outputsSplit := utils.SliceMap(strings.Split(outputsStr, ","), func(s string) string {
			return strings.TrimSpace(s)
		})

		outputs[modName] = outputsSplit

		for _, o := range outputsSplit {
			if _, ok := inputs[o]; !ok {
				inputs[o] = []string{}
			}
			inputs[o] = append(inputs[o], strings.TrimLeft(modName, "%&"))
		}

		return nil
	})

	modules := ModulesMap{}

	for modName, outputs := range outputs {
		if modName == "broadcaster" {
			modules[modName] = NewBroadcastModule(modName, outputs)
		} else if strings.HasPrefix(modName, "%") {
			modules[modName[1:]] = NewFlipFlopModule(modName[1:], outputs)
		} else if strings.HasPrefix(modName, "&") {
			modules[modName[1:]] = NewConjunctionModule(modName[1:], inputs[modName[1:]], outputs)
		}
	}

	return modules
}

func countPulseAfterButtonPush(modules ModulesMap) (int, int) {
	lowPulses := 0
	highPulses := 0

	pulsesToDo := []PulseMessage{{
		FromModule: "button",
		ToModule:   "broadcaster",
		PulseVal:   LowPulse,
	}}

	for len(pulsesToDo) > 0 {
		msg := pulsesToDo[0]
		mod, modExists := modules[msg.ToModule]

		if msg.PulseVal == HighPulse {
			highPulses++
		} else {
			lowPulses++
		}

		var newPulses []PulseMessage
		if modExists {
			newPulses = mod.ReceivePulse(msg.FromModule, msg.PulseVal)
		}
		pulsesToDo = append(pulsesToDo[1:], newPulses...)
	}

	return lowPulses, highPulses
}

func findFrequencyOfPulsesFromMods(modules ModulesMap, wantedPulse Pulse, modNames ...string) []int {
	modsHitWithHigh := 0
	modHitWithHigh := make([]int, len(modNames))
	buttonPresses := 0

	pulsesToDo := []PulseMessage{}
	pulsesFired := 0

	for modsHitWithHigh < len(modNames) {
		buttonPresses++
		pulsesToDo = append(pulsesToDo, PulseMessage{
			FromModule: "button",
			ToModule:   "broadcaster",
			PulseVal:   LowPulse,
		})

		for len(pulsesToDo) > 0 {
			msg := pulsesToDo[0]
			mod, modExists := modules[msg.ToModule]

			if msg.PulseVal == wantedPulse {
				searchModIdx := slices.Index(modNames, msg.FromModule)
				if searchModIdx > -1 && modHitWithHigh[searchModIdx] == 0 {
					modsHitWithHigh++
					modHitWithHigh[searchModIdx] = buttonPresses
				}
			}

			var newPulses []PulseMessage
			if modExists {
				newPulses = mod.ReceivePulse(msg.FromModule, msg.PulseVal)
			}

			pulsesToDo = append(pulsesToDo[1:], newPulses...)
			pulsesFired++
		}
	}

	return modHitWithHigh
}
