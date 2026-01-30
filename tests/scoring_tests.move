/// Tests for result entry, scoring, and group bonus.
#[test_only]
module world_cup_pool::scoring_tests;

use sui::test_scenario::{Self as ts};
use std::unit_test::destroy;
use world_cup_pool::pool::{Self, Pool};
use world_cup_pool::scoring;
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
    let mut results = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        results.push_back(0u8);
        i = i + 1;
    };
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
    let mut bets = vector[];
    let mut results = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        bets.push_back(1u8);
        results.push_back(1u8);
        i = i + 1;
    };

    assert!(scoring::check_group_bonus(&bets, &results, 0) == 3);
}

#[test]
fun group_bonus_one_wrong() {
    let mut bets = vector[];
    let mut results = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        bets.push_back(1u8);
        results.push_back(1u8);
        i = i + 1;
    };
    // Make one bet wrong in group 0
    *bets.borrow_mut(3) = 2u8;

    assert!(scoring::check_group_bonus(&bets, &results, 0) == 0);
}

// === Result entry & scoring integration tests ===

#[test]
fun enter_group_results_scores_correctly() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    // Creator bets all Home on group 0
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    let (indices, outcomes) = tu::match_range(0, 6, 1);
    pool.place_bets(indices, outcomes, &clock, ts::ctx(&mut scenario));

    // Enter results: matches 0-2 Home (correct), 3-5 Away (incorrect)
    pool.enter_results(
        &cap,
        vector[0, 1, 2, 3, 4, 5],
        vector[1, 1, 1, 3, 3, 3],
    );

    // 3 correct group matches = 3 points, no group bonus (only 3/6 correct)
    assert!(pool.participant_points(tu::creator()) == 3);
    assert!(pool.results_entered() == 6);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun group_bonus_awarded() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Bet all Home on group 0
    let (indices, outcomes) = tu::match_range(0, 6, 1);
    pool.place_bets(indices, outcomes, &clock, ts::ctx(&mut scenario));

    // Enter all 6 as Home (all correct)
    pool.enter_results(
        &cap,
        vector[0, 1, 2, 3, 4, 5],
        vector[1, 1, 1, 1, 1, 1],
    );

    // 6 correct × 1 point + 3 bonus = 9 points
    assert!(pool.participant_points(tu::creator()) == 9);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun knockout_scoring() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Bet Home on one match from each knockout phase
    pool.place_bets(
        vector[72, 88, 96, 100, 102, 103],
        vector[1, 1, 1, 1, 1, 1],
        &clock,
        ts::ctx(&mut scenario),
    );

    // Enter results: all correct
    pool.enter_results(
        &cap,
        vector[72, 88, 96, 100, 102, 103],
        vector[1, 1, 1, 1, 1, 1],
    );

    // R32: 2 + R16: 3 + QF: 5 + SF: 8 + 3rd: 8 + Final: 13 = 39
    assert!(pool.participant_points(tu::creator()) == 39);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun multi_participant_scoring() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(fee, deadlines, option::some(fee_coin), ts::ctx(&mut scenario));

    // User1 joins
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let coin1 = tu::mint_sui(fee, &mut scenario);
    pool.join(option::some(coin1), ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // Creator bets Home on match 0
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);
    pool.place_bets(vector[0], vector[1], &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1 bets Away on match 0
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.place_bets(vector[0], vector[3], &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // Result is Home (1)
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.enter_results(&cap, vector[0], vector[1]);

    assert!(pool.participant_points(tu::creator()) == 1); // Correct
    assert!(pool.participant_points(tu::user1()) == 0);   // Wrong

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 14, location = world_cup_pool::pool)]
fun cannot_enter_result_twice() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.enter_results(&cap, vector[0], vector[1]);
    // Try to enter again
    pool.enter_results(&cap, vector[0], vector[2]);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 9, location = world_cup_pool::pool)]
fun cannot_enter_results_after_finalize() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Enter all 104 results
    let (indices, outcomes) = tu::all_match_indices_and_home();
    pool.enter_results(&cap, indices, outcomes);
    pool.finalize(&cap);

    // Try to enter more results
    pool.enter_results(&cap, vector[0], vector[1]);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun no_bet_means_no_points() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Don't place any bets, but enter a result
    pool.enter_results(&cap, vector[0], vector[1]);
    assert!(pool.participant_points(tu::creator()) == 0);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
