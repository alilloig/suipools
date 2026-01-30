/// Tests for bet placement, deadlines, and immutability.
#[test_only]
module world_cup_pool::betting_tests;

use sui::test_scenario::{Self as ts};
use std::unit_test::destroy;
use world_cup_pool::pool::{Self, Pool};
use world_cup_pool::test_utils::{Self as tu};

#[test]
fun place_single_bet() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0], vector[1], &clock, ts::ctx(&mut scenario));
    assert!(*pool.participant_bets(tu::creator()).borrow(0) == 1);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun place_multiple_bets() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Bet on first 6 group matches (group 0)
    let (indices, outcomes) = tu::match_range(0, 6, 1);
    pool.place_bets(indices, outcomes, &clock, ts::ctx(&mut scenario));

    let bets = pool.participant_bets(tu::creator());
    let mut i: u64 = 0;
    while (i < 6) {
        assert!(*bets.borrow(i) == 1);
        i = i + 1;
    };
    // Match 6 should still be 0
    assert!(*bets.borrow(6) == 0);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun place_bets_different_phases() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(
        vector[0, 72, 88, 96, 100, 102, 103],
        vector[1, 2, 3, 1, 2, 3, 1],
        &clock,
        ts::ctx(&mut scenario),
    );

    let bets = pool.participant_bets(tu::creator());
    assert!(*bets.borrow(0) == 1);
    assert!(*bets.borrow(72) == 2);
    assert!(*bets.borrow(88) == 3);
    assert!(*bets.borrow(96) == 1);
    assert!(*bets.borrow(100) == 2);
    assert!(*bets.borrow(102) == 3);
    assert!(*bets.borrow(103) == 1);

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 5, location = world_cup_pool::pool)]
fun cannot_overwrite_bet() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0], vector[1], &clock, ts::ctx(&mut scenario));
    // Try to overwrite
    pool.place_bets(vector[0], vector[2], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 4, location = world_cup_pool::pool)]
fun betting_closed_after_deadline() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    // Clock is at group deadline (1_000_000) — not strictly before, so betting is closed
    let clock = tu::create_clock(1_000_000, &mut scenario);

    pool.place_bets(vector[0], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 4, location = world_cup_pool::pool)]
fun r32_betting_closed() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    // Past R32 deadline (2_000_000)
    let clock = tu::create_clock(2_500_000, &mut scenario);

    pool.place_bets(vector[72], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 6, location = world_cup_pool::pool)]
fun invalid_outcome_zero() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0], vector[0], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 6, location = world_cup_pool::pool)]
fun invalid_outcome_four() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0], vector[4], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 7, location = world_cup_pool::pool)]
fun mismatched_vectors() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0, 1], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = world_cup_pool::pool)]
fun non_participant_cannot_bet() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    // User1 hasn't joined
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[0], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 15, location = world_cup_pool::pool)]
fun invalid_match_index() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(0, deadlines, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(vector[104], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
