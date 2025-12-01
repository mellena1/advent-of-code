use std::{fmt::Display, fs::read_to_string};

fn main() {
    let mut computer = read_input("input.txt").expect("invalid input");
    println!("Part 1: {}", part1(&mut computer));
    println!("Part 2: {}", part2(&mut computer));
}

fn part1(computer: &mut Computer) -> String {
    computer.run_program()
}

fn part2(computer: &mut Computer) -> u64 {
    find_num_that_gets_outputs(
        computer,
        &computer.program.iter().map(|n| *n as u64).collect(),
        computer.program.len() - 1,
        0,
    )
    .unwrap()
}

fn read_input(path: &str) -> Result<Computer, std::io::Error> {
    let input = read_to_string(path)?;
    Ok(Computer::from(input.as_str()))
}

fn find_num_that_gets_outputs(
    computer: &mut Computer,
    needed_output: &Vec<u64>,
    needed_output_idx: usize,
    cur_num: u64,
) -> Option<u64> {
    for i in 0..8 {
        if cur_num == 0 && i == 0 {
            continue;
        }
        computer.reset();
        let reg_a_to_try = (cur_num << 3) | i;
        computer.reg_A = reg_a_to_try;

        let out = computer.run_until_output();
        if needed_output[needed_output_idx] == out {
            if needed_output_idx == 0 {
                return Some(reg_a_to_try);
            }

            if let Some(answer) = find_num_that_gets_outputs(
                computer,
                needed_output,
                needed_output_idx - 1,
                reg_a_to_try,
            ) {
                return Some(answer);
            }
        }
    }

    None
}

#[allow(non_snake_case)]
struct Computer {
    reg_A: u64,
    reg_B: u64,
    reg_C: u64,

    orig_reg_vals: [u64; 3],

    instruction_ptr: usize,

    program: Vec<u8>,

    outputs: Vec<u64>,
}

impl Computer {
    fn run_program(&mut self) -> String {
        loop {
            let result = self.tick();
            if result == ComputerTickResult::Halt {
                break;
            }
        }

        vec_to_str(&self.outputs)
    }

    fn run_until_output(&mut self) -> u64 {
        loop {
            let result = self.tick();
            if result == ComputerTickResult::AddedOutput {
                return self.outputs[0];
            }
        }
    }

    fn tick(&mut self) -> ComputerTickResult {
        if self.instruction_ptr > self.program.len() - 2 {
            return ComputerTickResult::Halt;
        }

        let (opcode, operand) = self.get_opcode_and_operand();

        match opcode {
            Instruction::adv => {
                let result = self.division_on_reg_a(operand);

                self.reg_A = result;
                self.instruction_ptr += 2;
            }
            Instruction::bxl => {
                let result = self.reg_B ^ (operand as u64);

                self.reg_B = result;
                self.instruction_ptr += 2;
            }
            Instruction::bst => {
                let result = self.combo_operand(operand) & 0b111; // same as % 8

                self.reg_B = result;
                self.instruction_ptr += 2;
            }
            Instruction::jnz => {
                if self.reg_A == 0 {
                    self.instruction_ptr += 2;
                } else {
                    self.instruction_ptr = operand as usize;
                }
            }
            Instruction::bxc => {
                let result = self.reg_B ^ self.reg_C;

                self.reg_B = result;
                self.instruction_ptr += 2;
            }
            Instruction::out => {
                let combo_op = self.combo_operand(operand);
                let result = combo_op & 0b111; // same as % 8

                self.outputs.push(result);

                self.instruction_ptr += 2;

                return ComputerTickResult::AddedOutput;
            }
            Instruction::bdv => {
                let result = self.division_on_reg_a(operand);

                self.reg_B = result;
                self.instruction_ptr += 2;
            }
            Instruction::cdv => {
                let result = self.division_on_reg_a(operand);

                self.reg_C = result;
                self.instruction_ptr += 2;
            }
        }

        ComputerTickResult::Ok
    }

    fn get_opcode_and_operand(&self) -> (Instruction, u8) {
        (
            Instruction::from(self.program[self.instruction_ptr]),
            self.program[self.instruction_ptr + 1],
        )
    }

    fn combo_operand(&self, operand: u8) -> u64 {
        match operand {
            0..=3 => operand as u64,
            4 => self.reg_A,
            5 => self.reg_B,
            6 => self.reg_C,
            7 => panic!("reserved operand 7, not valid"),
            _ => panic!("unknown operand"),
        }
    }

    fn division_on_reg_a(&mut self, operand: u8) -> u64 {
        let combo_op = self.combo_operand(operand);

        self.reg_A >> combo_op // same as (A / 2^n)
    }

    fn reset(&mut self) {
        self.reg_A = self.orig_reg_vals[0];
        self.reg_B = self.orig_reg_vals[1];
        self.reg_C = self.orig_reg_vals[2];
        self.outputs = Vec::new();
        self.instruction_ptr = 0;
    }
}

impl Display for Computer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Reg A: {}\nReg B: {}\nReg C: {}\nOutputs: {}",
            self.reg_A,
            self.reg_B,
            self.reg_C,
            vec_to_str(&self.outputs)
        )
    }
}

#[derive(PartialEq)]
enum ComputerTickResult {
    Ok,
    Halt,
    AddedOutput,
}

impl From<&str> for Computer {
    fn from(value: &str) -> Self {
        let lines: Vec<_> = value.lines().collect();

        let regs = [
            num_from_register_line(lines[0]),
            num_from_register_line(lines[1]),
            num_from_register_line(lines[2]),
        ];

        Self {
            reg_A: regs[0],
            reg_B: regs[1],
            reg_C: regs[2],

            orig_reg_vals: regs,

            instruction_ptr: 0,

            program: program_from_program_line(lines[4]),

            outputs: Vec::new(),
        }
    }
}

#[allow(non_camel_case_types)]
#[derive(Debug)]
enum Instruction {
    adv,
    bxl,
    bst,
    jnz,
    bxc,
    out,
    bdv,
    cdv,
}

impl From<u8> for Instruction {
    fn from(value: u8) -> Self {
        match value {
            0 => Self::adv,
            1 => Self::bxl,
            2 => Self::bst,
            3 => Self::jnz,
            4 => Self::bxc,
            5 => Self::out,
            6 => Self::bdv,
            7 => Self::cdv,
            _ => panic!("unknown instruction"),
        }
    }
}

fn num_from_register_line(line: &str) -> u64 {
    let (_, num_str) = line.split_once(":").expect("invalid register line");
    num_str.trim().parse().expect("must be a num")
}

fn program_from_program_line(line: &str) -> Vec<u8> {
    let (_, prog_str) = line.split_once(":").expect("invalid prog line");

    prog_str
        .trim()
        .split(",")
        .map(|s| s.parse().expect("must be a num"))
        .collect()
}

fn vec_to_str<T: ToString>(v: &Vec<T>) -> String {
    v.iter()
        .map(|i| i.to_string())
        .collect::<Vec<_>>()
        .join(",")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let mut computer = read_input("example.txt").expect("invalid input");

        let result = part1(&mut computer);
        assert_eq!(result.as_str(), "4,6,3,5,6,3,5,2,1,0");
    }

    #[test]
    fn part2_works() {
        let mut computer = read_input("example2.txt").expect("invalid input");
        let result = part2(&mut computer);
        assert_eq!(result, 117440);
    }
}
