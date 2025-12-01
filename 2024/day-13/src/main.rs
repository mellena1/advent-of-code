use std::fs::read_to_string;

use itertools::Itertools;

fn main() {
    let claw_machines = read_input("input.txt").expect("failed to read input");
    println!("{:?}", claw_machines[86]);
    println!("Part 1: {}", part1(&claw_machines));
    println!("Part 2: {}", part2(&claw_machines));
}

fn part1(machines: &Vec<ClawMachine>) -> u64 {
    machines
        .iter()
        .filter_map(|machine| machine.least_tokens_for_prize(100))
        .sum()
}

fn part2(machines: &Vec<ClawMachine>) -> u64 {
    machines
        .iter()
        .map(|machine| {
            let new_loc = Location {
                x: machine.prize.x + 10000000000000,
                y: machine.prize.y + 10000000000000,
            };

            ClawMachine {
                buttons: machine.buttons.clone(),
                prize: new_loc,
            }
        })
        .filter_map(|machine| machine.least_tokens_for_prize(std::u64::MAX))
        .sum()
}

fn read_input(path: &str) -> Result<Vec<ClawMachine>, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(input
        .lines()
        .filter(|line| !line.is_empty())
        .chunks(3)
        .into_iter()
        .map(|mut chunk| ClawMachine::from(chunk.join("\n").as_str()))
        .collect())
}

#[derive(Debug, PartialEq, Eq)]
struct ClawMachine {
    buttons: [Button; 2],
    prize: Location,
}

impl ClawMachine {
    fn least_tokens_for_prize(&self, max_btn_presses: u64) -> Option<u64> {
        self.find_btn_combos_get_prize(max_btn_presses)
            .map(|combo| self.combo_token_amt(&combo))
    }

    fn find_btn_combos_get_prize(&self, max_btn_presses: u64) -> Option<(u64, u64)> {
        let cx = self.prize.x as i64;
        let cy = self.prize.y as i64;
        let ax = self.buttons[0].x_translation as i64;
        let ay = self.buttons[0].y_translation as i64;
        let bx = self.buttons[1].x_translation as i64;
        let by = self.buttons[1].y_translation as i64;

        let denom = (bx * ay) - (by * ax);

        if denom == 0 {
            return None;
        }

        if ((cy * bx) - (by * cx)) % denom != 0 {
            return None;
        }
        let a = ((cy * bx) - (by * cx)) / denom;

        if (cx - (ax * a)) % bx != 0 {
            return None;
        }
        let b = (cx - (ax * a)) / bx;

        if a < 0 || b < 0 || a as u64 > max_btn_presses || b as u64 > max_btn_presses {
            return None;
        }

        Some((a as u64, b as u64))
    }

    fn combo_token_amt(&self, combo: &(u64, u64)) -> u64 {
        combo.0 * self.buttons[0].cost + combo.1 * self.buttons[1].cost
    }
}

impl From<&str> for ClawMachine {
    fn from(value: &str) -> Self {
        let lines: Vec<_> = value.lines().collect();

        let a_button = Button::from(lines[0]);
        let b_button = Button::from(lines[1]);
        let prize_loc = Location::from(lines[2]);

        Self {
            buttons: [a_button, b_button],
            prize: prize_loc,
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone)]
struct Button {
    x_translation: u64,
    y_translation: u64,
    cost: u64,
}

impl From<&str> for Button {
    fn from(value: &str) -> Self {
        let cost = if value.starts_with("Button A") { 3 } else { 1 };

        let (_, translations) = value.split_once(":").expect("must have :");
        let (x_str, y_str) = translations.split_once(",").expect("must have ,");
        let x = parse_num_after_sign(x_str, "+");
        let y = parse_num_after_sign(y_str, "+");

        Self {
            x_translation: x,
            y_translation: y,
            cost,
        }
    }
}

fn parse_num_after_sign(value: &str, sign: &str) -> u64 {
    let (_, num_str) = value.trim().split_once(sign).expect("missing delimiter");
    num_str.parse().expect("must be a num")
}

#[derive(Debug, PartialEq, Eq)]
struct Location {
    x: u64,
    y: u64,
}

impl From<&str> for Location {
    fn from(value: &str) -> Self {
        let (x_str, y_str) = value.split_once(",").expect("must have ,");
        let x = parse_num_after_sign(x_str, "=");
        let y = parse_num_after_sign(y_str, "=");

        Self { x, y }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let machines = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&machines), 480);
    }

    #[test]
    fn least_tokens_for_prize_works() {
        let machine = ClawMachine {
            buttons: [
                Button {
                    x_translation: 94,
                    y_translation: 34,
                    cost: 3,
                },
                Button {
                    x_translation: 22,
                    y_translation: 67,
                    cost: 1,
                },
            ],
            prize: Location { x: 8400, y: 5400 },
        };

        assert_eq!(machine.least_tokens_for_prize(100), Some(280));
    }

    #[test]
    fn can_read_input() {
        let machines = read_input("example.txt").expect("failed to read input");
        assert_eq!(
            machines[0],
            ClawMachine {
                buttons: [
                    Button {
                        x_translation: 94,
                        y_translation: 34,
                        cost: 3
                    },
                    Button {
                        x_translation: 22,
                        y_translation: 67,
                        cost: 1
                    },
                ],
                prize: Location { x: 8400, y: 5400 },
            }
        );

        assert_eq!(
            machines[3],
            ClawMachine {
                buttons: [
                    Button {
                        x_translation: 69,
                        y_translation: 23,
                        cost: 3
                    },
                    Button {
                        x_translation: 27,
                        y_translation: 71,
                        cost: 1
                    },
                ],
                prize: Location { x: 18641, y: 10279 },
            }
        );
    }

    #[test]
    fn claw_machine_parse_works() {
        let machine = ClawMachine::from(
            "\
            Button A: X+94, Y+34\n\
            Button B: X+22, Y+67\n\
            Prize: X=8400, Y=5400",
        );

        assert_eq!(
            machine,
            ClawMachine {
                buttons: [
                    Button {
                        x_translation: 94,
                        y_translation: 34,
                        cost: 3
                    },
                    Button {
                        x_translation: 22,
                        y_translation: 67,
                        cost: 1
                    },
                ],
                prize: Location { x: 8400, y: 5400 },
            }
        )
    }
}
