/// Tests for pool creation and joining.
#[test_only]
module world_cup_pool::pool_tests;

use sui::test_scenario::{Self as ts};
use world_cup_pool::pool::{Self, Pool};
use world_cup_pool::test_utils::{Self as tu};

#[test]
fun create_pool() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(
        fee,
        deadlines,
        option::some(fee_coin),
        ts::ctx(&mut scenario),
    );

    ts::next_tx(&mut scenario, tu::creator());
    let pool = ts::take_shared<Pool>(&scenario);

    assert!(pool.entry_fee() == fee);
    assert!(pool.participant_count() == 1);
    assert!(pool.prize_pool_value() == fee);
    assert!(pool.results_entered() == 0);
    assert!(pool.is_participant(tu::creator()));
    assert!(!pool.is_finalized());

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun create_free_pool() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(
        0,
        deadlines,
        option::none(),
        ts::ctx(&mut scenario),
    );

    ts::next_tx(&mut scenario, tu::creator());
    let pool = ts::take_shared<Pool>(&scenario);

    assert!(pool.entry_fee() == 0);
    assert!(pool.participant_count() == 1);
    assert!(pool.prize_pool_value() == 0);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun join_pool() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(
        fee,
        deadlines,
        option::some(fee_coin),
        ts::ctx(&mut scenario),
    );

    // User1 joins
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let join_coin = tu::mint_sui(fee, &mut scenario);
    pool.join(option::some(join_coin), ts::ctx(&mut scenario));

    assert!(pool.participant_count() == 2);
    assert!(pool.prize_pool_value() == fee * 2);
    assert!(pool.is_participant(tu::user1()));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun join_free_pool() {
    let mut scenario = tu::begin();
    let deadlines = tu::default_deadlines();

    let cap = pool::create(
        0,
        deadlines,
        option::none(),
        ts::ctx(&mut scenario),
    );

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    pool.join(option::none(), ts::ctx(&mut scenario));

    assert!(pool.participant_count() == 2);
    assert!(pool.prize_pool_value() == 0);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 1, location = world_cup_pool::pool)]
fun cannot_join_twice() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(
        fee,
        deadlines,
        option::some(fee_coin),
        ts::ctx(&mut scenario),
    );

    // Creator tries to join again
    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let join_coin = tu::mint_sui(fee, &mut scenario);
    pool.join(option::some(join_coin), ts::ctx(&mut scenario));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 2, location = world_cup_pool::pool)]
fun wrong_fee_amount() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(
        fee,
        deadlines,
        option::some(fee_coin),
        ts::ctx(&mut scenario),
    );

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<Pool>(&scenario);
    let wrong_coin = tu::mint_sui(fee / 2, &mut scenario);
    pool.join(option::some(wrong_coin), ts::ctx(&mut scenario));

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 3, location = world_cup_pool::pool)]
fun invalid_deadlines_wrong_length() {
    let mut scenario = tu::begin();

    let cap = pool::create(
        0,
        vector[1000, 2000, 3000],
        option::none(),
        ts::ctx(&mut scenario),
    );

    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 3, location = world_cup_pool::pool)]
fun invalid_deadlines_zero_value() {
    let mut scenario = tu::begin();

    let cap = pool::create(
        0,
        vector[0, 2000, 3000, 4000, 5000, 6000, 7000],
        option::none(),
        ts::ctx(&mut scenario),
    );

    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 3, location = world_cup_pool::pool)]
fun invalid_deadlines_not_non_decreasing() {
    let mut scenario = tu::begin();

    let cap = pool::create(
        0,
        vector[1000, 2000, 1500, 4000, 5000, 6000, 7000],
        option::none(),
        ts::ctx(&mut scenario),
    );

    pool::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test]
fun multiple_participants_join() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let deadlines = tu::default_deadlines();
    let fee_coin = tu::mint_sui(fee, &mut scenario);

    let cap = pool::create(
        fee,
        deadlines,
        option::some(fee_coin),
        ts::ctx(&mut scenario),
    );

    // 4 more participants join
    let users = vector[tu::user1(), tu::user2(), tu::user3(), tu::user4()];
    let mut i = 0;
    while (i < users.length()) {
        let user = *users.borrow(i);
        ts::next_tx(&mut scenario, user);
        let mut pool = ts::take_shared<Pool>(&scenario);
        let coin = tu::mint_sui(fee, &mut scenario);
        pool.join(option::some(coin), ts::ctx(&mut scenario));
        ts::return_shared(pool);
        i = i + 1;
    };

    ts::next_tx(&mut scenario, tu::creator());
    let pool = ts::take_shared<Pool>(&scenario);
    assert!(pool.participant_count() == 5);
    assert!(pool.prize_pool_value() == fee * 5);

    ts::return_shared(pool);
    pool::destroy_cap_for_testing(cap);
    scenario.end();
}
