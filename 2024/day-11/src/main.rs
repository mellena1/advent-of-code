use std::collections::HashMap;
use std::fs::read_to_string;

fn main() {
    let stones = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&stones));
    println!("Part 2: {}", part2(&stones));
}

fn blink_stones_n_times(stones: &Stones, n: u64) -> u64 {
    let mut cache = HashMap::new();

    stones.stones.iter().fold(0, |acc, stone| {
        acc + blink_on_stone_n_times_with_cache(stone, n, &mut cache)
    })
}

fn part1(stones: &Stones) -> u64 {
    blink_stones_n_times(stones, 25)
}

fn part2(stones: &Stones) -> u64 {
    blink_stones_n_times(stones, 75)
}

fn read_input(path: &str) -> Result<Stones, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(Stones::from(input.as_str()))
}

#[derive(Clone)]
struct Stones {
    stones: Vec<String>,
}

impl From<&str> for Stones {
    fn from(value: &str) -> Self {
        let stones = value.split_whitespace().map(|s| String::from(s)).collect();
        Self { stones }
    }
}

fn blink_on_stone(stone: &str) -> Vec<String> {
    if stone == "0" {
        vec!["1".into()]
    } else if stone.len() % 2 == 0 {
        let (left, right) = stone.split_at(stone.len() / 2);
        let trimmed_right = right.trim_start_matches("0").to_string();
        vec![
            left.into(),
            if trimmed_right.len() > 0 {
                trimmed_right
            } else {
                "0".into()
            },
        ]
    } else {
        let new_stone_num = stone.parse::<u64>().expect("all stones must be numbers") * 2024;
        vec![new_stone_num.to_string()]
    }
}

fn blink_on_stone_n_times_with_cache(
    stone: &str,
    n: u64,
    cache: &mut HashMap<(String, u64), u64>,
) -> u64 {
    if n == 0 {
        return 1;
    }

    if let Some(num_stones) = cache.get(&(stone.to_string(), n)) {
        return *num_stones;
    }

    let new_stones = blink_on_stone(stone);

    let num = new_stones.iter().fold(0, |acc, stone| {
        acc + blink_on_stone_n_times_with_cache(stone, n - 1, cache)
    });

    cache.insert((stone.to_string(), n), num);
    num
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let stones = read_input("example.txt").expect("failed to read input");
        let result = part1(&stones);
        assert_eq!(result, 55312);
    }
}
