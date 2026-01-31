/// Tests for scoring logic, compute_total_score, and tournament result entry.
#[test_only]
module world_cup_pool::scoring_tests;

use world_cup_pool::scoring;
use world_cup_pool::tournament;
use world_cup_pool::test_utils::{Self as tu};

// === Pure scoring function tests ===

#[test]
fun phase_mapping() {
    // Group stage
    assert!(scoring::phase_for_match(0) == 0);
    assert!(scoring::phase_for_match(71) == 0);
    // R32
    assert!(scoring::phase_for_match(72) == 1);
    assert!(scoring::phase_for_match(87) == 1);
    // R16
    assert!(scoring::phase_for_match(88) == 2);
    assert!(scoring::phase_for_match(95) == 2);
    // QF
    assert!(scoring::phase_for_match(96) == 3);
    assert!(scoring::phase_for_match(99) == 3);
    // SF
    assert!(scoring::phase_for_match(100) == 4);
    assert!(scoring::phase_for_match(101) == 4);
    // 3rd
    assert!(scoring::phase_for_match(102) == 5);
    // Final
    assert!(scoring::phase_for_match(103) == 6);
}

#[test]
fun point_values() {
    assert!(scoring::points_for_match(0) == 1);    // Group
    assert!(scoring::points_for_match(72) == 2);   // R32
    assert!(scoring::points_for_match(88) == 3);   // R16
    assert!(scoring::points_for_match(96) == 5);   // QF
    assert!(scoring::points_for_match(100) == 8);  // SF
    assert!(scoring::points_for_match(102) == 8);  // 3rd
    assert!(scoring::points_for_match(103) == 13); // Final
}

#[test]
fun group_index_mapping() {
    assert!(scoring::group_index_for_match(0) == 0);
    assert!(scoring::group_index_for_match(5) == 0);
    assert!(scoring::group_index_for_match(6) == 1);
    assert!(scoring::group_index_for_match(66) == 11);
    assert!(scoring::group_index_for_match(71) == 11);
}

#[test]
fun group_completeness() {
    let mut results = vector::tabulate!(104, |_| 0u8);
    // Fill group 0 (matches 0-5)
    let mut j: u64 = 0;
    while (j < 6) {
        *results.borrow_mut(j) = 1u8;
        j = j + 1;
    };

    assert!(scoring::is_group_complete(&results, 0));
    assert!(!scoring::is_group_complete(&results, 1));
}

#[test]
fun group_bonus_all_correct() {
    let bets = tu::all_home_bets();
    let results = tu::all_home_bets();

    assert!(scoring::check_group_bonus(&bets, &results, 0) == 3);
}

#[test]
fun group_bonus_one_wrong() {
    let mut bets = tu::all_home_bets();
    let results = tu::all_home_bets();
    // Make one bet wrong in group 0
    *bets.borrow_mut(3) = 2u8;

    assert!(scoring::check_group_bonus(&bets, &results, 0) == 0);
}

// === compute_total_score tests ===

#[test]
fun compute_total_score_all_correct() {
    let bets = tu::all_home_bets();
    let results = tu::all_home_bets();

    // 72 group matches * 1 + 16 R32 * 2 + 8 R16 * 3 + 4 QF * 5 + 2 SF * 8 + 1 3rd * 8 + 1 Final * 13
    // = 72 + 32 + 24 + 20 + 16 + 8 + 13 = 185
    // + 12 group bonuses * 3 = 36
    // Total = 221
    let score = scoring::compute_total_score(&bets, &results);
    assert!(score == 221);
}

#[test]
fun compute_total_score_all_wrong() {
    let bets = tu::all_away_bets();
    let results = tu::all_home_bets();

    let score = scoring::compute_total_score(&bets, &results);
    assert!(score == 0);
}

#[test]
fun compute_total_score_no_bets() {
    let bets = vector::tabulate!(104, |_| 0u8); // No bets placed
    let results = tu::all_home_bets();

    let score = scoring::compute_total_score(&bets, &results);
    assert!(score == 0);
}

#[test]
fun compute_total_score_partial_group_correct() {
    let mut bets = vector::tabulate!(104, |_| 0u8);
    let results = tu::all_home_bets();

    // Bet correctly on 3 of 6 matches in group 0
    *bets.borrow_mut(0) = 1;
    *bets.borrow_mut(1) = 1;
    *bets.borrow_mut(2) = 1;
    // Bet wrong on 3
    *bets.borrow_mut(3) = 3;
    *bets.borrow_mut(4) = 3;
    *bets.borrow_mut(5) = 3;

    // 3 correct * 1 point = 3, no group bonus
    let score = scoring::compute_total_score(&bets, &results);
    assert!(score == 3);
}

// === Tournament result entry tests ===

#[test]
fun tournament_enter_results() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    tournament.enter_results(&admin, vector[0, 1, 2], vector[1, 2, 3]);
    assert!(tournament.results_entered() == 3);
    assert!(*tournament.results().borrow(0) == 1);
    assert!(*tournament.results().borrow(1) == 2);
    assert!(*tournament.results().borrow(2) == 3);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}

#[test, expected_failure(abort_code = 2, location = world_cup_pool::tournament)]
fun tournament_cannot_enter_twice() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    tournament.enter_results(&admin, vector[0], vector[1]);
    tournament.enter_results(&admin, vector[0], vector[2]);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}

#[test, expected_failure(abort_code = 3, location = world_cup_pool::tournament)]
fun tournament_no_draw_in_knockout() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    // Match 72 is R32 (knockout)
    tournament.enter_results(&admin, vector[72], vector[2]);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}

#[test]
fun tournament_group_phase_complete() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    // Enter all 72 group results
    let (indices, outcomes) = tu::match_range(0, 72, 1);
    tournament.enter_results(&admin, indices, outcomes);

    assert!(tournament.group_phase_complete());
    assert!(tournament.results_entered() == 72);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}

#[test]
fun tournament_advance_phase() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    // Enter all group results
    let (indices, outcomes) = tu::match_range(0, 72, 1);
    tournament.enter_results(&admin, indices, outcomes);

    assert!(tournament.current_phase() == 0);
    tournament.advance_phase(&admin);
    assert!(tournament.current_phase() == 1);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}

#[test, expected_failure(abort_code = 4, location = world_cup_pool::tournament)]
fun tournament_cannot_advance_incomplete_phase() {
    let mut scenario = tu::begin();
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    // Enter only 50 of 72 group results
    let (indices, outcomes) = tu::match_range(0, 50, 1);
    tournament.enter_results(&admin, indices, outcomes);

    // Try to advance
    tournament.advance_phase(&admin);

    tournament::destroy_for_testing(tournament, admin);
    scenario.end();
}
