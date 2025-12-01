use std::{collections::HashSet, fs::read_to_string};

use grid::{Point, Velocity};

fn main() {
    let hq = read_input("input.txt", 101, 103).expect("failed to read input");
    println!("Part 1: {}", part1(&hq));

    let p2_result = part2(&hq);
    println!("Part 2: {}", p2_result);
    hq.print_grid(&hq.get_all_robots_after_time(p2_result));
}

fn part1(hq: &HQ) -> u64 {
    hq.get_safety_number(100)
}

fn part2(hq: &HQ) -> u64 {
    hq.find_christmas_tree()
}

fn read_input(path: &str, x_len: usize, y_len: usize) -> Result<HQ, std::io::Error> {
    let input = read_to_string(path)?;

    Ok(HQ {
        x_len,
        y_len,

        robots: input.lines().map(|line| Robot::from(line)).collect(),
    })
}

struct HQ {
    x_len: usize,
    y_len: usize,

    robots: Vec<Robot>,
}

impl HQ {
    fn get_safety_number(&self, seconds: u64) -> u64 {
        let mut quadrant_counts = [0, 0, 0, 0];

        self.get_all_robots_after_time(seconds)
            .iter()
            .for_each(|robot| {
                if robot.x < self.x_len / 2 && robot.y < self.y_len / 2 {
                    // top left
                    quadrant_counts[0] += 1
                } else if robot.x < self.x_len / 2 && robot.y > self.y_len / 2 {
                    // bottom left
                    quadrant_counts[1] += 1
                } else if robot.x > self.x_len / 2 && robot.y < self.y_len / 2 {
                    // top right
                    quadrant_counts[2] += 1
                } else if robot.x > self.x_len / 2 && robot.y > self.y_len / 2 {
                    // bottom right
                    quadrant_counts[3] += 1
                }
            });

        quadrant_counts.iter().fold(1, |acc, cnt| acc * cnt)
    }

    fn find_robot_location_after_time(&self, robot: &Robot, seconds: u64) -> Point {
        let total_movement = Velocity {
            x_vel: robot.vel.x_vel * seconds as i64,
            y_vel: robot.vel.y_vel * seconds as i64,
        };

        let (total_x, total_y) = (
            robot.pos.x as i64 + total_movement.x_vel,
            robot.pos.y as i64 + total_movement.y_vel,
        );

        let (wrapped_x, wrapped_y) = (
            total_x.rem_euclid(self.x_len as i64),
            total_y.rem_euclid(self.y_len as i64),
        );

        Point {
            x: wrapped_x as usize,
            y: wrapped_y as usize,
        }
    }

    fn get_all_robots_after_time(&self, seconds: u64) -> Vec<Point> {
        self.robots
            .iter()
            .map(|robot| self.find_robot_location_after_time(robot, seconds))
            .collect()
    }

    fn find_christmas_tree(&self) -> u64 {
        let mut sims: Vec<_> = (0..10_000)
            .map(|seconds| {
                let new_robots: Vec<_> = self.get_all_robots_after_time(seconds);

                let robot_locs = HashSet::from_iter(new_robots.clone());

                let mut total_neighbors: u64 = 0;
                for robot in &new_robots {
                    total_neighbors += self.count_neighbors(&robot, &robot_locs);
                }

                (seconds, total_neighbors)
            })
            .collect();

        sims.sort_by(|a, b| b.1.cmp(&a.1));
        sims[0].0
    }

    fn count_neighbors(&self, robot: &Point, robots: &HashSet<Point>) -> u64 {
        (-1..2).fold(0, |acc, i| {
            acc + (-1..2).fold(0, |acc2, j| {
                if i == 0 && j == 0 {
                    return acc2;
                }

                let new_x = robot.x as i64 + j;
                let new_y = robot.y as i64 + i;
                if new_x < 0 || new_y < 0 {
                    acc2
                } else {
                    if robots.contains(&Point {
                        x: new_x as usize,
                        y: new_y as usize,
                    }) {
                        acc2 + 1
                    } else {
                        acc2
                    }
                }
            })
        })
    }

    fn print_grid(&self, robots: &Vec<Point>) {
        (0..self.y_len).for_each(|i| {
            (0..self.x_len).for_each(|j| {
                if robots.contains(&Point { x: j, y: i }) {
                    print!("X");
                } else {
                    print!(".");
                }
            });
            println!();
        });
    }
}

struct Robot {
    pos: Point,
    vel: Velocity,
}

impl From<&str> for Robot {
    fn from(value: &str) -> Self {
        let (p, v) = value.split_once(" ").expect("must be a space");

        let (px_str, py_str) = p.trim()[2..].split_once(",").expect("must be comma");
        let (px, py): (usize, usize) = (
            px_str.parse().expect("must be num"),
            py_str.parse().expect("must be num"),
        );

        let (vx_str, vy_str) = v.trim()[2..].split_once(",").expect("must be comma");
        let (vx, vy): (i64, i64) = (
            vx_str.parse().expect("must be a num"),
            vy_str.parse().expect("must be a num"),
        );

        Self {
            pos: Point { x: px, y: py },
            vel: Velocity {
                x_vel: vx,
                y_vel: vy,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let hq = read_input("example.txt", 11, 7).expect("failed to read input");
        assert_eq!(part1(&hq), 12);
    }
}
