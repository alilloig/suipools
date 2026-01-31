/// Tests for prize distribution, ties, and edge cases.
#[test_only]
module world_cup_pool::distribution_tests;

use sui::test_scenario::{Self as ts};
use world_cup_pool::pool::{Self, Pool, PoolCreatorCap};
use world_cup_pool::tournament;
use world_cup_pool::test_utils::{Self as tu};

/// Helper: create a pool with N participants (creator + N-1 users).
fun setup_pool_with_n_participants(
    n: u64,
    fee: u64,
    prize_bps: vector<u64>,
    scenario: &mut ts::Scenario,
): PoolCreatorCap {
    let fee_coin = if (fee > 0) {
        option::some(tu::mint_sui(fee, scenario))
    } else {
        option::none()
    };

    let cap = pool::create(fee, prize_bps, fee_coin, ts::ctx(scenario));

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

/// Helper: finalize pool with tournament that has all results as Home (1).
/// Points are determined by each participant's bets (set before calling this).
fun finalize_with_tournament(
    pool: &mut Pool,
    cap: &PoolCreatorCap,
    scenario: &mut ts::Scenario,
) {
    let (mut tourn, admin) = tu::create_tournament(scenario);
    tu::enter_all_tournament_results(&mut tourn, &admin);
    pool.finalize(cap, &tourn);
    tournament::destroy_for_testing(tourn, admin);
}

/// Helper: place bets from a user for a range of matches.
/// Uses the tournament at the appropriate phase and a clock before the deadline.
fun place_bets_for_range(
    pool: &mut Pool,
    tournament: &tournament::Tournament,
    start: u64,
    end: u64,
    outcome: u8,
    clock: &sui::clock::Clock,
    scenario: &mut ts::Scenario,
) {
    let (indices, outcomes) = tu::match_range(start, end, outcome);
    pool.place_bets(tournament, indices, outcomes, clock, ts::ctx(scenario));
}

// === Standard distribution ===

#[test]
fun standard_distribution_3_participants() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = tu::default_prize_bps(); // [5000, 3000, 2000]
    let cap = setup_pool_with_n_participants(3, fee, prize_bps, &mut scenario);

    // Setup: creator bets all Home (all correct = max score)
    // user1 bets Home on first 50 matches (50 correct groups)
    // user2 bets all Away (0 correct)
    // Scores will be: creator=221, user1=50, user2=0
    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6); // Open all phases
    let clock = tu::create_clock(500_000, &mut scenario);

    // Creator bets all home
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1 bets Home on group matches 0-49
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 50, 1, &clock, &mut scenario);
    ts::return_shared(pool);

    // User2 bets all Away
    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    // Group stage: away
    place_bets_for_range(&mut pool, &tourn, 0, 72, 3, &clock, &mut scenario);
    // Knockout: away
    place_bets_for_range(&mut pool, &tourn, 72, 104, 3, &clock, &mut scenario);
    ts::return_shared(pool);

    // Enter all results and finalize
    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    // Pool = 3 SUI = 3_000_000_000
    // BPS: [5000, 3000, 2000], total = 10000
    // 1st: 3B * 5000 / 10000 = 1_500_000_000
    // 2nd: 3B * 3000 / 10000 =   900_000_000
    // 3rd: 3B * 2000 / 10000 =   600_000_000
    assert!(pool.participant_prize(tu::creator()) == 1_500_000_000);
    assert!(pool.participant_prize(tu::user1()) == 900_000_000);
    assert!(pool.participant_prize(tu::user2()) == 600_000_000);
    assert!(pool.is_finalized());
    assert!(pool.leaderboard().length() == 3);

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Tie handling ===

#[test]
fun tied_first_place() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = tu::default_prize_bps(); // [5000, 3000, 2000]
    let cap = setup_pool_with_n_participants(3, fee, prize_bps, &mut scenario);

    // creator and user1 bet identically (tie), user2 is different
    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Creator: bets Home on all
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1: also bets Home on all (will tie with creator)
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx2, all_out2) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx2, all_out2, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User2: bets all Away (0 points)
    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 72, 3, &clock, &mut scenario);
    place_bets_for_range(&mut pool, &tourn, 72, 104, 3, &clock, &mut scenario);
    ts::return_shared(pool);

    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    // Tied 1st-2nd: sum BPs 5000+3000=8000, each gets pool * 8000 / (10000 * 2)
    // 3B * 8000 / (10000 * 2) = 1_200_000_000
    assert!(pool.participant_prize(tu::creator()) == 1_200_000_000);
    assert!(pool.participant_prize(tu::user1()) == 1_200_000_000);
    // 3rd place gets normal 2000 BP
    assert!(pool.participant_prize(tu::user2()) == 600_000_000);

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Single participant ===

#[test]
fun single_participant() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = vector[10000]; // Winner takes all
    let cap = setup_pool_with_n_participants(1, fee, prize_bps, &mut scenario);

    // Creator bets all home
    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));

    tu::enter_all_tournament_results(&mut tourn, &admin);
    pool.finalize(&cap, &tourn);

    // Single participant gets full amount
    assert!(pool.participant_prize(tu::creator()) == 1_000_000_000);

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Fewer participants than prize slots ===

#[test]
fun fewer_participants_than_slots() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    // 5 prize slots but only 2 participants
    let prize_bps = vector[4000, 2000, 1500, 1500, 1000];
    let cap = setup_pool_with_n_participants(2, fee, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Creator bets all home (highest score)
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1 bets all away (0 score)
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 72, 3, &clock, &mut scenario);
    place_bets_for_range(&mut pool, &tourn, 72, 104, 3, &clock, &mut scenario);
    ts::return_shared(pool);

    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    // Only first 2 BPS used: [4000, 2000], total = 6000
    // Pool = 2 SUI = 2_000_000_000
    // 1st: 2B * 4000 / 6000 = 1_333_333_333
    // 2nd: 2B * 2000 / 6000 =   666_666_666
    assert!(pool.participant_prize(tu::creator()) == 1_333_333_333);
    assert!(pool.participant_prize(tu::user1()) == 666_666_666);

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Claim tests ===

#[test]
fun claim_prize_transfers_sui() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(2, fee, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Creator bets all home
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User1 bets all away
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 72, 3, &clock, &mut scenario);
    place_bets_for_range(&mut pool, &tourn, 72, 104, 3, &clock, &mut scenario);
    ts::return_shared(pool);

    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    assert!(pool.participant_prize(tu::creator()) > 0);
    pool.claim_prize(ts::ctx(&mut scenario));
    assert!(pool.participant_claimed(tu::creator()));

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 11, location = world_cup_pool::pool)]
fun cannot_double_claim() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(2, fee, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));

    tu::enter_all_tournament_results(&mut tourn, &admin);
    pool.finalize(&cap, &tourn);

    pool.claim_prize(ts::ctx(&mut scenario));
    pool.claim_prize(ts::ctx(&mut scenario));

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 10, location = world_cup_pool::pool)]
fun cannot_claim_before_finalize() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(2, 1_000_000_000, prize_bps, &mut scenario);

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
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(2, 0, prize_bps, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    let (indices, outcomes) = tu::match_range(0, 50, 1);
    tourn.enter_results(&admin, indices, outcomes);

    pool.finalize(&cap, &tourn);

    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 9, location = world_cup_pool::pool)]
fun cannot_finalize_twice() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(2, 0, prize_bps, &mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tu::enter_all_tournament_results(&mut tourn, &admin);

    pool.finalize(&cap, &tourn);
    pool.finalize(&cap, &tourn);

    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Free pool distribution ===

#[test]
fun free_pool_finalization() {
    let mut scenario = tu::begin();
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(3, 0, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    // All prizes should be 0 (no money in pool)
    assert!(pool.participant_prize(tu::creator()) == 0);
    assert!(pool.participant_prize(tu::user1()) == 0);
    assert!(pool.participant_prize(tu::user2()) == 0);

    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === View function tests ===

#[test]
fun leaderboard_is_sorted() {
    let mut scenario = tu::begin();
    let prize_bps = vector[4000, 3000, 2000, 1000];
    let cap = setup_pool_with_n_participants(4, 0, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Creator: bet on first 20 group matches home (20 points)
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 20, 1, &clock, &mut scenario);
    ts::return_shared(pool);

    // User1: bet on all matches home (221 points - max score)
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User2: bet on first 10 group matches home (10 points)
    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 10, 1, &clock, &mut scenario);
    ts::return_shared(pool);

    // User3: bet on first 40 group matches home (40 points)
    ts::next_tx(&mut scenario, tu::user3());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 40, 1, &clock, &mut scenario);
    ts::return_shared(pool);

    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    let lb = pool.leaderboard();
    assert!(lb.length() == 4);
    // user1 (all correct: 185 match pts + 36 bonus = 221)
    // user3 (40 group matches correct: 40 + 6 complete groups * 3 bonus = 58)
    // creator (20 group matches correct: 20 + 3 complete groups * 3 bonus = 29)
    // user2 (10 group matches correct: 10 + 1 complete group * 3 bonus = 13)
    assert!(lb.borrow(0).leaderboard_entry_points() == 221); // user1
    assert!(lb.borrow(1).leaderboard_entry_points() == 58);  // user3
    assert!(lb.borrow(2).leaderboard_entry_points() == 29);  // creator
    assert!(lb.borrow(3).leaderboard_entry_points() == 13);  // user2

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

// === Withdraw remainder ===

#[test]
fun withdraw_dust() {
    let mut scenario = tu::begin();
    let fee = 1_000_000_000;
    let prize_bps = tu::default_prize_bps();
    let cap = setup_pool_with_n_participants(3, fee, prize_bps, &mut scenario);

    let (mut tourn, admin) = tu::create_tournament(&mut scenario);
    tourn.set_phase_for_testing(6);
    let clock = tu::create_clock(500_000, &mut scenario);

    // Setup bets: creator=max, user1=mid, user2=0
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let (all_idx, all_out) = tu::all_match_indices_and_home();
    pool.place_bets(&tourn, all_idx, all_out, &clock, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 30, 1, &clock, &mut scenario);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    place_bets_for_range(&mut pool, &tourn, 0, 72, 3, &clock, &mut scenario);
    place_bets_for_range(&mut pool, &tourn, 72, 104, 3, &clock, &mut scenario);
    ts::return_shared(pool);

    tu::enter_all_tournament_results(&mut tourn, &admin);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.finalize(&cap, &tourn);

    // All claim
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.claim_prize(ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // Creator withdraws any remainder
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.withdraw_remainder(&cap, ts::ctx(&mut scenario));
    assert!(pool.prize_pool_value() == 0);

    sui::test_utils::destroy(clock);
    tournament::destroy_for_testing(tourn, admin);
    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
