use std::{collections::HashMap, fs::read_to_string};

fn main() {
    let towels = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&towels));
    println!("Part 2: {}", part2(&towels));
}

fn part1(towels: &Towels) -> usize {
    towels.amount_of_requested_possible()
}

fn part2(towels: &Towels) -> usize {
    towels.amount_of_combos_possible()
}

fn read_input(path: &str) -> Result<Towels, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(Towels::from(input.as_str()))
}

struct Towels {
    available_designs: Vec<Vec<Color>>,
    requested_designs: Vec<Vec<Color>>,
}

impl Towels {
    fn amount_of_requested_possible(&self) -> usize {
        let mut cache: HashMap<String, Option<usize>> = HashMap::new();
        self.requested_designs.iter().fold(0, |acc, design| {
            if let Some(_) = self.design_is_possible(&design, &mut cache) {
                acc + 1
            } else {
                acc
            }
        })
    }

    fn amount_of_combos_possible(&self) -> usize {
        let mut cache: HashMap<String, Option<usize>> = HashMap::new();
        self.requested_designs.iter().fold(0, |acc, design| {
            if let Some(num_times) = self.design_is_possible(&design, &mut cache) {
                acc + num_times
            } else {
                acc
            }
        })
    }

    fn design_is_possible(
        &self,
        design: &[Color],
        cache: &mut HashMap<String, Option<usize>>,
    ) -> Option<usize> {
        if design.len() == 0 {
            return Some(1);
        }

        let design_str = design_to_str(design);
        if let Some(result) = cache.get(&design_str) {
            return *result;
        }

        let mut combos = 0;
        for avail in self.available_designs.iter() {
            if avail.len() <= design.len() && design[0..avail.len()] == *avail.as_slice() {
                if let Some(num_times) = self.design_is_possible(&design[avail.len()..], cache) {
                    combos += num_times;
                }
            }
        }

        if combos > 0 {
            cache.insert(design_str, Some(combos));
            Some(combos)
        } else {
            cache.insert(design_str, None);
            None
        }
    }
}

fn design_to_str(design: &[Color]) -> String {
    design.iter().map(|c| Into::<char>::into(*c)).collect()
}

impl From<&str> for Towels {
    fn from(value: &str) -> Self {
        let lines: Vec<_> = value.lines().collect();

        let avaiable: Vec<Vec<_>> = lines[0]
            .split(",")
            .map(|towel| towel.trim().chars().map(|c| Color::from(c)).collect())
            .collect();

        let requested: Vec<Vec<_>> = lines[2..lines.len()]
            .iter()
            .map(|line| line.chars().map(|c| Color::from(c)).collect())
            .collect();

        Self {
            available_designs: avaiable,
            requested_designs: requested,
        }
    }
}

#[derive(PartialEq, Eq, Debug, Hash, Clone, Copy)]
enum Color {
    White,
    Blue,
    Black,
    Red,
    Green,
}

impl Into<char> for Color {
    fn into(self) -> char {
        match self {
            Color::White => 'w',
            Color::Blue => 'u',
            Color::Black => 'b',
            Color::Red => 'r',
            Color::Green => 'g',
        }
    }
}

impl From<char> for Color {
    fn from(value: char) -> Self {
        match value {
            'r' => Color::Red,
            'w' => Color::White,
            'b' => Color::Black,
            'u' => Color::Blue,
            'g' => Color::Green,
            _ => panic!("not a valid color"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let towels = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&towels), 6);
    }

    #[test]
    fn part2_works() {
        let towels = read_input("example.txt").expect("failed to read input");
        assert_eq!(part2(&towels), 16);
    }
}
