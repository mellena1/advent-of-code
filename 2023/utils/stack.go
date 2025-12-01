package utils

type Stack[T any] struct {
	data []T
}

func NewStack[T any]() *Stack[T] {
	return &Stack[T]{
		data: []T{},
	}
}

func (s *Stack[T]) Push(v T) {
	s.data = append(s.data, v)
}

func (s *Stack[T]) Pop() T {
	if s.Len() == 0 {
		panic("stack empty")
	}

	v := s.data[len(s.data)-1]
	s.data = s.data[:len(s.data)-1]

	return v
}

func (s *Stack[T]) Len() int {
	return len(s.data)
}
