use std::{
    collections::{HashMap, HashSet, VecDeque},
    fmt::Display,
    fs::read_to_string,
};

fn main() {
    let mut device = read_input("input.txt").expect("failed to read input");
    let orig_gate_values = device.gate_values.clone();

    println!("Part 1: {}", part1(&mut device));

    device.gate_values = orig_gate_values;
    println!("Part 2: {}", part2(&mut device));
}

fn part1(device: &mut Device) -> usize {
    device.run_all_instructions();
    device.get_num_from_z_gates()
}

fn part2(device: &mut Device) -> String {
    let swaps = device
        .fix_instrs_for_adders(&mut vec![])
        .expect("must find valid swaps");

    let mut outs: Vec<_> = swaps
        .iter()
        .flat_map(|swap| {
            [
                device.instructions[swap.0].c.clone(),
                device.instructions[swap.1].c.clone(),
            ]
        })
        .collect();
    outs.sort();

    outs.join(",")
}

fn read_input(path: &str) -> Result<Device, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(Device::from(input.as_str()))
}

struct Device {
    gate_values: HashMap<String, bool>,
    instructions: Vec<Instruction>,
}

impl Device {
    fn run_all_instructions(&mut self) -> Option<()> {
        let mut instrs_to_do = VecDeque::from_iter(self.instructions.iter());

        let mut iters_without_an_instr = 0;
        while let Some(instr) = instrs_to_do.pop_front() {
            if !self.can_do_instruction(&instr) {
                instrs_to_do.push_back(instr);
                iters_without_an_instr += 1;

                if iters_without_an_instr == instrs_to_do.len() {
                    return None;
                }

                continue;
            }

            iters_without_an_instr = 0;

            let (c, c_val) = instr.run(&self.gate_values);
            self.gate_values.insert(c, c_val);
        }

        Some(())
    }

    fn get_num_from_z_gates(&self) -> usize {
        let mut z_gates: Vec<_> = self
            .gate_values
            .iter()
            .filter(|(k, _)| k.starts_with("z"))
            .collect();

        get_num_from_list_of_gates(&mut z_gates)
    }

    fn can_do_instruction(&self, instr: &Instruction) -> bool {
        self.gate_values.contains_key(&instr.a) && self.gate_values.contains_key(&instr.b)
    }

    fn swap_instructions(&mut self, swap: &(usize, usize)) {
        let a = self.instructions[swap.0].c.clone();
        let b = self.instructions[swap.1].c.clone();
        self.instructions[swap.0].c = b;
        self.instructions[swap.1].c = a;
    }

    fn fix_instrs_for_adders(
        &mut self,
        swaps: &mut Vec<(usize, usize)>,
    ) -> Option<Vec<(usize, usize)>> {
        let mut wrong_gates = self.find_wrong_z_gates_for_adder();
        wrong_gates.sort_by(|a, b| a.cmp(b));

        if swaps.len() > 4 {
            return None;
        }

        if swaps.len() == 4 && wrong_gates.len() == 0 {
            return Some(swaps.to_vec());
        }

        let first_broken = wrong_gates[0].clone();
        let relevant_instrs = if let Ok(v) = self.find_instrs_used_for_z(&first_broken) {
            v
        } else {
            return None;
        };

        for (i, _) in relevant_instrs {
            for j in 0..self.instructions.len() {
                if i == j {
                    continue;
                }
                let swap = (i, j);

                self.swap_instructions(&swap);

                if self.z_gate_is_correct_for_adder(&first_broken) {
                    swaps.push(swap);
                    if let Some(ans) = self.fix_instrs_for_adders(swaps) {
                        return Some(ans);
                    } else {
                        swaps.pop();
                    }
                }

                self.swap_instructions(&swap);
            }
        }

        None
    }

    fn get_all_z_gates(&self) -> Vec<String> {
        self.instructions
            .iter()
            .filter_map(|instr| {
                if instr.c.starts_with("z") {
                    Some(instr.c.clone())
                } else {
                    None
                }
            })
            .collect()
    }

    fn find_wrong_z_gates_for_adder(&self) -> Vec<String> {
        let z_gates = self.get_all_z_gates();

        z_gates
            .iter()
            .filter_map(|z| {
                if !self.z_gate_is_correct_for_adder(z) {
                    Some(z.clone())
                } else {
                    None
                }
            })
            .collect()
    }

    fn z_gate_is_correct_for_adder(&self, z: &str) -> bool {
        self.dfs_for_tree_of_instrs(&z, &mut HashSet::new())
            .map_or(false, |tree| tree.is_full_adder(&z))
    }

    fn find_instrs_used_for_z(&self, z: &str) -> Result<Vec<(usize, Instruction)>, ()> {
        let mut queue = vec![z.to_string()];
        let mut instrs = vec![];
        let mut visited = HashSet::new();

        while let Some(v) = queue.pop() {
            visited.insert(v.to_string());

            if let Some((i, instr)) = self
                .instructions
                .iter()
                .enumerate()
                .find(|(_, instr)| instr.c == v)
            {
                instrs.push((i, instr.clone()));
                if !visited.contains(&instr.a) {
                    queue.push(instr.a.to_string());
                }
                if !visited.contains(&instr.b) {
                    queue.push(instr.b.to_string());
                }
            }
        }

        Ok(instrs)
    }

    fn dfs_for_tree_of_instrs(
        &self,
        gate: &str,
        visited: &mut HashSet<String>,
    ) -> Option<Box<Node>> {
        if visited.contains(gate) {
            return None;
        }
        if let Some((_, instr)) = self.find_instr_for_output(&gate) {
            visited.insert(gate.to_string());
            Some(Box::new(Node {
                val: instr.clone(),
                left: self.dfs_for_tree_of_instrs(&instr.a, visited),
                right: self.dfs_for_tree_of_instrs(&instr.b, visited),
            }))
        } else {
            None
        }
    }

    fn find_instr_for_output(&self, gate: &str) -> Option<(usize, Instruction)> {
        self.instructions
            .iter()
            .enumerate()
            .find(|(_, instr)| instr.c == gate)
            .map(|(i, instr)| (i, instr.clone()))
    }

    fn graphviz(&self) -> String {
        let mut s = "digraph {\n".to_string();

        self.instructions.iter().for_each(|instr| {
            s += format!("{} -> {}\n{} -> {}\n", instr.a, instr.c, instr.b, instr.c).as_str();
        });

        s + "}\n"
    }
}

impl From<&str> for Device {
    fn from(value: &str) -> Self {
        let (gates, instrs) = value.split_once("\n\n").unwrap();

        let gate_values = gates
            .lines()
            .map(|g| {
                let (k, v) = g.split_once(": ").expect("bad gate str");

                (k.to_string(), v == "1")
            })
            .collect();

        let instructions = instrs.lines().map(|line| Instruction::from(line)).collect();

        Self {
            gate_values,
            instructions,
        }
    }
}

#[derive(Clone, Debug)]
struct Instruction {
    a: String,
    gate: Gate,
    b: String,

    c: String,
}

impl Instruction {
    fn run(&self, gate_values: &HashMap<String, bool>) -> (String, bool) {
        let a_val = gate_values[&self.a];
        let b_val = gate_values[&self.b];
        let c_val = match self.gate {
            Gate::AND => a_val && b_val,
            Gate::OR => a_val || b_val,
            Gate::XOR => a_val ^ b_val,
        };
        (self.c.to_string(), c_val)
    }
}

impl Display for Instruction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}{}{}", self.a, self.gate, self.b)
    }
}

impl From<&str> for Instruction {
    fn from(value: &str) -> Self {
        let without_arrow = value.replace("->", "");
        let split: Vec<_> = without_arrow.split_whitespace().collect();

        Self {
            a: split[0].to_string(),
            gate: Gate::from(split[1]),
            b: split[2].to_string(),
            c: split[3].to_string(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Gate {
    AND,
    OR,
    XOR,
}

impl Display for Gate {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Gate::AND => "&",
                Gate::OR => "|",
                Gate::XOR => "^",
            }
        )
    }
}

impl From<&str> for Gate {
    fn from(value: &str) -> Self {
        match value {
            "AND" => Self::AND,
            "OR" => Self::OR,
            "XOR" => Self::XOR,
            _ => panic!("unknown gate"),
        }
    }
}

#[derive(Debug)]
struct Node {
    val: Instruction,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

impl Node {
    // returns true if a valid full adder for the out bit
    fn is_full_adder(&self, out: &str) -> bool {
        if out == "z00" {
            return self.is_xor_for_main_bits("z00");
        } else if out == "z45" {
            return self.is_correct_carry_gates("z45");
        }

        if self.left.is_none() || self.right.is_none() {
            return false;
        }
        let left = self.left.as_ref().unwrap();
        let right = self.right.as_ref().unwrap();
        self.val.gate == Gate::XOR
            && ((left.is_xor_for_main_bits(out) && right.is_correct_carry_gates(out))
                || (right.is_xor_for_main_bits(out) && left.is_correct_carry_gates(out)))
    }

    // for z03, should have x03^y03
    fn is_xor_for_main_bits(&self, out: &str) -> bool {
        let needed_inputs = [out.replace("z", "x"), out.replace("z", "y")];
        let mut actual_inputs = [self.val.a.clone(), self.val.b.clone()];
        actual_inputs.sort();

        self.val.gate == Gate::XOR && actual_inputs == needed_inputs
    }

    fn is_correct_carry_gates(&self, out: &str) -> bool {
        if out == "z01" {
            return self.is_and_of_prev_bit(out);
        }

        if self.val.gate != Gate::OR {
            return false;
        }

        if self.left.is_none() || self.right.is_none() {
            return false;
        }

        let left = self.left.as_ref().unwrap();
        let right = self.right.as_ref().unwrap();

        (left.is_and_of_prev_bit(out) && right.is_carry_input(out))
            || (right.is_and_of_prev_bit(out) && left.is_carry_input(out))
    }

    fn is_carry_input(&self, out: &str) -> bool {
        if self.left.is_none() || self.right.is_none() {
            return false;
        }

        if self.val.gate != Gate::AND {
            return false;
        }

        let left = self.left.as_ref().unwrap();
        let right = self.right.as_ref().unwrap();

        let n = out[1..].parse::<usize>().unwrap();
        let next_bit = format!("z{:02}", n - 1);

        (left.is_xor_for_main_bits(&next_bit) && right.is_correct_carry_gates(&next_bit))
            || (right.is_xor_for_main_bits(&next_bit) && left.is_correct_carry_gates(&next_bit))
    }

    fn is_and_of_prev_bit(&self, out: &str) -> bool {
        let n = out[1..].parse::<usize>();
        if n.is_err() {
            return false;
        }

        let prev_bit = n.unwrap() - 1;
        let needed_bits = [format!("x{:02}", prev_bit), format!("y{:02}", prev_bit)];

        let mut actual_inputs = [self.val.a.clone(), self.val.b.clone()];
        actual_inputs.sort();

        self.val.gate == Gate::AND && actual_inputs == needed_bits
    }
}

impl Display for Node {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.left.is_some() && self.right.is_some() {
            write!(
                f,
                "({}){}({})",
                self.left.as_ref().unwrap(),
                self.val.gate,
                self.right.as_ref().unwrap()
            )
        } else {
            write!(f, "{}", self.val)
        }
    }
}

fn get_num_from_list_of_gates(gates: &mut Vec<(&String, &bool)>) -> usize {
    gates.sort_by(|a, b| a.0.cmp(&b.0));

    let mut result = 0;

    gates.iter().enumerate().for_each(|(i, (_, v))| {
        if **v {
            result |= 1 << i;
        }
    });

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let mut device = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&mut device), 2024);
    }
}
