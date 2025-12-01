package utils

import (
	"cmp"
	"container/heap"
	"errors"
)

var (
	ErrKeyAlreadyExists = errors.New("key already exists")
)

type Queue[T any] struct {
	data []T
}

func NewQueue[T any]() *Queue[T] {
	return &Queue[T]{
		data: []T{},
	}
}

func (q *Queue[T]) Push(v T) {
	q.data = append(q.data, v)
}

func (q *Queue[T]) Pop() T {
	if q.Len() == 0 {
		panic("queue empty")
	}

	v := q.data[0]
	q.data = q.data[1:]
	return v
}

func (q *Queue[T]) Len() int {
	return len(q.data)
}

type item[K comparable, P cmp.Ordered] struct {
	value    K
	priority P
	index    int
}

type heapPriorityQueue[K comparable, P cmp.Ordered] struct {
	items        []*item[K, P]
	idxMap       map[K]int
	inverseOrder bool
}

func newHeapPriorityQueue[K comparable, P cmp.Ordered]() *heapPriorityQueue[K, P] {
	return &heapPriorityQueue[K, P]{
		items:  []*item[K, P]{},
		idxMap: map[K]int{},
	}
}

func (hpq heapPriorityQueue[_, _]) Len() int {
	return len(hpq.items)
}

func (hpq heapPriorityQueue[_, _]) Less(i, j int) bool {
	if hpq.inverseOrder {
		return hpq.items[i].priority > hpq.items[j].priority
	}
	return hpq.items[i].priority < hpq.items[j].priority
}

func (hpq heapPriorityQueue[_, _]) Swap(i, j int) {
	hpq.items[i], hpq.items[j] = hpq.items[j], hpq.items[i]

	hpq.items[i].index = i
	hpq.idxMap[hpq.items[i].value] = i

	hpq.items[j].index = j
	hpq.idxMap[hpq.items[j].value] = j
}

func (hpq *heapPriorityQueue[K, P]) Push(x any) {
	n := len(hpq.items)
	newItem := x.(*item[K, P])
	newItem.index = n

	hpq.items = append(hpq.items, newItem)
	hpq.idxMap[newItem.value] = n
}

func (hpq *heapPriorityQueue[_, _]) Pop() any {
	n := len(hpq.items)
	popItem := hpq.items[n-1]
	hpq.items[n-1] = nil
	popItem.index = -1
	hpq.items = hpq.items[:n-1]
	delete(hpq.idxMap, popItem.value)
	return popItem
}

type PriorityQueue[K comparable, P cmp.Ordered] struct {
	hpq *heapPriorityQueue[K, P]
}

func NewPriorityQueue[K comparable, P cmp.Ordered]() *PriorityQueue[K, P] {
	return &PriorityQueue[K, P]{
		hpq: newHeapPriorityQueue[K, P](),
	}
}

func (pq *PriorityQueue[K, P]) SetPriorityOrder(inverseOrder bool) {
	pq.hpq.inverseOrder = inverseOrder
}

func (pq *PriorityQueue[_, _]) Len() int {
	return pq.hpq.Len()
}

func (pq *PriorityQueue[K, P]) Push(v K, priority P) {
	heap.Push(pq.hpq, &item[K, P]{
		value:    v,
		priority: priority,
	})
}

func (pq *PriorityQueue[K, P]) Init(vals map[K]P) {
	for k, priority := range vals {
		// not possible for this to err since the map ensures unique keys
		pq.hpq.Push(&item[K, P]{
			value:    k,
			priority: priority,
		})
	}

	heap.Init(pq.hpq)
}

func (pq *PriorityQueue[K, P]) Update(v K, priority P) {
	i, ok := pq.hpq.idxMap[v]

	if !ok {
		pq.Push(v, priority)
		return
	}

	pq.hpq.items[i].priority = priority
	heap.Fix(pq.hpq, i)
}

func (pq *PriorityQueue[K, P]) Pop() (K, P) {
	popItem := heap.Pop(pq.hpq).(*item[K, P])

	return popItem.value, popItem.priority
}
