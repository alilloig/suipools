/// Tests for bet placement, deadlines, phase gating, and knockout draw enforcement.
#[test_only]
module world_cup_pool::betting_tests;

use sui::test_scenario::{Self as ts};
use std::unit_test::destroy;
use world_cup_pool::pool::{Self, Pool};
use world_cup_pool::tournament;
use world_cup_pool::test_utils::{Self as tu};

#[test]
fun place_single_bet() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);

    // Clock before group deadline
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[1], &clock, ts::ctx(&mut scenario));
    assert!(*pool.participant_bets(tu::creator()).borrow(0) == 1);

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun place_multiple_bets() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    let (indices, outcomes) = tu::match_range(0, 6, 1);
    pool.place_bets(&tournament, indices, outcomes, &clock, ts::ctx(&mut scenario));

    let bets = pool.participant_bets(tu::creator());
    let mut i: u64 = 0;
    while (i < 6) {
        assert!(*bets.borrow(i) == 1);
        i = i + 1;
    };
    assert!(*bets.borrow(6) == 0);

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun place_bets_different_phases() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    // Open all phases
    tournament.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(
        &tournament,
        vector[0, 72, 88, 96, 100, 102, 103],
        vector[1, 1, 3, 1, 1, 3, 1],  // No draws for knockout matches
        &clock,
        ts::ctx(&mut scenario),
    );

    let bets = pool.participant_bets(tu::creator());
    assert!(*bets.borrow(0) == 1);
    assert!(*bets.borrow(72) == 1);
    assert!(*bets.borrow(88) == 3);
    assert!(*bets.borrow(96) == 1);
    assert!(*bets.borrow(100) == 1);
    assert!(*bets.borrow(102) == 3);
    assert!(*bets.borrow(103) == 1);

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 5, location = world_cup_pool::pool)]
fun cannot_overwrite_bet() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[1], &clock, ts::ctx(&mut scenario));
    pool.place_bets(&tournament, vector[0], vector[2], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 4, location = world_cup_pool::pool)]
fun betting_closed_after_deadline() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    // Clock at group deadline (not strictly before)
    let clock = tu::create_clock(1_781_362_740_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 14, location = world_cup_pool::pool)]
fun phase_not_open() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    // Tournament is at phase 0 (Groups), try to bet on R32 (phase 1)
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[72], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 16, location = world_cup_pool::pool)]
fun no_draw_in_knockout() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    tournament.set_phase_for_testing(1); // Open R32
    let clock = tu::create_clock(500_000, &mut scenario);

    // Try to bet Draw on a R32 match
    pool.place_bets(&tournament, vector[72], vector[2], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun draw_allowed_in_group_stage() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Draw on group stage match is fine
    pool.place_bets(&tournament, vector[0], vector[2], &clock, ts::ctx(&mut scenario));
    assert!(*pool.participant_bets(tu::creator()).borrow(0) == 2);

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 6, location = world_cup_pool::pool)]
fun invalid_outcome_zero() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[0], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 6, location = world_cup_pool::pool)]
fun invalid_outcome_four() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[4], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 7, location = world_cup_pool::pool)]
fun mismatched_vectors() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0, 1], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 0, location = world_cup_pool::pool)]
fun non_participant_cannot_bet() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    // User1 hasn't joined
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[0], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 15, location = world_cup_pool::pool)]
fun invalid_match_index() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();

    let cap = pool::create(0, prize_bps, option::none(), ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (mut tournament, admin) = tu::create_tournament(&mut scenario);
    let clock = tu::create_clock(500_000, &mut scenario);

    pool.place_bets(&tournament, vector[104], vector[1], &clock, ts::ctx(&mut scenario));

    destroy(clock);
    tournament::destroy_for_testing(tournament, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
