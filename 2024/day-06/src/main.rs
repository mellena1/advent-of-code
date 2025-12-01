use std::{collections::HashSet, fmt::Display, fs::read_to_string};

fn main() {
    let mut input = read_input("input.txt").expect("failed to read input");
    println!("{}", part1(&mut input));

    let mut input = read_input("input.txt").expect("failed to read input");
    println!("{}", part2(&mut input));
}

fn part1(map: &mut Map) -> u64 {
    map.move_guard_until_off_map();
    map.num_visited_spaces()
}

fn part2(map: &mut Map) -> u64 {
    map.grid.iter().enumerate().fold(0, |acc, (i, row)| {
        acc + row.iter().enumerate().fold(0, |acc2, (j, obj)| {
            if matches!(obj, GridObject::Empty) {
                let mut cloned_map = map.clone();
                cloned_map.grid[i][j] = GridObject::Obstruction;
                if cloned_map.grid_results_in_cycle() {
                    acc2 + 1
                } else {
                    acc2
                }
            } else {
                acc2
            }
        })
    })
}

fn read_input(path: &str) -> Result<Map, std::io::Error> {
    Ok(read_to_string(path)?.into())
}

#[derive(Debug, Clone, Copy, Hash, PartialEq, Eq)]
struct Point {
    x: usize,
    y: usize,
}

#[derive(Debug, Clone)]
struct Map {
    grid: Vec<Vec<GridObject>>,
    visited: Vec<Vec<bool>>,
    cur_guard_pos: Point,
}

impl Map {
    fn num_visited_spaces(&self) -> u64 {
        self.visited.iter().fold(0, |acc, row| {
            acc + (row.iter().filter(|visited| **visited).count() as u64)
        })
    }

    fn grid_results_in_cycle(&mut self) -> bool {
        let mut visited_spaces: HashSet<(Point, Direction)> = HashSet::new();

        loop {
            let cur_dir = self.get_guard_dir();
            let pos_and_dir = (self.cur_guard_pos, cur_dir);

            if visited_spaces.contains(&pos_and_dir) {
                return true;
            }

            visited_spaces.insert(pos_and_dir);

            if !self.move_guard() {
                return false;
            }
        }
    }

    fn move_guard_until_off_map(&mut self) {
        loop {
            if !self.move_guard() {
                break;
            }
        }
    }

    fn move_guard(&mut self) -> bool {
        match self.get_obj_in_front_of_guard() {
            Some((dir, point, obj)) => {
                match obj {
                    GridObject::Empty => {
                        self.grid[point.y][point.x] = GridObject::Guard(dir);
                        self.visited[point.y][point.x] = true;
                        self.grid[self.cur_guard_pos.y][self.cur_guard_pos.x] = GridObject::Empty;
                        self.cur_guard_pos = point;
                    }
                    GridObject::Obstruction => {
                        self.grid[self.cur_guard_pos.y][self.cur_guard_pos.x] =
                            GridObject::Guard(dir.rotate_90_degress());
                    }
                    _ => panic!("invalid obj in front of guard"),
                }
                true
            }
            None => false,
        }
    }

    fn get_guard_dir(&self) -> Direction {
        let obj = &self.grid[self.cur_guard_pos.y][self.cur_guard_pos.x];
        match obj {
            GridObject::Guard(dir) => dir.clone(),
            _ => panic!("obj at guard pos is not the guard"),
        }
    }

    fn get_obj_in_front_of_guard(&self) -> Option<(Direction, Point, GridObject)> {
        let dir = self.get_guard_dir();
        let movement = dir.get_x_y_dir();

        let (x, y) = (
            (self.cur_guard_pos.x as i64) + movement.0,
            (self.cur_guard_pos.y as i64) + movement.1,
        );

        if x < 0 || y < 0 {
            return None;
        }

        self.grid
            .get(y as usize)
            .and_then(|row| row.get(x as usize))
            .and_then(|obj| {
                Some((
                    dir,
                    Point {
                        x: x as usize,
                        y: y as usize,
                    },
                    obj.clone(),
                ))
            })
    }
}

impl From<String> for Map {
    fn from(value: String) -> Self {
        let grid = value
            .lines()
            .map(|line| {
                line.chars()
                    .map(|c| GridObject::from(&c))
                    .collect::<Vec<GridObject>>()
            })
            .collect::<Vec<Vec<GridObject>>>();

        let cur_guard_pos = grid
            .iter()
            .enumerate()
            .find_map(|(i, row)| {
                if let Some(j) = row
                    .iter()
                    .position(|obj| matches!(obj, GridObject::Guard(_)))
                {
                    Some(Point { x: j, y: i })
                } else {
                    None
                }
            })
            .expect("guard not in grid");

        let visited = grid
            .iter()
            .enumerate()
            .map(|(i, row)| {
                row.iter()
                    .enumerate()
                    .map(|(j, _)| i == cur_guard_pos.y && j == cur_guard_pos.x)
                    .collect()
            })
            .collect();

        Self {
            grid,
            visited,
            cur_guard_pos,
        }
    }
}

impl Display for Map {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = self
            .grid
            .iter()
            .map(|row| row.iter().map(|obj| char::from(obj)).collect::<String>())
            .collect::<Vec<String>>()
            .join("\n");

        f.write_str(&s)
    }
}

#[derive(Debug, Clone, Copy, Hash, PartialEq, Eq)]
enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    fn get_x_y_dir(&self) -> (i64, i64) {
        match self {
            Direction::Up => (0, -1),
            Direction::Down => (0, 1),
            Direction::Left => (-1, 0),
            Direction::Right => (1, 0),
        }
    }

    fn rotate_90_degress(&self) -> Self {
        match self {
            Direction::Up => Direction::Right,
            Direction::Down => Direction::Left,
            Direction::Left => Direction::Up,
            Direction::Right => Direction::Down,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum GridObject {
    Empty,
    Guard(Direction),
    Obstruction,
}

impl From<&char> for GridObject {
    fn from(value: &char) -> Self {
        match value {
            '.' => GridObject::Empty,

            '^' => GridObject::Guard(Direction::Up),
            '>' => GridObject::Guard(Direction::Right),
            '<' => GridObject::Guard(Direction::Left),
            'v' => GridObject::Guard(Direction::Down),

            '#' => GridObject::Obstruction,

            _ => panic!("invalid char for input"),
        }
    }
}

impl From<&GridObject> for char {
    fn from(value: &GridObject) -> Self {
        match value {
            GridObject::Empty => '.',

            GridObject::Guard(Direction::Up) => '^',
            GridObject::Guard(Direction::Left) => '<',
            GridObject::Guard(Direction::Right) => '>',
            GridObject::Guard(Direction::Down) => 'v',

            GridObject::Obstruction => '#',
        }
    }
}

#[cfg(test)]
mod tests {
    use std::fs::read_to_string;

    use super::*;

    #[test]
    fn map_back_and_forth_to_str() {
        let path = "example.txt";
        let raw_example = read_to_string(path).expect("read input failed");
        let input = read_input(path).expect("read input failed");

        assert_eq!(input.to_string(), raw_example.trim());
    }

    #[test]
    fn part1_works() {
        let mut input = read_input("example.txt").expect("read input failed");
        let result = part1(&mut input);
        assert_eq!(result, 41);
    }

    #[test]
    fn part2_works() {
        let mut input = read_input("example.txt").expect("read input failed");
        let result = part2(&mut input);
        assert_eq!(result, 6);
    }

    #[test]
    fn cloning_board_works() {
        let mut input = read_input("example.txt").expect("read input failed");
        let cloned_input = input.clone();

        input.grid[0][0] = GridObject::Obstruction;

        assert_eq!(input.grid[0][0], GridObject::Obstruction);
        assert_eq!(cloned_input.grid[0][0], GridObject::Empty);
    }

    #[test]
    fn example_is_not_cycle() {
        let mut input = read_input("example.txt").expect("read input failed");
        let result = input.grid_results_in_cycle();
        assert_eq!(result, false);
    }

    #[test]
    fn example_cycle_is_cycle() {
        let mut input = read_input("example_cycle.txt").expect("read input failed");
        let result = input.grid_results_in_cycle();
        assert_eq!(result, true);
    }
}
