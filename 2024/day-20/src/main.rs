use core::panic;
use std::{
    cmp::Ordering,
    collections::{BinaryHeap, HashMap},
    fs::read_to_string,
};

use grid::Point;

fn main() {
    let map = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&map, 100));
    println!("Part 2: {}", part2(&map, 100));
}

fn part1(map: &Map, save_at_least: usize) -> usize {
    find_amount_of_cheats(map, 2, save_at_least)
}

fn part2(map: &Map, save_at_least: usize) -> usize {
    find_amount_of_cheats(map, 20, save_at_least)
}

fn find_amount_of_cheats(map: &Map, max_cheat_steps: usize, save_at_least: usize) -> usize {
    let dists_from_start = map.dijkstra(&map.start_loc);
    let dists_from_end = map.dijkstra(&map.end_loc);
    let non_cheating_dist = *dists_from_start.get(&map.end_loc).unwrap();

    let points: Vec<Point> = dists_from_start.keys().map(|p| p.clone()).collect();

    points.iter().fold(0, |acc, p| {
        acc + points.iter().fold(0, |acc, p2| {
            let steps_to_p2 = p.x.abs_diff(p2.x) + p.y.abs_diff(p2.y);
            if steps_to_p2 > max_cheat_steps {
                return acc;
            }

            let cheating_dist =
                dists_from_start.get(&p).unwrap() + steps_to_p2 + dists_from_end.get(&p2).unwrap();

            if cheating_dist < non_cheating_dist
                && non_cheating_dist - cheating_dist >= save_at_least
            {
                acc + 1
            } else {
                acc
            }
        })
    })
}

fn read_input(path: &str) -> Result<Map, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(Map::from(input.as_str()))
}

struct Map {
    grid: Vec<Vec<GridObject>>,
    start_loc: Point,
    end_loc: Point,
}

impl Map {
    fn dijkstra(&self, start: &Point) -> HashMap<Point, usize> {
        let mut dist: HashMap<Point, usize> = (0..self.grid[0].len())
            .flat_map(|x| (0..self.grid.len()).map(move |y| (Point { x, y }, usize::MAX)))
            .collect();

        let mut heap = BinaryHeap::new();

        dist.insert(*start, 0);
        heap.push(State {
            cost: 0,
            position: *start,
        });

        while let Some(State { cost, position }) = heap.pop() {
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

        // filter out any inaccessible points
        dist.into_iter().filter(|(_, d)| *d < usize::MAX).collect()
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
                        if self.grid[p.y][p.x] == GridObject::Empty {
                            Some(p)
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                })
            })
            .collect()
    }

    fn is_in_bounds(&self, x: i64, y: i64) -> bool {
        x >= 0 && x < self.grid[0].len() as i64 && y >= 0 && y < self.grid.len() as i64
    }
}

impl From<&str> for Map {
    fn from(value: &str) -> Self {
        let mut start_loc = Point { x: 0, y: 0 };
        let mut end_loc = Point { x: 0, y: 0 };
        let grid = value
            .lines()
            .enumerate()
            .map(|(i, line)| {
                line.chars()
                    .enumerate()
                    .map(|(j, c)| match c {
                        'S' => {
                            start_loc = Point { x: j, y: i };
                            GridObject::Empty
                        }
                        'E' => {
                            end_loc = Point { x: j, y: i };
                            GridObject::Empty
                        }
                        _ => GridObject::from(c),
                    })
                    .collect()
            })
            .collect();

        Self {
            grid,
            start_loc,
            end_loc,
        }
    }
}

#[derive(PartialEq, Eq, Clone, Copy)]
enum GridObject {
    Wall,
    Empty,
}

impl From<char> for GridObject {
    fn from(value: char) -> Self {
        match value {
            '#' => Self::Wall,
            '.' => Self::Empty,
            _ => panic!("invalid char for gridobject"),
        }
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
        let map = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&map, 20), 5);
        assert_eq!(part1(&map, 12), 8);
        assert_eq!(part1(&map, 10), 10);
    }

    #[test]
    fn part2_works() {
        let map = read_input("example.txt").expect("failed to read input");
        assert_eq!(part2(&map, 72), 29);
        assert_eq!(part2(&map, 70), 41);
    }
}
