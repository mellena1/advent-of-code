use std::{
    cmp::Ordering,
    collections::{BinaryHeap, HashMap, HashSet},
    fs::read_to_string,
};

use grid::{Direction, Point};
use petgraph::{
    prelude::DiGraphMap,
    visit::{VisitMap, Visitable},
};
use strum::IntoEnumIterator;

fn main() {
    let map = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&map));
    println!("Part 2: {}", part2(&map));
}

fn part1(map: &Map) -> u64 {
    map.lowest_score()
}

fn part2(map: &Map) -> u64 {
    map.num_tiles_on_best_paths()
}

fn read_input(path: &str) -> Result<Map, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(Map::from(input.as_str()))
}

struct Map {
    graph: DiGraphMap<Node, u64>,
    starting_node: Node,
    ending_nodes: Vec<Node>,
}

impl From<&str> for Map {
    fn from(value: &str) -> Self {
        let raw_map: Vec<Vec<char>> = value.lines().map(|line| line.chars().collect()).collect();
        Self::new(&raw_map)
    }
}

impl Map {
    fn new(raw_map: &Vec<Vec<char>>) -> Self {
        let corners = find_corners_in_raw_map(&raw_map);
        let edges = find_edges(raw_map, &corners);

        let mut graph = DiGraphMap::new();
        let starting_node = Node {
            pos: Point {
                x: 1,
                y: raw_map.len() - 2,
            },
            reindeer_dir: Direction::Right,
        };
        let mut ending_nodes = Vec::new();

        edges.iter().for_each(|(c1, c2)| {
            let dir_to_c2 = c1.direction_to_point(c2);

            let c2_node = Node {
                pos: c2.clone(),
                reindeer_dir: dir_to_c2,
            };

            if raw_map[c2.y][c2.x] == 'E' {
                ending_nodes.push(c2_node);
            }

            Direction::iter().for_each(|dir| {
                let cost_of_turn = dir.turns_to_other_dir(&dir_to_c2) * 1000;
                let cost_of_walking = c1.distance_to_point(&c2);

                let c1_node = Node {
                    pos: c1.clone(),
                    reindeer_dir: dir,
                };

                graph.add_edge(c1_node, c2_node, cost_of_turn + cost_of_walking);
            });
        });

        Self {
            graph,
            starting_node,
            ending_nodes,
        }
    }

    fn lowest_score(&self) -> u64 {
        self.ending_nodes
            .iter()
            .map(|end_node| {
                let (score, _) = self.dijkstra(self.starting_node, *end_node);
                score
            })
            .min()
            .expect("should have a min weight")
    }

    fn dijkstra(&self, start: Node, end: Node) -> (u64, Vec<Vec<Node>>) {
        // essentially a recreation of petgraph's dijkstra fn, but wtih no generics, and keeping
        // track of the path
        let mut visited = self.graph.visit_map();
        let mut scores = HashMap::new();
        let mut prev: HashMap<Node, Vec<Node>> = HashMap::new();
        let mut visit_next = BinaryHeap::new();
        scores.insert(start, 0);
        visit_next.push(MinScored(0, start));

        while let Some(MinScored(node_score, node)) = visit_next.pop() {
            if visited.is_visited(&node) {
                continue;
            }
            if end == node {
                break;
            }
            for (_, next, edge_cost) in self.graph.edges(node) {
                if visited.is_visited(&next) {
                    continue;
                }

                let next_score = node_score + edge_cost;
                match scores.entry(next) {
                    std::collections::hash_map::Entry::Occupied(ent) => {
                        if next_score <= *ent.get() {
                            *ent.into_mut() = next_score;
                            visit_next.push(MinScored(next_score, next));
                            prev.entry(next).or_insert(Vec::new()).push(node);
                        }
                    }
                    std::collections::hash_map::Entry::Vacant(ent) => {
                        ent.insert(next_score);
                        visit_next.push(MinScored(next_score, next));
                        prev.insert(next, vec![node]);
                    }
                }
            }
            visited.visit(node);
        }

        let mut paths = Vec::new();
        self.reverse_dijkstra_paths(&end, &vec![], &prev, &mut paths);
        (scores[&end], paths)
    }

    fn reverse_dijkstra_paths(
        &self,
        cur_node: &Node,
        cur_path: &Vec<Node>,
        prev: &HashMap<Node, Vec<Node>>,
        paths: &mut Vec<Vec<Node>>,
    ) {
        let mut next_path = cur_path.clone();
        next_path.push(*cur_node);

        let opts = prev.get(cur_node);
        if opts.is_none() || opts.unwrap().len() == 0 {
            paths.push(next_path.into_iter().rev().collect());
            return;
        }

        opts.unwrap().iter().for_each(|opt| {
            self.reverse_dijkstra_paths(opt, &next_path, prev, paths);
        });
    }

    fn num_tiles_on_best_paths(&self) -> u64 {
        let shortest_paths_per_end_dir: Vec<_> = self
            .ending_nodes
            .iter()
            .map(|end_node| self.dijkstra(self.starting_node, *end_node))
            .collect();
        let min_cost = shortest_paths_per_end_dir
            .iter()
            .min_by(|a, b| a.0.cmp(&b.0))
            .expect("must have a min cost")
            .0;

        let paths: Vec<_> = shortest_paths_per_end_dir
            .iter()
            .filter_map(|(cost, p)| if *cost == min_cost { Some(p) } else { None })
            .flatten()
            .collect();

        let mut tiles: HashSet<Point> = HashSet::new();

        paths.iter().for_each(|path| {
            path.iter().enumerate().for_each(|(i, node)| {
                if i == path.len() - 1 {
                    return;
                }

                tiles.insert(node.pos);
                tiles.extend(node.pos.points_between_other(&path[i + 1].pos));
                tiles.insert(path[i + 1].pos);
            });
        });

        tiles.len() as u64
    }
}

#[derive(Debug, PartialEq, Eq, Hash, Clone, Copy, PartialOrd, Ord)]
struct Node {
    pos: Point,
    reindeer_dir: Direction,
}

fn find_corners_in_raw_map(raw_map: &Vec<Vec<char>>) -> Vec<Point> {
    raw_map
        .iter()
        .enumerate()
        .fold(Vec::new(), |mut corners, (i, row)| {
            row.iter().enumerate().for_each(|(j, c)| {
                if *c == '#' {
                    return;
                }

                let point = Point { x: j, y: i };

                if point_is_dead_end(raw_map, &point) || point_is_intersection(raw_map, &point) {
                    corners.push(point);
                }
            });
            corners
        })
}

fn point_is_intersection(raw_map: &Vec<Vec<char>>, point: &Point) -> bool {
    [
        [Direction::Up, Direction::Right],
        [Direction::Up, Direction::Left],
        [Direction::Down, Direction::Right],
        [Direction::Down, Direction::Left],
    ]
    .iter()
    .any(|corner_dirs| {
        corner_dirs.iter().all(|dir| {
            let (x, y) = point.add_direction(dir);
            raw_map[y as usize][x as usize] != '#'
        })
    })
}

fn point_is_dead_end(raw_map: &Vec<Vec<char>>, point: &Point) -> bool {
    Direction::iter()
        .filter(|dir| {
            let (x, y) = point.add_direction(dir);
            raw_map[y as usize][x as usize] == '#'
        })
        .collect::<Vec<_>>()
        .len()
        == 3
}

fn find_edges(raw_map: &Vec<Vec<char>>, corners: &Vec<Point>) -> HashSet<(Point, Point)> {
    corners.iter().fold(HashSet::new(), |mut edges, corner| {
        let connected_corners = find_corners_connecting_to_corner(raw_map, corners, corner);
        connected_corners.iter().for_each(|connected_corner| {
            edges.insert((*corner, *connected_corner));
        });
        edges
    })
}

fn find_corners_connecting_to_corner(
    raw_map: &Vec<Vec<char>>,
    corners: &Vec<Point>,
    start_corner: &Point,
) -> Vec<Point> {
    Direction::iter()
        .filter_map(|dir| {
            let mut cur_pos = start_corner.clone();

            loop {
                let (x, y) = cur_pos.add_direction(&dir);
                cur_pos = Point::new(x, y);

                if raw_map[cur_pos.y][cur_pos.x] == '#' {
                    return None;
                }

                if corners.contains(&cur_pos) {
                    return Some(cur_pos);
                }
            }
        })
        .collect()
}

#[derive(Copy, Clone, Debug, Eq)]
struct MinScored(u64, Node);

impl Ord for MinScored {
    fn cmp(&self, other: &Self) -> Ordering {
        let a = &self.0;
        let b = &other.0;

        if a == b {
            Ordering::Equal
        } else if a < b {
            Ordering::Greater
        } else {
            Ordering::Less
        }
    }
}

impl PartialEq for MinScored {
    fn eq(&self, other: &Self) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}

impl PartialOrd for MinScored {
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
        assert_eq!(part1(&map), 7036);

        let map2 = read_input("example1.txt").expect("failed to read input");
        assert_eq!(part1(&map2), 11048);
    }

    #[test]
    fn part2_works() {
        let map = read_input("example.txt").expect("failed to read input");
        assert_eq!(part2(&map), 45);

        let map2 = read_input("example1.txt").expect("failed to read input");
        assert_eq!(part2(&map2), 64);
    }
}
