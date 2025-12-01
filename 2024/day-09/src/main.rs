use std::{collections::HashSet, fmt::Display, fs::read_to_string};

fn main() {
    let disk_map = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&disk_map));
    println!("Part 2: {}", part2(&disk_map));
}

fn part1(disk_map: &DiskMap) -> u64 {
    let squished = disk_map.squish();
    squished.checksum()
}

fn part2(disk_map: &DiskMap) -> u64 {
    let defragged = disk_map.defrag();
    defragged.checksum()
}

fn read_input(path: &str) -> Result<DiskMap, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(DiskMap::from(input.as_str()))
}

#[derive(Clone)]
struct DiskMap {
    content: Vec<DiskContent>,
}

impl DiskMap {
    // this fn is super wonky and could probably be improved to work similar to defrag, but meh I'm tired
    fn squish(&self) -> DiskMap {
        let mut new_content: Vec<DiskContent> = Vec::new();

        let mut full_pushed: HashSet<u64> = HashSet::new();
        let mut partial_pushed: HashSet<u64> = HashSet::new();

        let mut stack_of_files: Vec<DiskContent> = self
            .content
            .iter()
            .filter(|item| matches!(item, DiskContent::File { id: _, size: _ }))
            .map(|item| *item)
            .collect();

        self.content.iter().for_each(|item| {
            match item {
                DiskContent::File { id, size: _ } => {
                    if !partial_pushed.contains(id) {
                        new_content.push(*item);
                        full_pushed.insert(*id);
                    }
                }
                DiskContent::FreeSpace { size } => {
                    let mut free_space = *size;

                    while free_space > 0 {
                        if let Some(last_file) = stack_of_files.pop() {
                            if full_pushed.contains(&last_file.id()) {
                                continue;
                            }
                            partial_pushed.insert(last_file.id());
                            if last_file.size() > free_space {
                                new_content.push(DiskContent::File {
                                    id: last_file.id(),
                                    size: free_space,
                                });
                                stack_of_files.push(DiskContent::File {
                                    id: last_file.id(),
                                    size: last_file.size() - free_space,
                                });
                                free_space = 0;
                            } else {
                                new_content.push(last_file);
                                free_space -= last_file.size();
                            }
                        } else {
                            break;
                        }
                    }
                }
            };
        });

        DiskMap {
            content: new_content,
        }
    }

    fn defrag(&self) -> DiskMap {
        let mut defragged = self.clone();

        let mut i = (defragged.content.len() - 1) as i64;

        while i > 0 {
            let item = defragged.content[i as usize];
            match item {
                DiskContent::File { id: _, size } => {
                    if let Some((empty_idx, free_space)) =
                        defragged.find_first_empty_space_with_enough_room(size, i as usize)
                    {
                        defragged.content[empty_idx] = item;
                        defragged.content[i as usize] = DiskContent::FreeSpace { size: size };
                        if free_space.size() > size {
                            defragged.content.insert(
                                empty_idx + 1,
                                DiskContent::FreeSpace {
                                    size: free_space.size() - size,
                                },
                            );
                            i += 1;
                        }
                    }
                }
                DiskContent::FreeSpace { size: _ } => {}
            }

            i -= 1;
        }

        defragged
    }

    fn checksum(&self) -> u64 {
        let mut i = 0;
        self.content.iter().fold(0, |acc, content| {
            let result = acc + content.checksum(i);
            i += content.size() as usize;
            result
        })
    }

    fn find_first_empty_space_with_enough_room(
        &self,
        size: u64,
        before: usize,
    ) -> Option<(usize, DiskContent)> {
        self.content[..before]
            .iter()
            .enumerate()
            .find(|(_, item)| {
                matches!(item, DiskContent::FreeSpace { size: _ }) && item.size() >= size
            })
            .and_then(|(i, item)| Some((i, *item)))
    }
}

impl From<&str> for DiskMap {
    fn from(value: &str) -> Self {
        let content = value
            .trim()
            .chars()
            .enumerate()
            .map(|(i, c)| {
                let digit = c.to_digit(10).expect("char not a number") as u64;
                if i % 2 == 0 {
                    DiskContent::File {
                        id: (i / 2) as u64,
                        size: digit,
                    }
                } else {
                    DiskContent::FreeSpace { size: digit }
                }
            })
            .collect();

        Self { content }
    }
}

impl Display for DiskMap {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s: String = self.content.iter().map(|item| item.to_string()).collect();
        f.write_str(&s)
    }
}

#[derive(PartialEq, Eq, Debug, Clone, Copy)]
enum DiskContent {
    File { id: u64, size: u64 },
    FreeSpace { size: u64 },
}

impl DiskContent {
    fn checksum(&self, start_pos: usize) -> u64 {
        match self {
            DiskContent::File { id, size } => (start_pos..start_pos + *size as usize)
                .map(|i| id * i as u64)
                .sum(),
            _ => 0,
        }
    }

    fn size(&self) -> u64 {
        match self {
            DiskContent::File { id: _, size } => *size,
            DiskContent::FreeSpace { size } => *size,
        }
    }

    fn id(&self) -> u64 {
        match self {
            DiskContent::File { id, size: _ } => *id,
            DiskContent::FreeSpace { size: _ } => panic!("can't call id() on free space"),
        }
    }
}

impl Display for DiskContent {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s: String = match self {
            DiskContent::File { id, size } => (0..*size).map(|_| id.to_string()).collect(),
            DiskContent::FreeSpace { size } => (0..*size).map(|_| ".").collect(),
        };

        f.write_str(&s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let input = read_input("example.txt").expect("failed to read input");
        let result = part1(&input);
        assert_eq!(result, 1928);
    }

    #[test]
    fn part2_works() {
        let input = read_input("example.txt").expect("failed to read input");
        let result = part2(&input);
        assert_eq!(result, 2858);
    }

    #[test]
    fn diskmap_from_str_works() {
        let result = DiskMap::from("12345");
        assert_eq!(
            result.content.as_slice(),
            &[
                DiskContent::File { id: 0, size: 1 },
                DiskContent::FreeSpace { size: 2 },
                DiskContent::File { id: 1, size: 3 },
                DiskContent::FreeSpace { size: 4 },
                DiskContent::File { id: 2, size: 5 },
            ]
        );
    }

    #[test]
    fn diskmap_to_str_works() {
        let result = DiskMap::from("2333133121414131402");
        assert_eq!(
            result.to_string(),
            "00...111...2...333.44.5555.6666.777.888899"
        );
    }
}
