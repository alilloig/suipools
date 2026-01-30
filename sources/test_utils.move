/// Module: test_utils
/// Shared test infrastructure for the World Cup office pool tests.
#[test_only]
module world_cup_pool::test_utils;

use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

// === Test Addresses ===

const CREATOR: address = @0xAD;
const USER1: address = @0x01;
const USER2: address = @0x02;
const USER3: address = @0x03;
const USER4: address = @0x04;
const USER5: address = @0x05;
const USER6: address = @0x06;
const USER7: address = @0x07;
const USER8: address = @0x08;
const USER9: address = @0x09;
const USER10: address = @0x0A;

public fun creator(): address { CREATOR }
public fun user1(): address { USER1 }
public fun user2(): address { USER2 }
public fun user3(): address { USER3 }
public fun user4(): address { USER4 }
public fun user5(): address { USER5 }
public fun user6(): address { USER6 }
public fun user7(): address { USER7 }
public fun user8(): address { USER8 }
public fun user9(): address { USER9 }
public fun user10(): address { USER10 }

// === Helper Functions ===

/// Start a test scenario as the creator.
public fun begin(): Scenario {
    ts::begin(CREATOR)
}

/// Mint a SUI coin for testing.
public fun mint_sui(amount: u64, scenario: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
}

/// Create a clock at a given timestamp (ms).
public fun create_clock(timestamp_ms: u64, scenario: &mut Scenario): Clock {
    let mut clock = clock::create_for_testing(ts::ctx(scenario));
    clock.set_for_testing(timestamp_ms);
    clock
}

/// Returns default deadlines: 7 values, each 1 hour apart starting at 1000000.
public fun default_deadlines(): vector<u64> {
    vector[
        1_000_000,  // Groups
        2_000_000,  // R32
        3_000_000,  // R16
        4_000_000,  // QF
        5_000_000,  // SF
        6_000_000,  // 3rd place
        7_000_000,  // Final
    ]
}

/// Returns a bets vector where all 104 matches are bet as Home (1).
public fun all_home_bets(): vector<u8> {
    let mut v = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        v.push_back(1u8);
        i = i + 1;
    };
    v
}

/// Returns a bets vector where all 104 matches are bet as Away (3).
public fun all_away_bets(): vector<u8> {
    let mut v = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        v.push_back(3u8);
        i = i + 1;
    };
    v
}

/// Returns vectors of all match indices (0..103) and all Home outcomes.
public fun all_match_indices_and_home(): (vector<u64>, vector<u8>) {
    let mut indices = vector[];
    let mut outcomes = vector[];
    let mut i: u64 = 0;
    while (i < 104) {
        indices.push_back(i);
        outcomes.push_back(1);
        i = i + 1;
    };
    (indices, outcomes)
}

/// Returns vectors of match indices and outcomes for a range [start, end).
public fun match_range(start: u64, end: u64, outcome: u8): (vector<u64>, vector<u8>) {
    let mut indices = vector[];
    let mut outcomes = vector[];
    let mut i = start;
    while (i < end) {
        indices.push_back(i);
        outcomes.push_back(outcome);
        i = i + 1;
    };
    (indices, outcomes)
}

/// Default entry fee (1 SUI = 1_000_000_000 MIST).
public fun default_fee(): u64 {
    1_000_000_000
}

/// Destroy a coin in tests.
public fun destroy_coin<T>(coin: Coin<T>) {
    coin::burn_for_testing(coin);
}
