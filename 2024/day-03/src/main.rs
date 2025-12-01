use regex::{Match, Regex};
use std::{fs, io::Error};

fn main() {
    let input = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part_1(&input));
    println!("Part 2: {}", part_2(&input));
}

fn part_1(input: &str) -> u32 {
    let stmts = find_valid_multiply_stmts(&input);
    sum_muls(&stmts)
}

fn part_2(input: &str) -> u32 {
    let stmts = find_enabled_multiply_stmts(&input);
    sum_muls(&stmts)
}

fn read_input(path: &str) -> Result<String, Error> {
    fs::read_to_string(path)
}

fn find_valid_multiply_stmts(input: &str) -> Vec<MultiplyStatement> {
    let re = Regex::new(r"mul\((\d{1,3}),(\d{1,3})\)").unwrap();

    let match_to_int = |mat: Option<Match>| {
        mat.expect("uncaptured num")
            .as_str()
            .parse()
            .expect("capture was not an int")
    };

    re.captures_iter(input)
        .map(|cap| MultiplyStatement {
            left: match_to_int(cap.get(1)),
            right: match_to_int(cap.get(2)),
        })
        .collect()
}

fn find_enabled_multiply_stmts(input: &str) -> Vec<MultiplyStatement> {
    let mut stmts = Vec::new();

    find_enabled_multiply_stmts_helper(&mut stmts, input);

    stmts
}

fn find_enabled_multiply_stmts_helper(acc: &mut Vec<MultiplyStatement>, input: &str) {
    let (on, off) = match input.split_once("don't()") {
        Some((a, b)) => (a, b),
        None => (input, ""),
    };
    let mut stmts = find_valid_multiply_stmts(on);
    acc.append(&mut stmts);

    match off.split_once("do()") {
        Some((_, back_on)) => find_enabled_multiply_stmts_helper(acc, back_on),
        None => return,
    }
}

struct MultiplyStatement {
    left: u32,
    right: u32,
}

impl MultiplyStatement {
    fn mul(&self) -> u32 {
        self.left * self.right
    }
}

fn sum_muls(stmts: &[MultiplyStatement]) -> u32 {
    stmts.iter().fold(0, |acc, s| acc + s.mul())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let input = read_input("example.txt").expect("failed to read example");
        let result = part_1(&input);
        assert_eq!(result, 161);
    }

    #[test]
    fn part2_works() {
        let input = read_input("example.txt").expect("failed to read example");
        let result = part_2(&input);
        assert_eq!(result, 161);

        let input2 = read_input("example2.txt").expect("failed to read example");
        let result2 = part_2(&input2);
        assert_eq!(result2, 48);
    }
}
