use std::{
    collections::{HashMap, HashSet},
    fs::read_to_string,
};

use itertools::Itertools;

fn main() {
    let map = read_input("input.txt").expect("failed to read input");
    println!("{}", part1(&map));
    println!("{}", part2(&map));
}

fn read_input(path: &str) -> Result<Map, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(Map::from(input))
}

fn part1(map: &Map) -> u64 {
    map.get_antinode_locations(false).len() as u64
}

fn part2(map: &Map) -> u64 {
    map.get_antinode_locations(true).len() as u64
}

struct Map {
    grid: Vec<Vec<GridObject>>,
}

impl From<String> for Map {
    fn from(value: String) -> Self {
        let grid = value
            .lines()
            .map(|line| line.chars().map(|c| GridObject::from(c)).collect())
            .collect();

        Self { grid }
    }
}

impl Map {
    fn get_antinode_locations(&self, allow_any_distance: bool) -> HashSet<Point> {
        let mut antinodes = HashSet::new();

        let antennas = self.get_grouped_antennas();

        antennas.iter().for_each(|(_, points)| {
            self.get_antinodes_by_points(points, allow_any_distance)
                .into_iter()
                .for_each(|p| {
                    antinodes.insert(p);
                });
        });

        antinodes
    }

    fn get_antinodes_by_points(&self, points: &[Point], allow_any_distance: bool) -> Vec<Point> {
        points
            .iter()
            .combinations(2)
            .flat_map(|combo| {
                self.get_antinodes_for_antennas(combo[0], combo[1], allow_any_distance)
            })
            .collect()
    }

    fn get_antinodes_for_antennas(
        &self,
        a: &Point,
        b: &Point,
        allow_any_distance: bool,
    ) -> Vec<Point> {
        let max_x = self.grid[0].len() - 1;
        let max_y = self.grid.len() - 1;

        let orig_x_diff = a.x.abs_diff(b.x) as i64;
        let orig_y_diff = a.y.abs_diff(b.y) as i64;

        let mut antinodes = Vec::new();

        let mut i = if allow_any_distance { 0 } else { 1 };
        loop {
            let x_diff = orig_x_diff * i;
            let y_diff = orig_y_diff * i;

            let possible_antinodes = if a.x < b.x {
                if a.y < b.y {
                    vec![
                        Point::new_if_in_bounds(a.x as i64 - x_diff, a.y as i64 - y_diff),
                        Point::new_if_in_bounds(b.x as i64 + x_diff, b.y as i64 + y_diff),
                    ]
                } else {
                    vec![
                        Point::new_if_in_bounds(a.x as i64 - x_diff, a.y as i64 + y_diff),
                        Point::new_if_in_bounds(b.x as i64 + x_diff, b.y as i64 - y_diff),
                    ]
                }
            } else {
                if a.y < b.y {
                    vec![
                        Point::new_if_in_bounds(a.x as i64 + x_diff, a.y as i64 - y_diff),
                        Point::new_if_in_bounds(b.x as i64 - x_diff, b.y as i64 + y_diff),
                    ]
                } else {
                    vec![
                        Point::new_if_in_bounds(a.x as i64 + x_diff, a.y as i64 + y_diff),
                        Point::new_if_in_bounds(b.x as i64 - x_diff, b.y as i64 - y_diff),
                    ]
                }
            };

            let mut new_antinodes: Vec<Point> = possible_antinodes
                .into_iter()
                .flatten()
                .filter(|point| point.x <= max_x && point.y <= max_y)
                .collect();
            let new_antinodes_is_empty = new_antinodes.is_empty();

            if !new_antinodes_is_empty {
                antinodes.append(&mut new_antinodes);
            }

            if !allow_any_distance || new_antinodes_is_empty {
                break;
            }

            i += 1;
        }

        antinodes
    }

    fn get_grouped_antennas(&self) -> HashMap<GridObject, Vec<Point>> {
        let mut antenna_map: HashMap<GridObject, Vec<Point>> = HashMap::new();

        self.grid.iter().enumerate().for_each(|(i, row)| {
            row.iter().enumerate().for_each(|(j, obj)| {
                if matches!(obj, GridObject::Antenna(_)) {
                    if let Some(existing_vec) = antenna_map.get_mut(obj) {
                        existing_vec.push(Point { x: j, y: i })
                    } else {
                        antenna_map.insert(obj.clone(), vec![Point { x: j, y: i }]);
                    }
                }
            });
        });

        antenna_map
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Copy, Debug)]
enum GridObject {
    Antenna(char),
    Empty,
}

impl From<char> for GridObject {
    fn from(value: char) -> Self {
        match value {
            '.' => GridObject::Empty,
            _ => GridObject::Antenna(value),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Hash)]
struct Point {
    x: usize,
    y: usize,
}

impl Point {
    fn new_if_in_bounds(x: i64, y: i64) -> Option<Self> {
        if x < 0 || y < 0 {
            None
        } else {
            Some(Point {
                x: x as usize,
                y: y as usize,
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let input = read_input("example.txt").expect("failed to get input");
        let result = part1(&input);
        assert_eq!(result, 14);
    }

    #[test]
    fn part2_works() {
        let easy_input = read_input("example_2.txt").expect("failed to get input");
        let easy_result = part2(&easy_input);
        assert_eq!(easy_result, 9);

        let input = read_input("example.txt").expect("failed to get input");
        let result = part2(&input);
        assert_eq!(result, 34);
    }

    #[test]
    fn get_grouped_antennas_works() {
        let input = read_input("example.txt").expect("failed to get input");
        let result = input.get_grouped_antennas();

        assert_eq!(
            result
                .get(&GridObject::Antenna('0'))
                .expect("0 should be in map")
                .as_slice(),
            &[
                Point { x: 8, y: 1 },
                Point { x: 5, y: 2 },
                Point { x: 7, y: 3 },
                Point { x: 4, y: 4 },
            ]
        );

        assert_eq!(
            result
                .get(&GridObject::Antenna('A'))
                .expect("0 should be in map")
                .as_slice(),
            &[
                Point { x: 6, y: 5 },
                Point { x: 8, y: 8 },
                Point { x: 9, y: 9 },
            ]
        );
    }

    #[test]
    fn get_antinodes_for_antennas_works() {
        let input = read_input("example.txt").expect("failed to get input");
        let result =
            input.get_antinodes_for_antennas(&Point { x: 4, y: 3 }, &Point { x: 5, y: 5 }, false);
        assert_eq!(
            result.as_slice(),
            &[Point { x: 3, y: 1 }, Point { x: 6, y: 7 }]
        );

        let result_oob =
            input.get_antinodes_for_antennas(&Point { x: 4, y: 3 }, &Point { x: 8, y: 4 }, false);
        assert_eq!(result_oob.as_slice(), &[Point { x: 0, y: 2 }]);
    }
}
