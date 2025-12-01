use std::{collections::VecDeque, fs::read_to_string, num::ParseIntError};

fn main() {
    let equations = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&equations));
    println!("Part 2: {}", part2(&equations));
}

fn part1(equations: &[Equation]) -> i64 {
    equations.iter().fold(0, |acc, eq| {
        if eq.valid_with_any_operation_combos(&[Operation::Add, Operation::Multiply]) {
            acc + eq.result
        } else {
            acc
        }
    })
}

fn part2(equations: &[Equation]) -> i64 {
    equations.iter().fold(0, |acc, eq| {
        if eq.valid_with_any_operation_combos(&[
            Operation::Add,
            Operation::Multiply,
            Operation::Concat,
        ]) {
            acc + eq.result
        } else {
            acc
        }
    })
}

fn read_input(path: &str) -> Result<Vec<Equation>, anyhow::Error> {
    let input = read_to_string(path)?;

    let equation_results: Vec<_> = input.lines().map(|line| Equation::try_from(line)).collect();

    if let Some(err) = equation_results.iter().find(|result| result.is_err()) {
        Err(err.clone().unwrap_err().into())
    } else {
        Ok(equation_results
            .into_iter()
            .map(|result| result.unwrap())
            .collect())
    }
}

#[derive(Clone)]
enum Operation {
    Add,
    Multiply,
    Concat,
}

impl Operation {
    fn calculate(&self, a: i64, b: i64) -> i64 {
        match self {
            Operation::Add => a + b,
            Operation::Multiply => a * b,
            Operation::Concat => format!("{a}{b}").parse().unwrap(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Equation {
    result: i64,
    nums: Vec<i64>,
}

#[derive(thiserror::Error, Debug)]
enum EquationError {
    #[error("ops must be 1 less than nums")]
    InvalidNumberOfOperations,
}

impl Equation {
    fn valid_with_any_operation_combos(&self, op_options: &[Operation]) -> bool {
        self.build_operation_combo_and_check_if_any_valid(&[], op_options)
    }

    fn build_operation_combo_and_check_if_any_valid(
        &self,
        ops: &[Operation],
        op_options: &[Operation],
    ) -> bool {
        if ops.len() == self.nums.len() - 1 {
            self.valid_with_operations(ops)
                .expect("should never be the wrong size")
        } else {
            op_options.iter().any(|op| {
                self.build_operation_combo_and_check_if_any_valid(
                    &[ops, &[op.clone()]].concat(),
                    op_options,
                )
            })
        }
    }

    fn valid_with_operations(&self, ops: &[Operation]) -> Result<bool, EquationError> {
        if ops.len() != self.nums.len() - 1 {
            return Err(EquationError::InvalidNumberOfOperations);
        }

        let mut nums_stack: VecDeque<i64> = VecDeque::with_capacity(self.nums.len());
        self.nums.iter().for_each(|n| nums_stack.push_front(*n));

        let mut ops_stack = VecDeque::with_capacity(ops.len());
        ops.iter().for_each(|op| ops_stack.push_front(op));

        while nums_stack.len() > 1 {
            let a = nums_stack.pop_back().expect("stack should never be empty");
            let b = nums_stack.pop_back().expect("stack should never be empty");
            let op = ops_stack.pop_back().expect("stack should never be empty");

            let c = op.calculate(a, b);
            nums_stack.push_back(c);
        }

        let actual = nums_stack.pop_back().expect("stack should never be empty");
        Ok(actual == self.result)
    }
}

#[derive(thiserror::Error, Debug, Clone)]
enum EquationParseError {
    #[error("failed to split on :")]
    FailedToSplitError,
    #[error("failed parsing to int")]
    FailedParsingToInt(#[from] ParseIntError),
}

impl TryFrom<&str> for Equation {
    type Error = EquationParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        let (left, right) = value
            .split_once(":")
            .ok_or(EquationParseError::FailedToSplitError)?;

        let result = left
            .parse()
            .map_err(|e| EquationParseError::FailedParsingToInt(e))?;

        let num_results: Vec<_> = right
            .trim()
            .split_whitespace()
            .map(|s| {
                s.parse::<i64>()
                    .map_err(|e| EquationParseError::FailedParsingToInt(e))
            })
            .collect();
        let nums = if let Some(err) = num_results.iter().find(|result| result.is_err()) {
            return Err(err.clone().unwrap_err());
        } else {
            num_results
                .into_iter()
                .map(|result| result.unwrap())
                .collect()
        };

        Ok(Self { result, nums })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let input = read_input("example.txt").expect("failed to read input");
        let result = part1(&input);
        assert_eq!(result, 3749);
    }

    #[test]
    fn part2_works() {
        let input = read_input("example.txt").expect("failed to read input");
        let result = part2(&input);
        assert_eq!(result, 11387);
    }

    #[test]
    fn parsing_equation_works() {
        let result = Equation::try_from("161011: 16 10 13");
        assert_eq!(result.is_ok(), true);
        assert_eq!(
            result.unwrap(),
            Equation {
                result: 161011,
                nums: vec![16, 10, 13]
            }
        );
    }
}
