use std::{
    fs::{self},
    io::Error,
};

fn main() {
    let levels = read_input("input.txt").expect("failed to read input");

    println!("Part 1: {}", part_1(&levels));
    println!("Part 2: {}", part_2(&levels));
}

fn read_input(path: &str) -> Result<Vec<Vec<i64>>, Error> {
    Ok(fs::read_to_string(path)?
        .lines()
        .map(|s| {
            s.split_whitespace()
                .map(|n| n.parse::<i64>().unwrap())
                .collect()
        })
        .collect())
}

fn floor_is_safe(floor: &[i64]) -> bool {
    (floor.is_sorted_by(|a, b| a < b) || floor.is_sorted_by(|a, b| a > b))
        && floor.windows(2).all(|window| {
            let diff = (window[0] - window[1]).abs();
            diff >= 1 && diff <= 3
        })
}

fn part_1(levels: &Vec<Vec<i64>>) -> i64 {
    levels.iter().fold(0, |acc, floor| {
        acc + if floor_is_safe(floor) { 1 } else { 0 }
    })
}

fn part_2(levels: &Vec<Vec<i64>>) -> i64 {
    levels.iter().fold(0, |acc, floor| {
        acc + if floor_is_safe(floor) {
            1
        } else {
            if (0..floor.len()).any(|i| {
                let floor_without_i = [&floor[0..i], &floor[i + 1..floor.len()]].concat();
                floor_is_safe(&floor_without_i)
            }) {
                1
            } else {
                0
            }
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let levels = read_input("example.txt").expect("failed to read input");

        let result = part_1(&levels);
        assert_eq!(result, 2);
    }

    #[test]
    fn part2_works() {
        let levels = read_input("example.txt").expect("failed to read input");

        let result = part_2(&levels);
        assert_eq!(result, 4);
    }
}
