use std::{collections::HashMap, fs::read_to_string};

fn main() {
    let puzzle_input = read_input("input.txt").expect("failed to parse input");
    println!("Part 1: {}", part1(&puzzle_input));
    println!("Part 2: {}", part2(&puzzle_input));
}

fn read_input(path: &str) -> Result<PuzzleInput, std::io::Error> {
    let txt = read_to_string(path)?;
    let (rules, page_orders) = txt
        .split_once("\n\n")
        .ok_or(std::io::Error::from(std::io::ErrorKind::UnexpectedEof))?;

    Ok(PuzzleInput {
        pages_not_allowed_before: parse_rules(rules),
        pages_to_produce: parse_pages_to_produce(page_orders),
    })
}

fn parse_rules(rules_str: &str) -> RulesMap {
    let mut rules: RulesMap = HashMap::new();
    rules_str.lines().for_each(|line| {
        let (a, b) = line.split_once("|").expect("invalid input");
        let (a_int, b_int) = (
            a.parse::<u64>().expect("should be num"),
            b.parse::<u64>().expect("should be num"),
        );
        if let Some(cur_list) = rules.get_mut(&a_int) {
            cur_list.push(b_int);
        } else {
            let new_list = vec![b_int];
            rules.insert(a_int, new_list);
        }
    });
    rules
}

fn parse_pages_to_produce(pages_str: &str) -> Vec<PageOrder> {
    pages_str
        .lines()
        .map(|line| {
            line.split(",")
                .map(|n| n.parse::<u64>().expect("should be num"))
                .collect()
        })
        .collect()
}

fn part1(input: &PuzzleInput) -> u64 {
    input
        .pages_to_produce
        .iter()
        .map(|p_order| {
            if page_order_is_correct(p_order, &input.pages_not_allowed_before) {
                get_mid_number(p_order)
            } else {
                0
            }
        })
        .sum()
}

fn part2(input: &PuzzleInput) -> u64 {
    input
        .pages_to_produce
        .iter()
        .filter_map(|p_order| {
            if page_order_is_correct(&p_order, &input.pages_not_allowed_before) {
                None
            } else {
                let sorted = sort_page_order(&p_order, &input.pages_not_allowed_before);
                Some(get_mid_number(&sorted))
            }
        })
        .sum()
}

type PageOrder = Vec<u64>;
type RulesMap = HashMap<u64, Vec<u64>>;

struct PuzzleInput {
    pages_not_allowed_before: RulesMap,
    pages_to_produce: Vec<PageOrder>,
}

fn get_mid_number(l: &PageOrder) -> u64 {
    l[l.len() / 2]
}

fn page_order_is_correct(p_order: &PageOrder, pages_not_allowed_before: &RulesMap) -> bool {
    p_order
        .iter()
        .enumerate()
        .all(|(i, page)| page_is_allowed(&p_order[0..i], page, pages_not_allowed_before))
}

fn page_is_allowed(prev_pages: &[u64], page: &u64, pages_not_allowed_before: &RulesMap) -> bool {
    if let Some(unallowed_list) = pages_not_allowed_before.get(page) {
        prev_pages
            .iter()
            .all(|prev_page| !unallowed_list.contains(prev_page))
    } else {
        true
    }
}

fn sort_page_order(p_order: &PageOrder, pages_not_allowed_before: &RulesMap) -> PageOrder {
    let mut sorted_page_order = Vec::with_capacity(p_order.len());

    p_order.iter().enumerate().for_each(|(i, page)| {
        let mut j = i;

        loop {
            if page_is_allowed(&sorted_page_order[0..j], page, pages_not_allowed_before) {
                sorted_page_order.insert(j, page.clone());
                break;
            }
            j -= 1;
        }
    });

    sorted_page_order
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part1_works() {
        let puzzle_input = read_input("example.txt").expect("failed to parse input");
        let result = part1(&puzzle_input);
        assert_eq!(result, 143);
    }

    #[test]
    fn sort_works() {
        let puzzle_input = read_input("example.txt").expect("failed to parse input");
        puzzle_input.pages_to_produce.iter().for_each(|p_order| {
            let sorted = sort_page_order(p_order, &puzzle_input.pages_not_allowed_before);
            assert!(page_order_is_correct(
                &sorted,
                &puzzle_input.pages_not_allowed_before
            ));
        });
    }

    #[test]
    fn part2_works() {
        let puzzle_input = read_input("example.txt").expect("failed to parse input");
        let result = part2(&puzzle_input);
        assert_eq!(result, 123);
    }
}
