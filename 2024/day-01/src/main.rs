use std::{collections::HashMap, fs, io};

fn main() {
    let (list1, list2) = read_input("input.txt").expect("failed to read input");

    println!("Part 1: {}", part1(list1.clone(), list2.clone()));
    println!("Part 2: {}", part2(&list1, &list2));
}

fn read_input(path: &str) -> Result<(Vec<i64>, Vec<i64>), io::Error> {
    let contents = fs::read_to_string(path)?;

    Ok(contents.lines().filter_map(split_line_into_ints).unzip())
}

fn split_line_into_ints(line: &str) -> Option<(i64, i64)> {
    if line.trim().is_empty() {
        return None;
    }

    let mut iter = line
        .split_ascii_whitespace()
        .map(|n| n.parse::<i64>().unwrap());

    Some((iter.next().unwrap(), iter.next().unwrap()))
}

fn part1(mut list1: Vec<i64>, mut list2: Vec<i64>) -> i64 {
    list1.sort();
    list2.sort();

    list1
        .iter()
        .enumerate()
        .map(|(i, num)| (num - list2[i]).abs())
        .sum()
}

fn part2(list1: &Vec<i64>, list2: &Vec<i64>) -> i64 {
    let right_appearances = list2.iter().fold(HashMap::new(), |mut acc, num| {
        acc.insert(num, acc.get(num).and_then(|cur| Some(cur + 1)).unwrap_or(1));
        acc
    });

    list1
        .iter()
        .map(|num| num * right_appearances.get(num).unwrap_or(&0))
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let (list1, list2) = read_input("example.txt").expect("failed to read input");

        let result = part1(list1.clone(), list2.clone());
        assert_eq!(result, 11);
    }

    #[test]
    fn part2_works() {
        let (list1, list2) = read_input("example.txt").expect("failed to read input");

        let result = part2(&list1, &list2);
        assert_eq!(result, 31);
    }
}
