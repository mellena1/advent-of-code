use std::fs::read_to_string;
use strum::{EnumIter, IntoEnumIterator};

fn main() {
    let letters = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part_1(&letters));
    println!("Part 2: {}", part_2(&letters));
}

fn read_input(path: &str) -> Result<Vec<Vec<Letter>>, std::io::Error> {
    let letters = read_to_string(path)?
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.chars().map(|c| Letter::from(c)).collect())
            }
        })
        .collect();
    Ok(letters)
}

fn part_1(letters: &Vec<Vec<Letter>>) -> u64 {
    num_of_xmas_in_word_search(letters)
}

fn num_of_xmas_in_word_search(letters: &Vec<Vec<Letter>>) -> u64 {
    letters
        .iter()
        .enumerate()
        .map(|(i, row)| {
            row.iter()
                .enumerate()
                .map(|(j, _)| num_xmas_from_letter(&letters, Point { x: j, y: i }, Letter::X, None))
                .sum::<u64>()
        })
        .sum()
}

fn num_xmas_from_letter(
    letters: &Vec<Vec<Letter>>,
    coor: Point,
    needed_letter: Letter,
    cur_direction: Option<Direction>,
) -> u64 {
    let cur_letter = letters[coor.y][coor.x];

    if cur_letter != needed_letter {
        return 0;
    }

    match cur_letter {
        Letter::S => return 1,
        Letter::X => Direction::iter()
            .map(|dir| move_to_next_letter(letters, coor, Letter::M, dir))
            .sum(),
        _ => {
            let dir = cur_direction.expect("should already have a known direction for M and A");
            move_to_next_letter(
                letters,
                coor,
                match cur_letter {
                    Letter::M => Letter::A,
                    Letter::A => Letter::S,
                    _ => panic!("can't get here"),
                },
                dir,
            )
        }
    }
}

fn move_to_next_letter(
    letters: &Vec<Vec<Letter>>,
    coor: Point,
    needed_letter: Letter,
    dir: Direction,
) -> u64 {
    let new_coor_opt = coor.add_direction(dir);
    match new_coor_opt {
        Some(new_coor) => {
            if new_coor.is_out_of_bounds(letters) {
                0
            } else {
                num_xmas_from_letter(letters, new_coor, needed_letter, Some(dir))
            }
        }
        None => 0,
    }
}

fn part_2(letters: &Vec<Vec<Letter>>) -> u64 {
    num_of_crossing_mas_in_word_search(letters)
}

fn num_of_crossing_mas_in_word_search(letters: &Vec<Vec<Letter>>) -> u64 {
    letters
        .iter()
        .enumerate()
        .map(|(i, row)| {
            row.iter()
                .enumerate()
                .map(|(j, letter)| match letter {
                    Letter::A => {
                        let coor = Point { x: j, y: i };

                        if is_valid_mas(letters, coor, [Direction::DownLeft, Direction::UpRight])
                            && is_valid_mas(
                                letters,
                                coor,
                                [Direction::DownRight, Direction::UpLeft],
                            )
                        {
                            1
                        } else {
                            0
                        }
                    }
                    _ => 0,
                })
                .sum::<u64>()
        })
        .sum()
}

fn is_valid_mas(letters: &Vec<Vec<Letter>>, coor: Point, directions: [Direction; 2]) -> bool {
    let neighbors = directions.map(|dir| match coor.add_direction(dir) {
        Some(new_coor) => {
            if new_coor.is_out_of_bounds(letters) {
                None
            } else {
                Some(letters[new_coor.y][new_coor.x])
            }
        }
        None => None,
    });

    match neighbors {
        [Some(Letter::M), Some(Letter::S)] => true,
        [Some(Letter::S), Some(Letter::M)] => true,
        _ => false,
    }
}

#[derive(Clone, Copy, PartialEq)]
enum Letter {
    X,
    M,
    A,
    S,
}

impl From<char> for Letter {
    fn from(item: char) -> Self {
        match item {
            'X' => Self::X,
            'M' => Self::M,
            'A' => Self::A,
            'S' => Self::S,
            _ => panic!("unknown input"),
        }
    }
}

#[derive(Clone, Copy, EnumIter)]
enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

impl Direction {
    fn get_x_y_movement(self) -> (i32, i32) {
        match self {
            Direction::Up => (0, -1),
            Direction::Down => (0, 1),
            Direction::Left => (-1, 0),
            Direction::Right => (1, 0),
            Direction::UpLeft => (-1, -1),
            Direction::UpRight => (1, -1),
            Direction::DownLeft => (-1, 1),
            Direction::DownRight => (1, 1),
        }
    }
}

#[derive(Clone, Copy)]
struct Point {
    x: usize,
    y: usize,
}

impl Point {
    fn add_direction(self, dir: Direction) -> Option<Point> {
        let movement = dir.get_x_y_movement();
        let x = (self.x as i32) + movement.0;
        let y = (self.y as i32) + movement.1;
        if x < 0 || y < 0 {
            return None;
        }
        Some(Point {
            x: x as usize,
            y: y as usize,
        })
    }

    fn is_out_of_bounds<T>(self, grid: &Vec<Vec<T>>) -> bool {
        self.y >= grid.len() || self.x >= grid[0].len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let letters = read_input("example.txt").expect("failed to read input");
        let result = part_1(&letters);

        assert_eq!(result, 18);
    }

    #[test]
    fn part2_works() {
        let letters = read_input("example.txt").expect("failed to read input");
        let result = part_2(&letters);

        assert_eq!(result, 9);
    }
}
