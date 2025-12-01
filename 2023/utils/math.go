package utils

func LeastCommonMultiple(nums []int) int {
	dedupFactors := map[int]any{}

	for _, n := range nums {
		factors := PrimeFactorization(n)
		for _, f := range factors {
			dedupFactors[f] = nil
		}
	}

	lcm := 1
	for f := range dedupFactors {
		lcm *= f
	}

	return lcm
}

func PrimeFactorization(num int) []int {
	primeFactors := []int{}

	// get all 2s
	for num%2 == 0 {
		primeFactors = append(primeFactors, 2)
		num /= 2
	}

	// go through odd nums
	for i := 3; i*i <= num; i += 2 {
		for num%i == 0 {
			primeFactors = append(primeFactors, i)
			num /= i
		}
	}

	// whatever is left must still be prime
	if num > 2 {
		primeFactors = append(primeFactors, num)
	}

	return primeFactors
}

func NevilleInterpolation(xs []int, ys []int, x int) int {
	n := len(ys)
	p := make([]float64, n)

	for k := 0; k < n; k++ {
		for i := 0; i < n-k; i++ {
			if k == 0 {
				p[i] = float64(ys[i])
			} else {
				p[i] = (float64(x-xs[i]-k)*p[i] + float64(xs[i]-x)*p[i+1]) / float64(-k)
			}
		}
	}

	return int(p[0])
}
