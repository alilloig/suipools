/// Module: test_utils
/// Shared test infrastructure for the World Cup SuiPoolool tests.
#[test_only]
module world_cup_pool::test_utils;

use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};
use world_cup_pool::tournament::{Self, Tournament, AdminCap};

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

/// Returns default prize BPS: top 3 winner-takes-most distribution.
public fun default_prize_bps(): vector<u64> {
    vector[5000, 3000, 2000]
}

/// Returns a bets vector where all 104 matches are bet as Home (1).
public fun all_home_bets(): vector<u8> {
    vector::tabulate!(104, |_| 1u8)
}

/// Returns a bets vector where all 104 matches are bet as Away (3).
public fun all_away_bets(): vector<u8> {
    vector::tabulate!(104, |_| 3u8)
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

/// Create a Tournament and AdminCap for testing.
public fun create_tournament(scenario: &mut Scenario): (Tournament, AdminCap) {
    tournament::create_for_testing(ts::ctx(scenario))
}

/// Enter all 104 results as Home (1) into a tournament.
/// Also sets group_phase_complete.
public fun enter_all_tournament_results(tournament: &mut Tournament, admin: &AdminCap) {
    // Enter group results (Home win, no draws)
    let (group_indices, group_outcomes) = match_range(0, 72, 1);
    tournament.enter_results(admin, group_indices, group_outcomes);

    // Enter knockout results (Home win, no draws)
    let (ko_indices, ko_outcomes) = match_range(72, 104, 1);
    tournament.enter_results(admin, ko_indices, ko_outcomes);
}
