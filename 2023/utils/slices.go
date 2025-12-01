package utils

import (
	"strconv"
)

func StrSliceToIntSlice(strs []string) ([]int, error) {
	nums := make([]int, len(strs))
	for i, s := range strs {
		n, err := strconv.Atoi(s)
		if err != nil {
			return nil, err
		}
		nums[i] = n
	}
	return nums, nil
}

func SliceFilter[T any](s []T, f func(v T) bool) []T {
	newS := []T{}
	for _, v := range s {
		if f(v) {
			newS = append(newS, v)
		}
	}
	return newS
}

func SliceMap[T any, U any](s []T, f func(v T) U) []U {
	newS := make([]U, len(s))
	for i, v := range s {
		newS[i] = f(v)
	}
	return newS
}

func IntSliceSum(s []int) int {
	sum := 0
	for _, n := range s {
		sum += n
	}
	return sum
}
