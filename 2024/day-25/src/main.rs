use std::fs::read_to_string;

fn main() {
    let schematics = read_input("input.txt").expect("failed to read input");

    println!("Part 1: {}", part1(&schematics));
}

fn part1(schematics: &[Schematic]) -> usize {
    let lock_cols: Vec<_> = schematics
        .iter()
        .filter_map(|sch| {
            if let Schematic::Lock(cols) = sch {
                Some(cols)
            } else {
                None
            }
        })
        .collect();
    let key_cols: Vec<_> = schematics
        .iter()
        .filter_map(|sch| {
            if let Schematic::Key(cols) = sch {
                Some(cols)
            } else {
                None
            }
        })
        .collect();

    let mut valid_combos = 0;

    lock_cols.iter().for_each(|lock| {
        key_cols.iter().for_each(|key| {
            if key_and_lock_fit(key, lock) {
                valid_combos += 1;
            }
        });
    });

    valid_combos
}

fn read_input(path: &str) -> Result<Vec<Schematic>, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(input
        .split("\n\n")
        .map(|inp| Schematic::from(inp))
        .collect())
}

enum Schematic {
    Key(Vec<usize>),
    Lock(Vec<usize>),
}

impl From<&str> for Schematic {
    fn from(value: &str) -> Self {
        let lines: Vec<_> = value.lines().collect();
        let mut cols = vec![0; lines[0].len()];
        if lines[0].chars().all(|c| c == '#') {
            // Lock
            lines[1..].iter().for_each(|line| {
                line.char_indices().for_each(|(i, c)| {
                    if c == '#' {
                        cols[i] += 1;
                    }
                });
            });
            Schematic::Lock(cols)
        } else {
            // Key
            lines[0..lines.len() - 1].iter().rev().for_each(|line| {
                line.char_indices().for_each(|(i, c)| {
                    if c == '#' {
                        cols[i] += 1;
                    }
                });
            });
            Schematic::Key(cols)
        }
    }
}

fn key_and_lock_fit(key: &[usize], lock: &[usize]) -> bool {
    key.iter()
        .enumerate()
        .all(|(i, key_col_height)| (key_col_height + lock[i]) <= 5)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let input = read_input("example.txt").expect("failed to get input");
        assert_eq!(part1(&input), 3);
    }

    #[test]
    fn can_read_input() {
        let input = read_input("example.txt").expect("failed to get input");

        assert!(matches!(input[0], Schematic::Lock(_)));
        let Schematic::Lock(cols) = &input[0] else {
            panic!();
        };
        assert_eq!(cols, &vec![0, 5, 3, 4, 3]);

        assert!(matches!(input[2], Schematic::Key(_)));
        let Schematic::Key(cols) = &input[2] else {
            panic!();
        };
        assert_eq!(cols, &vec![5, 0, 2, 1, 3]);
    }
}
