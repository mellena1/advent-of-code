package main

import (
	"fmt"
	"slices"
)

type Pulse bool

func (p Pulse) String() string {
	if p == HighPulse {
		return "high"
	}
	return "low"
}

const (
	HighPulse Pulse = true
	LowPulse  Pulse = false
)

func makeMessages(fromModule string, outputModules []string, pulse Pulse) []PulseMessage {
	messages := []PulseMessage{}

	for _, output := range outputModules {
		messages = append(messages, PulseMessage{
			FromModule: fromModule,
			ToModule:   output,
			PulseVal:   pulse,
		})
	}

	return messages
}

type PulseMessage struct {
	FromModule string
	ToModule   string
	PulseVal   Pulse
}

func (pm PulseMessage) String() string {
	return fmt.Sprintf("%s -%s-> %s", pm.FromModule, pm.PulseVal, pm.ToModule)
}

type Module interface {
	fmt.Stringer
	ReceivePulse(source string, pulse Pulse) []PulseMessage
	EqualState(m Module) bool
	StateString() string
	Outputs() []string
	Name() string
	Copy() Module
}

type FlipFlopModule struct {
	name            string
	state           bool
	outputModules   []string
	highOutMessages []PulseMessage
	lowOutMessages  []PulseMessage
}

func NewFlipFlopModule(name string, outputs []string) *FlipFlopModule {
	return &FlipFlopModule{
		name:            name,
		state:           false,
		outputModules:   outputs,
		highOutMessages: makeMessages(name, outputs, HighPulse),
		lowOutMessages:  makeMessages(name, outputs, LowPulse),
	}
}

func (mod *FlipFlopModule) ReceivePulse(source string, pulse Pulse) []PulseMessage {
	// high pulse does nothing
	if pulse {
		return []PulseMessage{}
	}

	mod.state = !mod.state

	if mod.state {
		return mod.highOutMessages
	} else {
		return mod.lowOutMessages
	}
}

func (mod *FlipFlopModule) EqualState(module Module) bool {
	switch module.(type) {
	case *FlipFlopModule:
	default:
		panic("must check against equality against the same type")
	}

	m2 := module.(*FlipFlopModule)

	return mod.state == m2.state
}

func (mod *FlipFlopModule) StateString() string {
	return fmt.Sprintf("%v", mod.state)
}

func (mod *FlipFlopModule) Copy() Module {
	return &FlipFlopModule{
		name:            mod.name,
		state:           mod.state,
		outputModules:   mod.outputModules,
		highOutMessages: mod.highOutMessages,
		lowOutMessages:  mod.lowOutMessages,
	}
}

func (mod *FlipFlopModule) Outputs() []string {
	return mod.outputModules
}

func (mod *FlipFlopModule) Name() string {
	return mod.name
}

func (mod FlipFlopModule) String() string {
	return fmt.Sprintf("flipflop{state: %v, outputs: %v}", mod.state, mod.outputModules)
}

type ConjunctionModule struct {
	name            string
	prevPulses      map[string]Pulse
	numInputsLow    int
	outputModules   []string
	highOutMessages []PulseMessage
	lowOutMessages  []PulseMessage
}

func NewConjunctionModule(name string, inputs []string, outputs []string) *ConjunctionModule {
	prevPulses := map[string]Pulse{}

	for _, in := range inputs {
		prevPulses[in] = LowPulse
	}

	return &ConjunctionModule{
		name:            name,
		prevPulses:      prevPulses,
		numInputsLow:    len(prevPulses),
		outputModules:   outputs,
		highOutMessages: makeMessages(name, outputs, HighPulse),
		lowOutMessages:  makeMessages(name, outputs, LowPulse),
	}
}

func (mod *ConjunctionModule) ReceivePulse(source string, pulse Pulse) []PulseMessage {
	oldPulse := mod.prevPulses[source]
	if oldPulse != pulse {
		if pulse == HighPulse {
			mod.numInputsLow--
		} else {
			mod.numInputsLow++
		}
	}
	mod.prevPulses[source] = pulse

	if mod.numInputsLow == 0 {
		return mod.lowOutMessages
	} else {
		return mod.highOutMessages
	}
}

func (mod *ConjunctionModule) EqualState(module Module) bool {
	switch module.(type) {
	case *ConjunctionModule:
	default:
		panic("must check against equality against the same type")
	}

	m2 := module.(*ConjunctionModule)

	for k, v := range mod.prevPulses {
		if m2.prevPulses[k] != v {
			return false
		}
	}
	return true
}

func (mod *ConjunctionModule) StateString() string {
	keys := []string{}
	for k := range mod.prevPulses {
		keys = append(keys, k)
	}
	slices.Sort(keys)

	s := ""
	for _, k := range keys {
		s += fmt.Sprintf("%s:%v,", k, mod.prevPulses[k])
	}

	return s
}

func (mod *ConjunctionModule) Copy() Module {
	prevPulsesCopy := make(map[string]Pulse, len(mod.prevPulses))
	for k, v := range mod.prevPulses {
		prevPulsesCopy[k] = v
	}

	return &ConjunctionModule{
		name:            mod.name,
		numInputsLow:    mod.numInputsLow,
		prevPulses:      prevPulsesCopy,
		outputModules:   mod.outputModules,
		highOutMessages: mod.highOutMessages,
		lowOutMessages:  mod.lowOutMessages,
	}
}

func (mod *ConjunctionModule) Outputs() []string {
	return mod.outputModules
}

func (mod *ConjunctionModule) Name() string {
	return mod.name
}

func (mod ConjunctionModule) String() string {
	return fmt.Sprintf("conjunction{states: %+v, outputs: %v}", mod.prevPulses, mod.outputModules)
}

type BroadcastModule struct {
	name            string
	outputModules   []string
	lowOutMessages  []PulseMessage
	highOutMessages []PulseMessage
}

func NewBroadcastModule(name string, outputs []string) *BroadcastModule {
	return &BroadcastModule{
		name:            name,
		outputModules:   outputs,
		lowOutMessages:  makeMessages(name, outputs, LowPulse),
		highOutMessages: makeMessages(name, outputs, HighPulse),
	}
}

func (mod *BroadcastModule) ReceivePulse(source string, pulse Pulse) []PulseMessage {
	if pulse == HighPulse {
		return mod.highOutMessages
	} else {
		return mod.lowOutMessages
	}
}

func (mod *BroadcastModule) EqualState(module Module) bool {
	return true
}

func (mod *BroadcastModule) StateString() string {
	return ""
}

func (mod *BroadcastModule) Copy() Module {
	return mod
}

func (mod *BroadcastModule) Outputs() []string {
	return mod.outputModules
}

func (mod *BroadcastModule) Name() string {
	return mod.name
}

func (mod BroadcastModule) String() string {
	return fmt.Sprintf("broadcast{outputs: %v}", mod.outputModules)
}
