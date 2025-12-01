use strum::EnumIter;

#[derive(Debug, EnumIter, PartialEq, Eq, Clone, Copy, Hash, PartialOrd, Ord)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    fn translate(&self, x: i64, y: i64) -> (i64, i64) {
        match self {
            Direction::Up => (x, y - 1),
            Direction::Down => (x, y + 1),
            Direction::Left => (x - 1, y),
            Direction::Right => (x + 1, y),
        }
    }

    pub fn opposite(&self) -> Self {
        match self {
            Direction::Up => Direction::Down,
            Direction::Down => Direction::Up,
            Direction::Left => Direction::Right,
            Direction::Right => Direction::Left,
        }
    }

    pub fn turns_to_other_dir(&self, other: &Direction) -> u64 {
        match self {
            Direction::Up => match other {
                Direction::Up => 0,
                Direction::Down => 2,
                Direction::Left => 1,
                Direction::Right => 1,
            },
            Direction::Down => match other {
                Direction::Up => 2,
                Direction::Down => 0,
                Direction::Left => 1,
                Direction::Right => 1,
            },
            Direction::Left => match other {
                Direction::Up => 1,
                Direction::Down => 1,
                Direction::Left => 0,
                Direction::Right => 2,
            },
            Direction::Right => match other {
                Direction::Up => 1,
                Direction::Down => 1,
                Direction::Left => 2,
                Direction::Right => 0,
            },
        }
    }
}

pub struct Velocity {
    pub x_vel: i64,
    pub y_vel: i64,
}

#[derive(Debug, PartialEq, Eq, Clone, Copy, Hash, PartialOrd, Ord)]
pub struct Point {
    pub x: usize,
    pub y: usize,
}

impl Point {
    pub fn new(x: i64, y: i64) -> Self {
        Self {
            x: x as usize,
            y: y as usize,
        }
    }

    pub fn add_direction(&self, dir: &Direction) -> (i64, i64) {
        let x = self.x as i64;
        let y = self.y as i64;
        dir.translate(x, y)
    }

    pub fn add_diagonal_direction(&self, dir: (&Direction, &Direction)) -> (i64, i64) {
        let mut x = self.x as i64;
        let mut y = self.y as i64;

        (x, y) = dir.0.translate(x, y);
        dir.1.translate(x, y)
    }

    pub fn direction_to_point(&self, other: &Point) -> Direction {
        if self.x != other.x && self.y != other.y {
            panic!("must be parallel");
        }

        if self.x == other.x {
            if self.y < other.y {
                Direction::Down
            } else {
                Direction::Up
            }
        } else {
            if self.x < other.x {
                Direction::Right
            } else {
                Direction::Left
            }
        }
    }

    pub fn distance_to_point(&self, other: &Point) -> u64 {
        match self.direction_to_point(other) {
            Direction::Up | Direction::Down => self.y.abs_diff(other.y) as u64,
            Direction::Left | Direction::Right => self.x.abs_diff(other.x) as u64,
        }
    }

    pub fn points_between_other(&self, other: &Point) -> Vec<Point> {
        let dir = self.direction_to_point(other);

        let mut points = Vec::new();

        let mut cur = self.clone();
        loop {
            let (x, y) = cur.add_direction(&dir);
            cur = Point::new(x, y);

            if cur == *other {
                break;
            }

            points.push(cur);
        }

        points
    }
}

pub fn new_point_if_in_bounds<T>(grid: &Vec<Vec<T>>, x: i64, y: i64) -> Option<Point> {
    if x < 0 || y < 0 || x >= grid[0].len() as i64 || y >= grid.len() as i64 {
        None
    } else {
        Some(Point::new(x, y))
    }
}
