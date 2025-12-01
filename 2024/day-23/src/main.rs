use std::{collections::HashMap, fs::read_to_string};

fn main() {
    let network = read_input("input.txt").expect("failed to read input");
    println!("Part 1: {}", part1(&network));
    println!("Part 2: {}", part2(&network));
}

fn part1(network: &NetworkMap) -> usize {
    network
        .get_set_of_three_conns()
        .iter()
        .filter(|conns| conns.iter().any(|comp| comp.starts_with("t")))
        .count()
}

fn part2(network: &NetworkMap) -> String {
    let mut longest_conn = network.get_largest_fully_connected_comps();
    longest_conn.sort();
    longest_conn.join(",")
}

fn read_input(path: &str) -> Result<NetworkMap, std::io::Error> {
    let input = read_to_string(&path)?;
    Ok(NetworkMap::from(input.as_str()))
}

struct NetworkMap {
    connections: Vec<(String, String)>,
}

impl NetworkMap {
    fn get_set_of_three_conns(&self) -> Vec<[String; 3]> {
        let conn_map = self.get_connection_map();

        let comps: Vec<_> = conn_map.keys().collect();

        let mut set = Vec::new();

        for (i, comp) in comps.iter().enumerate() {
            let conns_with_this_comp = conn_map.get(*comp).unwrap();

            if i == comps.len() - 2 {
                break;
            }

            for (j, comp2) in conns_with_this_comp.iter().enumerate() {
                if j == conns_with_this_comp.len() - 1 {
                    break;
                }

                // already looked at this earlier
                if comps.iter().position(|c| *c == comp2).unwrap() < i {
                    continue;
                }

                for comp3 in &conns_with_this_comp[j + 1..] {
                    // already looked at this earlier
                    if comps.iter().position(|c| *c == comp3).unwrap() < i {
                        continue;
                    }

                    if let Some(conns_with_comp2) = conn_map.get(comp2) {
                        if conns_with_comp2.contains(comp3) {
                            set.push([comp.to_string(), comp2.to_string(), comp3.to_string()]);
                        }
                    }
                }
            }
        }

        set
    }

    fn get_largest_fully_connected_comps(&self) -> Vec<String> {
        let conn_map = self.get_connection_map();

        let comps: Vec<String> = conn_map.keys().map(|k| k.clone()).collect();

        comps
            .iter()
            .enumerate()
            .map(|(i, comp)| {
                self.longest_chain_for_comp(&conn_map, &[comp.to_string()], 0, comp, &comps[..i])
            })
            .max_by(|a, b| a.len().cmp(&b.len()))
            .expect("should have a max")
    }

    fn longest_chain_for_comp(
        &self,
        conn_map: &HashMap<String, Vec<String>>,
        cur_chain: &[String],
        cur_idx: usize,
        first_comp: &String,
        already_done: &[String],
    ) -> Vec<String> {
        let connnected_comps = &conn_map[first_comp];

        if cur_idx == connnected_comps.len() {
            return cur_chain.to_vec();
        }

        let next_comp = connnected_comps[cur_idx].clone();

        let longest_by_skipping_this_comp =
            self.longest_chain_for_comp(conn_map, cur_chain, cur_idx + 1, first_comp, already_done);

        if already_done.contains(&next_comp) {
            return longest_by_skipping_this_comp;
        }

        if self.comp_is_connected_to_all(&cur_chain[1..], conn_map, next_comp.to_string()) {
            let longest_with_comp = self.longest_chain_for_comp(
                conn_map,
                &[cur_chain, &[next_comp.to_string()]].concat(),
                cur_idx + 1,
                first_comp,
                already_done,
            );
            if longest_with_comp.len() > longest_by_skipping_this_comp.len() {
                return longest_with_comp;
            }
        }

        longest_by_skipping_this_comp
    }

    fn comp_is_connected_to_all(
        &self,
        chain: &[String],
        conn_map: &HashMap<String, Vec<String>>,
        new_comp: String,
    ) -> bool {
        chain.iter().all(|comp| {
            let conns = &conn_map[comp];
            conns.contains(&new_comp)
        })
    }

    fn get_connection_map(&self) -> HashMap<String, Vec<String>> {
        let mut map: HashMap<String, Vec<String>> = HashMap::new();

        self.connections.iter().for_each(|conn| {
            let (left, right) = conn;

            if let Some(cur_list) = map.get_mut(left) {
                cur_list.push(right.clone());
            } else {
                map.insert(left.clone(), vec![right.clone()]);
            }

            if let Some(cur_list) = map.get_mut(right) {
                cur_list.push(left.clone());
            } else {
                map.insert(right.clone(), vec![left.clone()]);
            }
        });

        map
    }
}

impl From<&str> for NetworkMap {
    fn from(value: &str) -> Self {
        let connections = value
            .lines()
            .map(|line| {
                let (left, right) = line.split_once("-").expect("must have a hyphen");
                (left.into(), right.into())
            })
            .collect();

        Self { connections }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let network = read_input("example.txt").expect("failed to read input");
        assert_eq!(part1(&network), 7);
    }

    #[test]
    fn part2_works() {
        let network = read_input("example.txt").expect("failed to read input");
        assert_eq!(part2(&network), "co,de,ka,ta".to_string());
    }
}
