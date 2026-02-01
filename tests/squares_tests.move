#[test_only]
module world_cup_pool::squares_tests;

use sui::random;
use sui::random::Random;
use sui::test_scenario::{Self as ts};
use world_cup_pool::squares::{Self, SquaresPool};
use world_cup_pool::test_utils::{Self as tu};

// === Helper: fill grid with one user ===
fun fill_grid(pool: &mut SquaresPool, scenario: &mut ts::Scenario) {
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, scenario);
        pool.buy_square(i, coin, ts::ctx(scenario));
        i = i + 1;
    };
}

fun fill_grid_with_fee(pool: &mut SquaresPool, fee: u64, scenario: &mut ts::Scenario) {
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(fee, scenario);
        pool.buy_square(i, coin, ts::ctx(scenario));
        i = i + 1;
    };
}

// Helper: set up a pool with full grid and assigned numbers
fun setup_full_pool_with_numbers(scenario: &mut ts::Scenario): squares::SquaresCreatorCap {
    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(scenario));

    ts::next_tx(scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(scenario);
    fill_grid(&mut pool, scenario);
    ts::return_shared(pool);

    ts::next_tx(scenario, @0x0);
    random::create_for_testing(ts::ctx(scenario));

    ts::next_tx(scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(scenario);
    let random = ts::take_shared<Random>(scenario);
    pool.assign_numbers(&random, ts::ctx(scenario));
    ts::return_shared(random);
    ts::return_shared(pool);

    cap
}

// ==================== Task 1: Create tests ====================

#[test]
fun create_squares_pool() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let prize_bps = vector[2000, 2000, 2000, 4000];

    let cap = squares::create(fee, 5, prize_bps, ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let pool = ts::take_shared<SquaresPool>(&scenario);

    assert!(pool.entry_fee() == fee);
    assert!(pool.max_per_player() == 5);
    assert!(pool.squares_claimed() == 0);
    assert!(!pool.numbers_assigned());

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 3, location = world_cup_pool::squares)]
fun create_invalid_prize_bps() {
    let mut scenario = tu::begin();
    let cap = squares::create(0, 5, vector[2000, 2000, 2000], ts::ctx(&mut scenario));
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

// ==================== Task 2: buy_square tests ====================

#[test]
fun buy_single_square() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 5, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin, ts::ctx(&mut scenario));

    assert!(pool.squares_claimed() == 1);
    assert!(pool.prize_pool_value() == fee);
    assert!(pool.grid_cell(0).is_some());

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 1, location = world_cup_pool::squares)]
fun cannot_buy_taken_square() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 5, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin2 = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin2, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 4, location = world_cup_pool::squares)]
fun cannot_exceed_max_per_player() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 1, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin1 = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin1, ts::ctx(&mut scenario));

    let coin2 = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(1, coin2, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 2, location = world_cup_pool::squares)]
fun invalid_position() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 5, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(0, &mut scenario);
    pool.buy_square(100, coin, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

// ==================== Task 3: assign_numbers tests ====================

#[test]
fun assign_numbers_after_grid_full() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    fill_grid(&mut pool, &mut scenario);
    assert!(pool.squares_claimed() == 100);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);

    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    assert!(pool.numbers_assigned());
    assert!(pool.row_numbers().length() == 10);
    assert!(pool.col_numbers().length() == 10);

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 5, location = world_cup_pool::squares)]
fun cannot_assign_numbers_grid_not_full() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(0, &mut scenario);
    pool.buy_square(0, coin, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 6, location = world_cup_pool::squares)]
fun cannot_assign_numbers_twice() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    fill_grid(&mut pool, &mut scenario);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

// ==================== Task 4: enter_score tests ====================

#[test]
fun enter_score_resolves_winner() {
    let mut scenario = tu::begin();
    let cap = setup_full_pool_with_numbers(&mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.enter_score(&cap, 0, 7, 3);
    assert!(pool.quarterly_winner(0).is_some());

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 7, location = world_cup_pool::squares)]
fun cannot_enter_score_without_numbers() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.enter_score(&cap, 0, 7, 3);

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 8, location = world_cup_pool::squares)]
fun invalid_quarter() {
    let mut scenario = tu::begin();
    let cap = setup_full_pool_with_numbers(&mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.enter_score(&cap, 4, 7, 3);

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 9, location = world_cup_pool::squares)]
fun cannot_enter_score_twice() {
    let mut scenario = tu::begin();
    let cap = setup_full_pool_with_numbers(&mut scenario);

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.enter_score(&cap, 0, 7, 3);
    pool.enter_score(&cap, 0, 14, 10);

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

// ==================== Task 5: claim_prize tests ====================

#[test]
fun claim_quarterly_prize() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    fill_grid_with_fee(&mut pool, fee, &mut scenario);
    let total_prize = pool.prize_pool_value();
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));
    pool.enter_score(&cap, 0, 7, 3);
    ts::return_shared(random);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.claim_prize(0, ts::ctx(&mut scenario));

    assert!(pool.quarterly_claimed(0));
    // Q1 = 25% of original total (fee * 100)
    let expected_payout = total_prize * 2500 / 10000;
    assert!(pool.prize_pool_value() == total_prize - expected_payout);

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 10, location = world_cup_pool::squares)]
fun non_winner_cannot_claim() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    fill_grid_with_fee(&mut pool, fee, &mut scenario);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));
    pool.enter_score(&cap, 0, 7, 3);
    ts::return_shared(random);
    ts::return_shared(pool);

    // User2 (who owns no squares) tries to claim
    ts::next_tx(&mut scenario, tu::user2());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.claim_prize(0, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 11, location = world_cup_pool::squares)]
fun cannot_claim_twice() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    fill_grid(&mut pool, &mut scenario);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, @0x0);
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));
    pool.enter_score(&cap, 0, 7, 3);
    ts::return_shared(random);
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.claim_prize(0, ts::ctx(&mut scenario));
    pool.claim_prize(0, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
