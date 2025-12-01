use std::{collections::HashSet, fs::read_to_string};

use grid::{new_point_if_in_bounds, Direction, Point};
use strum::IntoEnumIterator;

fn main() {
    let map = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&map));
    println!("Part 2: {}", part2(&map));
}

fn part1(map: &GardenMap) -> u64 {
    let area_and_perims = map.get_area_and_perimeters();
    area_and_perims
        .iter()
        .fold(0, |acc, (_, (area, perim))| acc + area * perim)
}

fn part2(map: &GardenMap) -> u64 {
    let area_and_sides = map.get_area_and_sides();
    area_and_sides
        .iter()
        .fold(0, |acc, (_, (area, sides))| acc + area * sides)
}

fn read_input(path: &str) -> Result<GardenMap, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(GardenMap::from(input.as_str()))
}

struct GardenMap {
    map: Vec<Vec<char>>,
}

impl GardenMap {
    fn get_area_and_perimeters(&self) -> Vec<(char, (u64, u64))> {
        let regions = self.find_all_regions();

        regions
            .iter()
            .map(|(c, region)| {
                let area = region.len() as u64;
                let perimeter = self.calc_perimeter_of_region(region);

                (c.clone(), (area, perimeter))
            })
            .collect()
    }

    fn get_area_and_sides(&self) -> Vec<(char, (u64, u64))> {
        let regions = self.find_all_regions();

        regions
            .iter()
            .map(|(c, region)| {
                let area = region.len() as u64;
                let sides = self.calc_sides_of_region(region);

                (c.clone(), (area, sides))
            })
            .collect()
    }

    fn find_all_regions(&self) -> Vec<(char, Vec<Point>)> {
        let mut visited: HashSet<Point> = HashSet::new();
        let mut regions = Vec::new();

        self.map.iter().enumerate().for_each(|(i, row)| {
            row.iter().enumerate().for_each(|(j, _)| {
                let pos = Point { x: j, y: i };

                if visited.contains(&pos) {
                    return;
                }

                let (c, region) = self.find_region_from_pos(&pos);
                visited.extend(region.iter());
                regions.push((c, region));
            });
        });

        regions
    }

    fn find_region_from_pos(&self, cur_pos: &Point) -> (char, Vec<Point>) {
        let c = self.get_val_at_pos(cur_pos);
        let mut region = Vec::new();
        self.find_all_connected_points(cur_pos, c, &mut region);

        (c, region)
    }

    fn find_all_connected_points(
        &self,
        cur_pos: &Point,
        needed_char: char,
        region: &mut Vec<Point>,
    ) {
        if self.get_val_at_pos(cur_pos) != needed_char {
            return;
        }

        region.push(cur_pos.clone());

        Direction::iter()
            .filter_map(|dir| {
                let (x, y) = cur_pos.add_direction(&dir);
                new_point_if_in_bounds(&self.map, x, y)
            })
            .for_each(|pos| {
                if !region.contains(&pos) {
                    self.find_all_connected_points(&pos, needed_char, region)
                }
            });
    }

    fn get_val_at_pos(&self, pos: &Point) -> char {
        self.map[pos.y][pos.x]
    }

    fn calc_perimeter_of_region(&self, region: &Vec<Point>) -> u64 {
        region.iter().fold(0, |acc, pos| {
            let surrounding = self.num_of_same_char_around_pos(pos);
            acc + 4 - surrounding
        })
    }

    fn num_of_same_char_around_pos(&self, pos: &Point) -> u64 {
        self.valid_directions_from_pos(pos).len() as u64
    }

    fn valid_directions_from_pos(&self, pos: &Point) -> Vec<Direction> {
        Direction::iter()
            .filter(|dir| self.neighbor_is_same_as_self(pos, dir))
            .collect()
    }

    fn calc_sides_of_region(&self, region: &Vec<Point>) -> u64 {
        region
            .iter()
            .fold(0, |acc, pos| acc + self.count_corners_from_point(pos))
    }

    fn count_corners_from_point(&self, cur_pos: &Point) -> u64 {
        let diags = [
            [Direction::Up, Direction::Left],
            [Direction::Up, Direction::Right],
            [Direction::Down, Direction::Left],
            [Direction::Down, Direction::Right],
        ];

        diags.iter().fold(0, |acc, diag| {
            let are_same = diag.map(|dir| self.neighbor_is_same_as_self(cur_pos, &dir));
            if are_same[0] == are_same[1] {
                if are_same[0] {
                    // make sure we don't just have a square, because if so, this isn't a corner
                    // i.e.
                    // AA  vs BA
                    // AA     AA

                    if self.diag_neighbor_is_same_as_self(cur_pos, (&diag[0], &diag[1])) {
                        acc
                    } else {
                        acc + 1
                    }
                } else {
                    acc + 1
                }
            } else {
                acc
            }
        })
    }

    fn neighbor_is_same_as_self(&self, pos: &Point, dir: &Direction) -> bool {
        let c = self.get_val_at_pos(pos);
        let (x, y) = pos.add_direction(dir);
        if let Some(next_pos) = new_point_if_in_bounds(&self.map, x, y) {
            c == self.get_val_at_pos(&next_pos)
        } else {
            false
        }
    }

    fn diag_neighbor_is_same_as_self(&self, pos: &Point, dir: (&Direction, &Direction)) -> bool {
        let c = self.get_val_at_pos(pos);
        let (x, y) = pos.add_diagonal_direction(dir);
        if let Some(next_pos) = new_point_if_in_bounds(&self.map, x, y) {
            c == self.get_val_at_pos(&next_pos)
        } else {
            false
        }
    }
}

impl From<&str> for GardenMap {
    fn from(value: &str) -> Self {
        let map = value.lines().map(|line| line.chars().collect()).collect();

        Self { map }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let map = read_input("example.txt").expect("failed to read input");
        let result = part1(&map);
        assert_eq!(result, 1930);
    }

    #[test]
    fn part2_works() {
        let map = read_input("example.txt").expect("failed to read input");
        let result = part2(&map);
        assert_eq!(result, 1206);
    }

    #[test]
    fn get_area_and_perimeter_works() {
        let map = read_input("example.txt").expect("failed to read input");
        let result = map.get_area_and_perimeters();
        assert_eq!(
            &result,
            &[
                ('R', (12, 18)),
                ('I', (4, 8)),
                ('C', (14, 28)),
                ('F', (10, 18)),
                ('V', (13, 20)),
                ('J', (11, 20)),
                ('C', (1, 4)),
                ('E', (13, 18)),
                ('I', (14, 22)),
                ('M', (5, 12)),
                ('S', (3, 8))
            ]
        );
    }

    #[test]
    fn get_area_and_sides_works() {
        let map = read_input("example.txt").expect("failed to read input");
        let result = map.get_area_and_sides();
        assert_eq!(
            &result,
            &[
                ('R', (12, 10)),
                ('I', (4, 4)),
                ('C', (14, 22)),
                ('F', (10, 12)),
                ('V', (13, 10)),
                ('J', (11, 12)),
                ('C', (1, 4)),
                ('E', (13, 8)),
                ('I', (14, 16)),
                ('M', (5, 6)),
                ('S', (3, 6))
            ]
        );
    }
}
