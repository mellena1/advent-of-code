use std::{fmt, fs::read_to_string};

use grid::{Direction, Point};

fn main() {
    let mut map = read_input("input.txt").expect("failed to read input");
    let mut doubled_map = map.double_width();

    println!("Part 1: {}", part1(&mut map));
    println!("Part 2: {}", part2(&mut doubled_map));
}

fn part1(map: &mut RobotMap) -> u64 {
    map.move_the_robot_all_steps();
    map.get_sum_of_box_gps_coords()
}

fn part2(map: &mut RobotMap) -> u64 {
    map.move_the_robot_all_steps();
    map.get_sum_of_box_gps_coords()
}

fn read_input(path: &str) -> Result<RobotMap, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(RobotMap::from(input.as_str()))
}

struct RobotMap {
    map: Vec<Vec<Object>>,
    cur_robot_loc: Point,
    robot_directions: Vec<Direction>,
}

impl RobotMap {
    fn new(value: &str) -> Self {
        let (map_str, dir_str) = value.split_once("\n\n").expect("should be a newline split");

        let map: Vec<_> = map_str
            .lines()
            .map(|line| line.chars().map(|c| Object::from(c)).collect::<Vec<_>>())
            .collect();

        let dirs = dir_str
            .chars()
            .filter_map(|c| {
                if c.is_whitespace() {
                    None
                } else {
                    Some(dir_from_char(c))
                }
            })
            .collect();

        let robot_loc = find_robot_from_grid(&map);

        Self {
            map,
            cur_robot_loc: robot_loc,
            robot_directions: dirs,
        }
    }

    fn double_width(&self) -> Self {
        let new_map: Vec<_> = self
            .map
            .iter()
            .map(|row| {
                row.iter()
                    .flat_map(|obj| match *obj {
                        Object::Wall => [Object::Wall, Object::Wall],
                        Object::Box => [Object::LeftBox, Object::RightBox],
                        Object::Robot => [Object::Robot, Object::Empty],
                        Object::Empty => [Object::Empty, Object::Empty],
                        _ => panic!("cannot double this object"),
                    })
                    .collect()
            })
            .collect();

        let robot_loc = find_robot_from_grid(&new_map);

        Self {
            map: new_map,
            cur_robot_loc: robot_loc,
            robot_directions: self.robot_directions.clone(),
        }
    }

    fn get_sum_of_box_gps_coords(&self) -> u64 {
        let boxes = self.get_box_locs();

        boxes
            .iter()
            .fold(0, |acc, pos| acc + pos.y as u64 * 100 + pos.x as u64)
    }

    fn get_box_locs(&self) -> Vec<Point> {
        self.map
            .iter()
            .enumerate()
            .flat_map(|(i, row)| {
                row.iter().enumerate().filter_map(move |(j, obj)| {
                    if *obj == Object::Box || *obj == Object::LeftBox {
                        Some(Point { x: j, y: i })
                    } else {
                        None
                    }
                })
            })
            .collect()
    }

    fn move_the_robot_all_steps(&mut self) {
        let robot_dirs = self.robot_directions.clone();
        for dir in robot_dirs.iter() {
            self.move_robot(dir);
        }
    }

    fn move_robot(&mut self, dir: &Direction) {
        let next_pos = new_point_unsafe(&self.cur_robot_loc, dir);

        match self.get_obj_at_loc(&next_pos) {
            Object::Empty => {
                self.move_robot_with_empty_space_behind(&next_pos);
            }
            Object::Wall => {}
            Object::Box => {
                self.find_empty_space_and_move_objs_if_possible(&next_pos, dir);
            }
            Object::Robot => panic!("the robot should never be able to walk into itself"),
            Object::LeftBox => match dir {
                Direction::Up | Direction::Down => {
                    self.move_double_width_boxes_and_robot_vertically_if_possible(&next_pos, dir);
                }
                Direction::Right => {
                    self.find_empty_space_and_move_objs_if_possible(&next_pos, dir);
                }
                Direction::Left => {
                    panic!("can't hit a LeftBox from the left");
                }
            },
            Object::RightBox => match dir {
                Direction::Up | Direction::Down => {
                    self.move_double_width_boxes_and_robot_vertically_if_possible(&next_pos, dir);
                }
                Direction::Left => {
                    self.find_empty_space_and_move_objs_if_possible(&next_pos, dir);
                }
                Direction::Right => {
                    panic!("can't hit a RightBox from the right");
                }
            },
        }
    }

    fn move_robot_with_empty_space_behind(&mut self, next_pos: &Point) {
        let cur_robot_loc = self.cur_robot_loc;
        self.set_obj_at_loc(&cur_robot_loc, Object::Empty);
        self.set_obj_at_loc(&next_pos, Object::Robot);
    }

    fn move_double_width_boxes_and_robot_vertically_if_possible(
        &mut self,
        start_pos: &Point,
        dir: &Direction,
    ) {
        let mut boxes = Vec::new();
        self.find_double_width_boxes_in_the_way(start_pos, dir, &mut boxes);

        if boxes
            .iter()
            .any(|box_pos| self.double_width_box_is_entirely_blocked(box_pos, dir))
        {
            return;
        }

        boxes.sort_by(|a, b| {
            if *dir == Direction::Up {
                a.0.y.cmp(&b.0.y)
            } else {
                b.0.y.cmp(&a.0.y)
            }
        });

        boxes.iter().for_each(|box_pos| {
            self.move_double_width_box_vertically(box_pos, dir);
        });

        self.move_robot_with_empty_space_behind(&start_pos);
    }

    fn move_double_width_box_vertically(&mut self, box_pos: &(Point, Point), dir: &Direction) {
        self.set_obj_at_loc(&new_point_unsafe(&box_pos.0, dir), Object::LeftBox);
        self.set_obj_at_loc(&new_point_unsafe(&box_pos.1, dir), Object::RightBox);
        self.set_obj_at_loc(&box_pos.0, Object::Empty);
        self.set_obj_at_loc(&box_pos.1, Object::Empty);
    }

    fn find_double_width_boxes_in_the_way(
        &self,
        pos: &Point,
        dir: &Direction,
        boxes: &mut Vec<(Point, Point)>,
    ) {
        match self.get_obj_at_loc(pos) {
            Object::LeftBox => {
                let right_pos = new_point_unsafe(pos, &Direction::Right);
                boxes.push((pos.clone(), right_pos));
                self.find_double_width_boxes_in_the_way(&new_point_unsafe(&pos, dir), dir, boxes);
                self.find_double_width_boxes_in_the_way(
                    &new_point_unsafe(&right_pos, dir),
                    dir,
                    boxes,
                );
            }
            Object::RightBox => {
                let left_pos = new_point_unsafe(pos, &Direction::Left);
                boxes.push((left_pos, pos.clone()));
                self.find_double_width_boxes_in_the_way(
                    &new_point_unsafe(&left_pos, dir),
                    dir,
                    boxes,
                );
                self.find_double_width_boxes_in_the_way(&new_point_unsafe(&pos, dir), dir, boxes);
            }
            _ => return,
        }
    }

    fn double_width_box_is_entirely_blocked(
        &self,
        box_loc: &(Point, Point),
        dir: &Direction,
    ) -> bool {
        self.get_obj_at_loc(&new_point_unsafe(&box_loc.0, dir)) == Object::Wall
            || self.get_obj_at_loc(&new_point_unsafe(&box_loc.1, dir)) == Object::Wall
    }

    fn find_empty_space_and_move_objs_if_possible(&mut self, start_pos: &Point, dir: &Direction) {
        let next_empty_space = if let Some(v) = self.find_next_empty_space_from_loc(&start_pos, dir)
        {
            v
        } else {
            return;
        };

        self.move_all_objs_from_empty_to_robot(&next_empty_space, dir);
    }

    fn find_next_empty_space_from_loc(&self, pos: &Point, dir: &Direction) -> Option<Point> {
        let mut next_empty_space = pos.clone();
        loop {
            next_empty_space = new_point_unsafe(&next_empty_space, dir);

            match self.get_obj_at_loc(&next_empty_space) {
                Object::Empty => break,
                Object::Wall => return None,
                _ => {}
            }
        }
        Some(next_empty_space)
    }

    fn move_all_objs_from_empty_to_robot(&mut self, empty_space_pos: &Point, dir: &Direction) {
        let robot_cur_pos = self.cur_robot_loc;
        let mut next_empty_space = empty_space_pos.clone();
        let mut prev_space = next_empty_space;
        loop {
            prev_space = new_point_unsafe(&prev_space, &dir.opposite());
            next_empty_space = new_point_unsafe(&prev_space, &dir);
            self.set_obj_at_loc(&next_empty_space, self.get_obj_at_loc(&prev_space));
            if prev_space == robot_cur_pos {
                self.set_obj_at_loc(&prev_space, Object::Empty);
                break;
            }
        }
    }

    fn get_obj_at_loc(&self, pos: &Point) -> Object {
        self.map[pos.y][pos.x]
    }

    fn set_obj_at_loc(&mut self, pos: &Point, obj: Object) {
        self.map[pos.y][pos.x] = obj;
        if obj == Object::Robot {
            self.cur_robot_loc = pos.clone();
        }
    }
}

impl From<&str> for RobotMap {
    fn from(value: &str) -> Self {
        Self::new(value)
    }
}

impl fmt::Display for RobotMap {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let s = self.map.iter().fold(String::new(), |acc, row| {
            acc + &row
                .iter()
                .fold(String::new(), |acc2: String, obj| acc2 + &obj.to_string())
                + "\n"
        });

        write!(f, "{}", s)
    }
}

#[derive(PartialEq, Eq, Clone, Copy)]
enum Object {
    Wall,
    Box,
    LeftBox,
    RightBox,
    Robot,
    Empty,
}

impl From<char> for Object {
    fn from(value: char) -> Self {
        match value {
            '#' => Object::Wall,
            'O' => Object::Box,
            '@' => Object::Robot,
            '.' => Object::Empty,
            '[' => Object::LeftBox,
            ']' => Object::RightBox,
            _ => panic!("no idea what this obj is"),
        }
    }
}

impl fmt::Display for Object {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Object::Wall => '#',
                Object::Box => 'O',
                Object::Robot => '@',
                Object::Empty => '.',
                Object::RightBox => ']',
                Object::LeftBox => '[',
            }
        )
    }
}

fn dir_from_char(c: char) -> Direction {
    match c {
        '<' => Direction::Left,
        '>' => Direction::Right,
        'v' => Direction::Down,
        '^' => Direction::Up,
        _ => panic!("no idea what this direction is"),
    }
}

fn new_point_unsafe(p: &Point, dir: &Direction) -> Point {
    let (x, y) = p.add_direction(dir);
    Point::new(x, y)
}

fn find_robot_from_grid(map: &Vec<Vec<Object>>) -> Point {
    for (i, row) in map.iter().enumerate() {
        for (j, obj) in row.iter().enumerate() {
            if *obj == Object::Robot {
                return Point { x: j, y: i };
            }
        }
    }
    panic!("no robot found");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let mut map = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&mut map), 10092);
    }

    #[test]
    fn part2_works() {
        let mut doubled_map = read_input("example.txt")
            .expect("failed to read input")
            .double_width();
        assert_eq!(part2(&mut doubled_map), 9021);
    }
}
