/// Tests for prize distribution, ties, and edge cases.
#[test_only]
module world_cup_pool::distribution_tests;

use sui::test_scenario::{Self as ts};
use world_cup_pool::pool::{Self, Pool, PoolCreatorCap};
use world_cup_pool::test_utils::{Self as tu};

/// Helper: create a pool with N participants (creator + N-1 users).
fun setup_pool_with_n_participants(
    n: u64,
    fee: u64,
    scenario: &mut ts::Scenario,
): PoolCreatorCap {
    let deadlines = tu::default_deadlines();
    let fee_coin = if (fee > 0) {
        option::some(tu::mint_sui(fee, scenario))
    } else {
        option::none()
    };

    let cap = pool::create(fee, deadlines, fee_coin, ts::ctx(scenario));

    let users = vector[
        tu::user1(), tu::user2(), tu::user3(), tu::user4(),
        tu::user5(), tu::user6(), tu::user7(), tu::user8(),
        tu::user9(), tu::user10(),
    ];

    let mut i = 0;
    while (i < n - 1 && i < users.length()) {
        let user = *users.borrow(i);
        ts::next_tx(scenario, user);
        let mut pool = ts::take_shared<Pool>(scenario);
        if (fee > 0) {
            let coin = tu::mint_sui(fee, scenario);
            pool.join(option::some(coin), ts::ctx(scenario));
        } else {
            pool.join(option::none(), ts::ctx(scenario));
        };
        ts::return_shared(pool);
        i = i + 1;
    };

    cap
}

/// Helper: enter all 104 results as Home (1) and finalize.
fun enter_all_results_and_finalize(
    pool: &mut Pool,
    cap: &PoolCreatorCap,
) {
    let (indices, outcomes) = tu::all_match_indices_and_home();
    pool.enter_results(cap, indices, outcomes);
    pool.finalize(cap);
}

// === Standard 8+ participant distribution ===

#[test]
fun standard_distribution_8_participants() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000; // 1 SUI
    let cap = setup_pool_with_n_participants(8, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Set distinct points for all 8 participants
    pool.set_participant_points_for_testing(tu::creator(), 80);
    pool.set_participant_points_for_testing(tu::user1(), 70);
    pool.set_participant_points_for_testing(tu::user2(), 60);
    pool.set_participant_points_for_testing(tu::user3(), 50);
    pool.set_participant_points_for_testing(tu::user4(), 40);
    pool.set_participant_points_for_testing(tu::user5(), 30);
    pool.set_participant_points_for_testing(tu::user6(), 20);
    pool.set_participant_points_for_testing(tu::user7(), 10);

    enter_all_results_and_finalize(&mut pool, &cap);

    // Pool = 8 SUI = 8_000_000_000 MIST
    // Prize BPs: [4000, 2000, 1000, 800, 550, 550, 550, 550], total = 10000
    assert!(pool.participant_prize(tu::creator()) == 3_200_000_000);
    assert!(pool.participant_prize(tu::user1()) == 1_600_000_000);
    assert!(pool.participant_prize(tu::user2()) == 800_000_000);
    assert!(pool.participant_prize(tu::user3()) == 640_000_000);
    assert!(pool.participant_prize(tu::user4()) == 440_000_000);
    assert!(pool.participant_prize(tu::user5()) == 440_000_000);
    assert!(pool.participant_prize(tu::user6()) == 440_000_000);
    assert!(pool.participant_prize(tu::user7()) == 440_000_000);

    assert!(pool.is_finalized());
    assert!(pool.leaderboard().length() == 8);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Tie handling ===

#[test]
fun tied_first_place() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(8, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Creator and user1 tie for 1st
    pool.set_participant_points_for_testing(tu::creator(), 80);
    pool.set_participant_points_for_testing(tu::user1(), 80);
    pool.set_participant_points_for_testing(tu::user2(), 60);
    pool.set_participant_points_for_testing(tu::user3(), 50);
    pool.set_participant_points_for_testing(tu::user4(), 40);
    pool.set_participant_points_for_testing(tu::user5(), 30);
    pool.set_participant_points_for_testing(tu::user6(), 20);
    pool.set_participant_points_for_testing(tu::user7(), 10);

    enter_all_results_and_finalize(&mut pool, &cap);

    // Tied 1st-2nd: sum BPs 4000+2000=6000, each gets pool * 6000 / (10000 * 2)
    // 8B * 6000 / (10000 * 2) = 2_400_000_000
    assert!(pool.participant_prize(tu::creator()) == 2_400_000_000);
    assert!(pool.participant_prize(tu::user1()) == 2_400_000_000);
    // 3rd place gets normal 1000 BP
    assert!(pool.participant_prize(tu::user2()) == 800_000_000);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Less than 8 participants ===

#[test]
fun three_participants() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(3, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    pool.set_participant_points_for_testing(tu::user1(), 30);
    pool.set_participant_points_for_testing(tu::user2(), 10);

    enter_all_results_and_finalize(&mut pool, &cap);

    // Pool = 3 SUI = 3_000_000_000
    // First 3 BPs: [4000, 2000, 1000], sum = 7000
    // 1st: 3B * 4000 / 7000 = 1_714_285_714
    // 2nd: 3B * 2000 / 7000 =   857_142_857
    // 3rd: 3B * 1000 / 7000 =   428_571_428
    assert!(pool.participant_prize(tu::creator()) == 1_714_285_714);
    assert!(pool.participant_prize(tu::user1()) == 857_142_857);
    assert!(pool.participant_prize(tu::user2()) == 428_571_428);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Single participant ===

#[test]
fun single_participant() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(1, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    enter_all_results_and_finalize(&mut pool, &cap);

    // Single participant: BP [4000], total = 4000
    // Prize: 1B * 4000 / 4000 = 1_000_000_000 (full amount)
    assert!(pool.participant_prize(tu::creator()) == 1_000_000_000);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Claim tests ===

#[test]
fun claim_prize_transfers_sui() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(2, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    pool.set_participant_points_for_testing(tu::user1(), 30);
    enter_all_results_and_finalize(&mut pool, &cap);

    assert!(pool.participant_prize(tu::creator()) > 0);

    // Creator claims
    pool.claim_prize(ts::ctx(&mut scenario));
    assert!(pool.participant_claimed(tu::creator()));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 11, location = world_cup_pool::pool)]
fun cannot_double_claim() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(2, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    pool.set_participant_points_for_testing(tu::user1(), 30);
    enter_all_results_and_finalize(&mut pool, &cap);

    pool.claim_prize(ts::ctx(&mut scenario));
    // Try again
    pool.claim_prize(ts::ctx(&mut scenario));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 10, location = world_cup_pool::pool)]
fun cannot_claim_before_finalize() {
    let mut scenario = tu::begin();
    let cap = setup_pool_with_n_participants(2, 1_000_000_000, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.claim_prize(ts::ctx(&mut scenario));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 8, location = world_cup_pool::pool)]
fun cannot_finalize_without_all_results() {
    let mut scenario = tu::begin();
    let cap = setup_pool_with_n_participants(2, 0, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Enter only 50 results
    let (indices, outcomes) = tu::match_range(0, 50, 1);
    pool.enter_results(&cap, indices, outcomes);

    pool.finalize(&cap);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 9, location = world_cup_pool::pool)]
fun cannot_finalize_twice() {
    let mut scenario = tu::begin();
    let cap = setup_pool_with_n_participants(2, 0, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    enter_all_results_and_finalize(&mut pool, &cap);
    pool.finalize(&cap);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Withdraw remainder ===

#[test]
fun withdraw_dust() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let cap = setup_pool_with_n_participants(3, fee, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    pool.set_participant_points_for_testing(tu::user1(), 30);
    pool.set_participant_points_for_testing(tu::user2(), 10);
    enter_all_results_and_finalize(&mut pool, &cap);

    // Creator claims
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1 claims
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User2 claims
    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // Creator withdraws dust
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let remainder = pool.prize_pool_value();
    // Should have 1 MIST dust (3B - 2_999_999_999)
    assert!(remainder == 1);
    pool.withdraw_remainder(&cap, ts::ctx(&mut scenario));
    assert!(pool.prize_pool_value() == 0);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Free pool distribution ===

#[test]
fun free_pool_finalization() {
    let mut scenario = tu::begin();
    let cap = setup_pool_with_n_participants(3, 0, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    pool.set_participant_points_for_testing(tu::creator(), 50);
    pool.set_participant_points_for_testing(tu::user1(), 30);
    pool.set_participant_points_for_testing(tu::user2(), 10);
    enter_all_results_and_finalize(&mut pool, &cap);

    // All prizes should be 0 (no money in pool)
    assert!(pool.participant_prize(tu::creator()) == 0);
    assert!(pool.participant_prize(tu::user1()) == 0);
    assert!(pool.participant_prize(tu::user2()) == 0);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === View function tests ===

#[test]
fun leaderboard_is_sorted() {
    let mut scenario = tu::begin();
    let cap = setup_pool_with_n_participants(4, 0, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    // Set points in non-sorted order
    pool.set_participant_points_for_testing(tu::creator(), 20);
    pool.set_participant_points_for_testing(tu::user1(), 50);
    pool.set_participant_points_for_testing(tu::user2(), 10);
    pool.set_participant_points_for_testing(tu::user3(), 40);

    enter_all_results_and_finalize(&mut pool, &cap);

    let lb = pool.leaderboard();
    assert!(lb.length() == 4);
    assert!(lb.borrow(0).leaderboard_entry_points() == 50); // user1
    assert!(lb.borrow(1).leaderboard_entry_points() == 40); // user3
    assert!(lb.borrow(2).leaderboard_entry_points() == 20); // creator
    assert!(lb.borrow(3).leaderboard_entry_points() == 10); // user2

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
