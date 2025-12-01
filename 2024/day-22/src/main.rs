use std::{
    collections::{HashMap, HashSet},
    fs::read_to_string,
};

fn main() {
    let secrets = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&secrets));
    println!("Part 2: {}", part2(&secrets));
}

fn part1(secrets: &BuyerSecretNums) -> usize {
    secrets
        .nums
        .iter()
        .fold(0, |acc, n| acc + get_nth_secret_num(*n, 2000))
}

fn part2(secrets: &BuyerSecretNums) -> usize {
    secrets.find_price_for_selling_with_best_combo(2000)
}

fn read_input(path: &str) -> Result<BuyerSecretNums, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(BuyerSecretNums::from(input.as_str()))
}

struct BuyerSecretNums {
    nums: Vec<usize>,
}

impl BuyerSecretNums {
    fn find_price_for_selling_with_best_combo(&self, num_of_iters: usize) -> usize {
        let all_changes: Vec<_> = self
            .nums
            .iter()
            .map(|n| get_list_of_changes_with_price(*n, num_of_iters))
            .collect();

        let price_per_combo_per_buyer: Vec<_> = all_changes
            .iter()
            .map(|changes| get_map_of_possible_change_combos(changes.as_slice()))
            .collect();

        let mut set_of_combos: HashSet<[i64; 4]> = HashSet::new();
        price_per_combo_per_buyer.iter().for_each(|combo_map| {
            set_of_combos.extend(combo_map.keys());
        });

        set_of_combos
            .iter()
            .map(|combo| {
                price_per_combo_per_buyer.iter().fold(0, |acc, buyer_map| {
                    acc + buyer_map.get(combo).unwrap_or_else(|| &0)
                })
            })
            .max()
            .expect("should never fail")
    }
}

impl From<&str> for BuyerSecretNums {
    fn from(value: &str) -> Self {
        let nums = value
            .lines()
            .map(|line| line.parse().expect("should be num"))
            .collect();

        Self { nums }
    }
}

fn get_nth_secret_num(n: usize, num_of_iters: usize) -> usize {
    (0..num_of_iters).fold(n, |acc, _| get_next_secret_num(acc))
}

fn get_next_secret_num(n: usize) -> usize {
    let step1 = prune_num(mix_num(n, n * 64));
    let step2 = prune_num(mix_num(step1, step1 / 32));
    prune_num(mix_num(step2, step2 * 2048))
}

fn mix_num(n: usize, val: usize) -> usize {
    n ^ val
}

fn prune_num(n: usize) -> usize {
    n % 16777216
}

fn get_list_of_changes_with_price(n: usize, num_of_iters: usize) -> Vec<(i64, usize)> {
    let mut changes_and_prices = Vec::with_capacity(num_of_iters);
    let mut cur_n = n;
    for _ in 0..num_of_iters {
        let next_n = get_next_secret_num(cur_n);
        let cur_price = cur_n % 10;
        let next_price = next_n % 10;
        let change = next_price as i64 - cur_price as i64;
        changes_and_prices.push((change, next_price));

        cur_n = next_n;
    }
    changes_and_prices
}

fn get_map_of_possible_change_combos(
    changes_with_prices: &[(i64, usize)],
) -> HashMap<[i64; 4], usize> {
    let mut combos: HashMap<[i64; 4], usize> = HashMap::new();

    changes_with_prices
        .windows(4)
        .for_each(|window_of_combo_with_price| {
            let window: Vec<_> = window_of_combo_with_price.iter().map(|v| v.0).collect();
            let arr = <[i64; 4]>::try_from(window).expect("should never fail");

            if !combos.contains_key(&arr) {
                combos.insert(arr, window_of_combo_with_price[3].1);
            }
        });

    combos
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let secrets = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&secrets), 37327623);
    }

    #[test]
    fn part2_works() {
        let secrets = read_input("example2.txt").expect("failed to read input");
        assert_eq!(part2(&secrets), 23);
    }
}
