use std::{
    cmp::Ordering,
    collections::{BinaryHeap, HashMap},
    fmt::Display,
    fs::read_to_string,
    usize,
};

use grid::Point;

fn main() {
    let mut comp = read_input("input.txt", 71).expect("failed to read input");
    comp.bytes_dropped = 1024;
    println!("Part 1: {}", part1(&comp));
    println!("Part 2: {:?}", part2(&mut comp));
}

fn part1(comp: &ElfComputer) -> usize {
    comp.find_min_steps_to_exit()
}

fn part2(comp: &mut ElfComputer) -> Point {
    loop {
        comp.bytes_dropped += 1;

        let steps = comp.find_min_steps_to_exit();
        if steps == usize::MAX {
            return comp.byte_locs[comp.bytes_dropped - 1];
        }
    }
}

fn read_input(path: &str, size: usize) -> Result<ElfComputer, std::io::Error> {
    let input = read_to_string(&path)?;

    let bytes = input.lines().map(|line| {
        let (x_str, y_str) = line.split_once(",").expect("line must have comma");

        Point::new(
            x_str.parse().expect("x must be int"),
            y_str.parse().expect("y must be int"),
        )
    });

    Ok(ElfComputer {
        grid_size: size,
        byte_locs: bytes.collect(),
        bytes_dropped: 0,
    })
}

struct ElfComputer {
    grid_size: usize,

    byte_locs: Vec<Point>,
    bytes_dropped: usize,
}

impl ElfComputer {
    fn find_min_steps_to_exit(&self) -> usize {
        let mut dist: HashMap<Point, usize> = (0..self.grid_size)
            .flat_map(|x| (0..self.grid_size).map(move |y| (Point { x, y }, usize::MAX)))
            .collect();

        let mut heap = BinaryHeap::new();

        dist.insert(Point { x: 0, y: 0 }, 0);
        heap.push(State {
            cost: 0,
            position: Point { x: 0, y: 0 },
        });

        let end = Point {
            x: self.grid_size - 1,
            y: self.grid_size - 1,
        };

        while let Some(State { cost, position }) = heap.pop() {
            if position == end {
                return cost;
            }

            if cost > *dist.get(&position).unwrap() {
                continue;
            }

            for neighbor in self.neighbors(&position) {
                let dist_to_neighbor = dist.get(&position).unwrap() + 1;

                if dist_to_neighbor < *dist.get(&neighbor).unwrap() {
                    dist.insert(neighbor, dist_to_neighbor);
                    heap.push(State {
                        cost: dist_to_neighbor,
                        position: neighbor,
                    });
                }
            }
        }

        *dist.get(&end).unwrap()
    }

    fn byte_in_the_way(&self, p: &Point) -> bool {
        self.byte_locs[0..self.bytes_dropped].contains(&p)
    }

    fn neighbors(&self, p: &Point) -> Vec<Point> {
        (-1_i64..=1)
            .flat_map(|i| {
                (-1_i64..=1).filter_map(move |j| {
                    if i != 0 && j != 0 {
                        return None; // can't move diagonally
                    }

                    let new_x = p.x as i64 + j;
                    let new_y = p.y as i64 + i;

                    if self.is_in_bounds(new_x, new_y) {
                        let p = Point::new(new_x, new_y);
                        if self.byte_in_the_way(&p) {
                            None
                        } else {
                            Some(p)
                        }
                    } else {
                        None
                    }
                })
            })
            .collect()
    }

    fn is_in_bounds(&self, x: i64, y: i64) -> bool {
        x >= 0 && x < self.grid_size as i64 && y >= 0 && y < self.grid_size as i64
    }
}

impl Display for ElfComputer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = (0..self.grid_size)
            .map(|i| {
                (0..self.grid_size)
                    .map(|j| {
                        if self.byte_in_the_way(&Point { x: j, y: i }) {
                            "#"
                        } else {
                            "."
                        }
                    })
                    .collect::<Vec<_>>()
                    .join("")
            })
            .collect::<Vec<_>>()
            .join("\n");

        write!(f, "{}", s)
    }
}

#[derive(Copy, Clone, Eq, PartialEq)]
struct State {
    cost: usize,
    position: Point,
}

impl Ord for State {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .cost
            .cmp(&self.cost)
            .then_with(|| self.position.cmp(&other.position))
    }
}

impl PartialOrd for State {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let mut comp = read_input("example.txt", 7).expect("failed to read input");
        comp.bytes_dropped = 12;
        assert_eq!(part1(&mut comp), 22);
    }

    #[test]
    fn part2_works() {
        let mut comp = read_input("example.txt", 7).expect("failed to read input");
        comp.bytes_dropped = 12;
        assert_eq!(part2(&mut comp), Point { x: 6, y: 1 });
    }
}
