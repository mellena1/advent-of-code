use std::{collections::HashMap, fmt::Display, fs::read_to_string};

use grid::Point;

fn main() {
    let codes = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&codes));
    println!("Part 2: {}", part2(&codes));
}

fn part1(codes: &[KeypadCode]) -> usize {
    codes.iter().fold(0, |acc, code| {
        let btn_seq = code.button_sequence_for_human(2);
        let code_num = code.code_to_num();
        acc + (btn_seq * code_num)
    })
}

fn part2(codes: &[KeypadCode]) -> usize {
    codes.iter().fold(0, |acc, code| {
        let btn_seq = code.button_sequence_for_human(25);
        let code_num = code.code_to_num();
        acc + (btn_seq * code_num)
    })
}

fn read_input(path: &str) -> Result<Vec<KeypadCode>, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(input
        .lines()
        .map(|line| KeypadCode {
            code: line.to_string(),
        })
        .collect())
}

struct KeypadCode {
    code: String,
}

impl KeypadCode {
    const DIR_PAD_EMPTY_SPACE: Point = Point { x: 0, y: 0 };
    const DIR_PAD_A_POS: Point = Point { x: 2, y: 0 };

    const NUM_PAD_EMPTY_SPACE: Point = Point { x: 0, y: 3 };
    const NUM_PAD_A_POS: Point = Point { x: 2, y: 3 };

    fn button_sequence_for_human(&self, num_robots: usize) -> usize {
        let first_options = self.buttons_for_numpad();

        let best =
            self.find_min_length_of_buttons(&first_options, 1, num_robots, &mut HashMap::new());

        best
    }

    fn buttons_for_numpad(&self) -> Vec<DirectionalButton> {
        let mut cur_pos = Self::NUM_PAD_A_POS;

        self.code
            .chars()
            .flat_map(|c| {
                let next_pos = self.pos_of_numpad_button(c);

                let buttons =
                    self.path_to_next_button(&cur_pos, &next_pos, &Self::NUM_PAD_EMPTY_SPACE);
                cur_pos = next_pos;
                buttons
            })
            .collect()
    }

    fn find_min_length_of_buttons(
        &self,
        inputs: &[DirectionalButton],
        level: usize,
        max_level: usize,
        cache: &mut HashMap<(Vec<DirectionalButton>, usize), usize>,
    ) -> usize {
        if let Some(cached_num) = cache.get(&(inputs.to_vec(), level)) {
            return *cached_num;
        }

        if level == max_level {
            let btns = self.buttons_for_directional_pad(inputs);
            return btns.len();
        }

        let mut cur_pos = Self::DIR_PAD_A_POS;
        inputs.iter().fold(0, |acc, i| {
            let next_pos = self.pos_of_direction_button(*i);

            let btns_for_i =
                self.path_to_next_button(&cur_pos, &next_pos, &Self::DIR_PAD_EMPTY_SPACE);

            let num_btns =
                self.find_min_length_of_buttons(&btns_for_i, level + 1, max_level, cache);
            cache.insert((btns_for_i, level + 1), num_btns);
            cur_pos = next_pos;
            acc + num_btns
        })
    }

    fn buttons_for_directional_pad(&self, inputs: &[DirectionalButton]) -> Vec<DirectionalButton> {
        let mut cur_pos = Self::DIR_PAD_A_POS;

        inputs
            .iter()
            .flat_map(|btn| {
                let next_pos = self.pos_of_direction_button(*btn);

                let buttons =
                    self.path_to_next_button(&cur_pos, &next_pos, &Self::DIR_PAD_EMPTY_SPACE);
                cur_pos = next_pos;
                buttons
            })
            .collect()
    }

    fn path_to_next_button(
        &self,
        cur_pos: &Point,
        next_pos: &Point,
        empty_space_pos: &Point,
    ) -> Vec<DirectionalButton> {
        let x_translation = next_pos.x as i64 - cur_pos.x as i64;
        let y_translation = next_pos.y as i64 - cur_pos.y as i64;

        let horiz = self.make_horiz_movements(x_translation);
        let vert = self.make_vert_movements(y_translation);
        let dirs: Vec<DirectionalButton> = if cur_pos.x as i64 + x_translation
            == empty_space_pos.x as i64
            && cur_pos.y == empty_space_pos.y
        {
            // can only do the y translation first because of hitting empty_space
            [vert, horiz, vec![DirectionalButton::A]].concat()
        } else if cur_pos.y as i64 + y_translation as i64 == empty_space_pos.y as i64
            && cur_pos.x == empty_space_pos.x
        {
            // can only do the x translation first because of hitting empty_space
            [horiz, vert, vec![DirectionalButton::A]].concat()
        } else {
            // some magic from
            // https://github.com/maksverver/AdventOfCode/blob/9ec8c02e5b0fca04efa43bca63e28cf62bf95dcb/2024/21-alt.py#L74
            // I was too tired to think this through and gave up looking for hints o7
            if x_translation < 0 && y_translation < 0 {
                // prefer <^ over ^<
                [horiz, vert, vec![DirectionalButton::A]].concat()
            } else if x_translation < 0 && y_translation > 0 {
                // prefer <v over v<
                [horiz, vert, vec![DirectionalButton::A]].concat()
            } else if x_translation > 0 && y_translation < 0 {
                // prefer ^> over >^
                [vert, horiz, vec![DirectionalButton::A]].concat()
            } else {
                // prefer v> over >v
                [vert, horiz, vec![DirectionalButton::A]].concat()
            }
        };

        dirs
    }

    fn make_horiz_movements(&self, x_translation: i64) -> Vec<DirectionalButton> {
        (0..x_translation.abs())
            .map(|_| {
                if x_translation < 0 {
                    DirectionalButton::Left
                } else {
                    DirectionalButton::Right
                }
            })
            .collect()
    }

    fn make_vert_movements(&self, y_translation: i64) -> Vec<DirectionalButton> {
        (0..y_translation.abs())
            .map(|_| {
                if y_translation < 0 {
                    DirectionalButton::Up
                } else {
                    DirectionalButton::Down
                }
            })
            .collect()
    }

    fn pos_of_numpad_button(&self, c: char) -> Point {
        match c {
            '7' => Point { x: 0, y: 0 },
            '8' => Point { x: 1, y: 0 },
            '9' => Point { x: 2, y: 0 },
            '4' => Point { x: 0, y: 1 },
            '5' => Point { x: 1, y: 1 },
            '6' => Point { x: 2, y: 1 },
            '1' => Point { x: 0, y: 2 },
            '2' => Point { x: 1, y: 2 },
            '3' => Point { x: 2, y: 2 },
            '0' => Point { x: 1, y: 3 },
            'A' => Point { x: 2, y: 3 },
            _ => panic!("unknown char: {}", c),
        }
    }

    fn pos_of_direction_button(&self, dir: DirectionalButton) -> Point {
        match dir {
            DirectionalButton::Up => Point { x: 1, y: 0 },
            DirectionalButton::Down => Point { x: 1, y: 1 },
            DirectionalButton::Left => Point { x: 0, y: 1 },
            DirectionalButton::Right => Point { x: 2, y: 1 },
            DirectionalButton::A => Point { x: 2, y: 0 },
        }
    }

    fn code_to_num(&self) -> usize {
        self.code
            .chars()
            .filter(|c| c.is_ascii_digit())
            .collect::<String>()
            .parse()
            .expect("NaN")
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
enum DirectionalButton {
    Up,
    Down,
    Left,
    Right,
    A,
}

impl Display for DirectionalButton {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                DirectionalButton::Up => '^',
                DirectionalButton::Down => 'v',
                DirectionalButton::Left => '<',
                DirectionalButton::Right => '>',
                DirectionalButton::A => 'A',
            }
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let codes = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&codes), 126384);
    }
}
