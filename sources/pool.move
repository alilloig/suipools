/// Module: pool
/// Core module for the World Cup office pool.
/// Manages pool creation, joining, betting, result entry, scoring, and prize distribution.
module world_cup_pool::pool;

// === Imports ===
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::clock::Clock;
use sui::event;
use sui::sui::SUI;
use sui::table::{Self, Table};
use world_cup_pool::scoring;

// === Errors ===
const ENotParticipant: u64 = 0;
const EAlreadyJoined: u64 = 1;
const EIncorrectFee: u64 = 2;
const EInvalidDeadlines: u64 = 3;
const EBettingClosed: u64 = 4;
const EBetAlreadyPlaced: u64 = 5;
const EInvalidOutcome: u64 = 6;
const EVectorLengthMismatch: u64 = 7;
const ENotAllResultsEntered: u64 = 8;
const EAlreadyFinalized: u64 = 9;
const ENotFinalized: u64 = 10;
const EAlreadyClaimed: u64 = 11;
const ENoPrize: u64 = 12;
const EPoolNotEmpty: u64 = 13;
const EResultAlreadyEntered: u64 = 14;
const EInvalidMatchIndex: u64 = 15;

// === Constants ===

/// Number of deadline slots (one per phase)
const NUM_DEADLINES: u64 = 7;

/// Total matches
const TOTAL_MATCHES: u64 = 104;

/// Prize distribution in basis points (out of 10000)
/// 1st: 4000, 2nd: 2000, 3rd: 1000, 4th: 800, 5th-8th: 550 each
const PRIZE_BPS: vector<u64> = vector[4000, 2000, 1000, 800, 550, 550, 550, 550];

// === Structs ===

/// The main pool object, shared.
public struct Pool has key {
    id: UID,
    /// Entry fee in MIST (0 = free pool)
    entry_fee: u64,
    /// 7 deadlines (ms timestamps), one per phase
    deadlines: vector<u64>,
    /// Accumulated prize pool
    prize_pool: Balance<SUI>,
    /// List of participant addresses (for iteration)
    participants: vector<address>,
    /// Participant data keyed by address
    participant_data: Table<address, ParticipantData>,
    /// 104-element results vector (0=not entered, 1=Home, 2=Draw, 3=Away)
    results: vector<u8>,
    /// Number of results entered so far
    results_entered: u64,
    /// Whether the pool has been finalized
    finalized: bool,
    /// Number of prizes claimed
    claims_made: u64,
    /// Leaderboard (populated on finalize)
    leaderboard: vector<LeaderboardEntry>,
}

/// Capability for the pool creator
public struct PoolCreatorCap has key, store {
    id: UID,
    pool_id: ID,
}

/// Per-participant data stored in the Pool's table
public struct ParticipantData has store {
    /// 104-element bets vector
    bets: vector<u8>,
    /// Accumulated points
    points: u64,
    /// Whether group bonus has been checked for each of 12 groups
    group_bonus_checked: vector<bool>,
    /// Prize amount (set on finalize)
    prize_amount: u64,
    /// Whether prize has been claimed
    claimed: bool,
}

/// Leaderboard entry for sorting
public struct LeaderboardEntry has store, copy, drop {
    participant: address,
    points: u64,
}

// === Events ===

public struct PoolCreated has copy, drop {
    pool_id: ID,
    creator: address,
    entry_fee: u64,
}

public struct ParticipantJoined has copy, drop {
    pool_id: ID,
    participant: address,
}

public struct BetsPlaced has copy, drop {
    pool_id: ID,
    participant: address,
    match_count: u64,
}

public struct ResultsEntered has copy, drop {
    pool_id: ID,
    match_count: u64,
    total_entered: u64,
}

public struct PoolFinalized has copy, drop {
    pool_id: ID,
    participant_count: u64,
}

public struct PrizeClaimed has copy, drop {
    pool_id: ID,
    participant: address,
    amount: u64,
}

// === Public Functions ===

/// Create a new pool. The creator is automatically joined.
/// `deadlines` must have exactly 7 elements, each > 0, in non-decreasing order.
/// `entry_fee` is in MIST (can be 0 for a free pool).
/// If entry_fee > 0, `fee_coin` must contain exactly that amount.
public fun create(
    entry_fee: u64,
    deadlines: vector<u64>,
    mut fee_coin: Option<Coin<SUI>>,
    ctx: &mut TxContext,
): PoolCreatorCap {
    // Validate deadlines
    assert!(deadlines.length() == NUM_DEADLINES, EInvalidDeadlines);
    let mut i = 0;
    while (i < NUM_DEADLINES) {
        assert!(*deadlines.borrow(i) > 0, EInvalidDeadlines);
        if (i > 0) {
            assert!(*deadlines.borrow(i) >= *deadlines.borrow(i - 1), EInvalidDeadlines);
        };
        i = i + 1;
    };

    // Initialize results vector (104 zeros)
    let results = new_zero_vector_u8(TOTAL_MATCHES);

    let creator = ctx.sender();

    // Build prize pool balance
    let mut prize_pool = balance::zero<SUI>();
    if (entry_fee > 0) {
        let coin = fee_coin.extract();
        assert!(coin.value() == entry_fee, EIncorrectFee);
        prize_pool.join(coin.into_balance());
    } else {
        // No fee; destroy the option if provided
        if (fee_coin.is_some()) {
            let coin = fee_coin.extract();
            assert!(coin.value() == 0, EIncorrectFee);
            coin.destroy_zero();
        };
    };
    fee_coin.destroy_none();

    // Create participant data for creator
    let mut participant_data = table::new<address, ParticipantData>(ctx);
    participant_data.add(creator, new_participant_data());

    let pool = Pool {
        id: object::new(ctx),
        entry_fee,
        deadlines,
        prize_pool,
        participants: vector[creator],
        participant_data,
        results,
        results_entered: 0,
        finalized: false,
        claims_made: 0,
        leaderboard: vector[],
    };

    let pool_id = object::id(&pool);

    let cap = PoolCreatorCap {
        id: object::new(ctx),
        pool_id,
    };

    event::emit(PoolCreated { pool_id, creator, entry_fee });
    event::emit(ParticipantJoined { pool_id, participant: creator });

    transfer::share_object(pool);

    cap
}

/// Join an existing pool. Pays the entry fee.
public fun join(
    pool: &mut Pool,
    mut fee_coin: Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    let participant = ctx.sender();
    assert!(!pool.participant_data.contains(participant), EAlreadyJoined);

    // Handle fee
    if (pool.entry_fee > 0) {
        let coin = fee_coin.extract();
        assert!(coin.value() == pool.entry_fee, EIncorrectFee);
        pool.prize_pool.join(coin.into_balance());
    } else {
        if (fee_coin.is_some()) {
            let coin = fee_coin.extract();
            assert!(coin.value() == 0, EIncorrectFee);
            coin.destroy_zero();
        };
    };
    fee_coin.destroy_none();

    pool.participants.push_back(participant);
    pool.participant_data.add(participant, new_participant_data());

    event::emit(ParticipantJoined {
        pool_id: object::id(pool),
        participant,
    });
}

/// Place bets for specific matches.
/// `match_indices` and `outcomes` must be the same length.
/// Each outcome must be 1 (Home), 2 (Draw), or 3 (Away).
/// Cannot overwrite a previously placed bet (non-zero value).
/// Each match must be before its phase deadline.
public fun place_bets(
    pool: &mut Pool,
    match_indices: vector<u64>,
    outcomes: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    let sender = ctx.sender();
    assert!(pool.participant_data.contains(sender), ENotParticipant);
    assert!(match_indices.length() == outcomes.length(), EVectorLengthMismatch);

    let now = clock.timestamp_ms();
    let data = pool.participant_data.borrow_mut(sender);
    let len = match_indices.length();

    let mut i = 0;
    while (i < len) {
        let match_idx = *match_indices.borrow(i);
        let outcome = *outcomes.borrow(i);

        assert!(match_idx < TOTAL_MATCHES, EInvalidMatchIndex);
        assert!(outcome >= 1 && outcome <= 3, EInvalidOutcome);

        // Check deadline
        let deadline_idx = scoring::deadline_index_for_match(match_idx);
        assert!(now < *pool.deadlines.borrow(deadline_idx), EBettingClosed);

        // Cannot overwrite existing bet
        assert!(*data.bets.borrow(match_idx) == 0, EBetAlreadyPlaced);

        *data.bets.borrow_mut(match_idx) = outcome;

        i = i + 1;
    };

    event::emit(BetsPlaced {
        pool_id: object::id(pool),
        participant: sender,
        match_count: len,
    });
}

/// Enter results for specific matches. Only the pool creator (cap holder) can do this.
/// Scores all participants for each match entered.
/// When a group becomes complete, checks group bonus for all participants.
public fun enter_results(
    pool: &mut Pool,
    cap: &PoolCreatorCap,
    match_indices: vector<u64>,
    outcomes: vector<u8>,
) {
    assert!(cap.pool_id == object::id(pool));
    assert!(!pool.finalized, EAlreadyFinalized);
    assert!(match_indices.length() == outcomes.length(), EVectorLengthMismatch);

    let len = match_indices.length();
    let mut i = 0;

    while (i < len) {
        let match_idx = *match_indices.borrow(i);
        let outcome = *outcomes.borrow(i);

        assert!(match_idx < TOTAL_MATCHES, EInvalidMatchIndex);
        assert!(outcome >= 1 && outcome <= 3, EInvalidOutcome);
        assert!(*pool.results.borrow(match_idx) == 0, EResultAlreadyEntered);

        *pool.results.borrow_mut(match_idx) = outcome;
        pool.results_entered = pool.results_entered + 1;

        // Score all participants for this match
        let points = scoring::points_for_match(match_idx);
        let num_participants = pool.participants.length();
        let mut p = 0;
        while (p < num_participants) {
            let addr = *pool.participants.borrow(p);
            let data = pool.participant_data.borrow_mut(addr);
            if (*data.bets.borrow(match_idx) == outcome) {
                data.points = data.points + points;
            };
            p = p + 1;
        };

        // Check group bonus if this is a group-stage match and group is now complete
        if (match_idx < 72) {
            let group_idx = scoring::group_index_for_match(match_idx);
            if (scoring::is_group_complete(&pool.results, group_idx)) {
                let num_participants = pool.participants.length();
                let mut p = 0;
                while (p < num_participants) {
                    let addr = *pool.participants.borrow(p);
                    let data = pool.participant_data.borrow_mut(addr);
                    if (!*data.group_bonus_checked.borrow(group_idx)) {
                        *data.group_bonus_checked.borrow_mut(group_idx) = true;
                        let bonus = scoring::check_group_bonus(
                            &data.bets,
                            &pool.results,
                            group_idx,
                        );
                        data.points = data.points + bonus;
                    };
                    p = p + 1;
                };
            };
        };

        i = i + 1;
    };

    event::emit(ResultsEntered {
        pool_id: object::id(pool),
        match_count: len,
        total_entered: pool.results_entered,
    });
}

/// Finalize the pool after all results are entered.
/// Builds leaderboard, handles ties, and computes prize amounts.
public fun finalize(
    pool: &mut Pool,
    cap: &PoolCreatorCap,
) {
    assert!(cap.pool_id == object::id(pool));
    assert!(!pool.finalized, EAlreadyFinalized);
    assert!(pool.results_entered == TOTAL_MATCHES, ENotAllResultsEntered);

    let num_participants = pool.participants.length();

    // Build leaderboard entries
    let mut entries = vector[];
    let mut i = 0;
    while (i < num_participants) {
        let addr = *pool.participants.borrow(i);
        let data = pool.participant_data.borrow(addr);
        entries.push_back(LeaderboardEntry {
            participant: addr,
            points: data.points,
        });
        i = i + 1;
    };

    // Sort by points descending (insertion sort — N is small)
    sort_leaderboard_desc(&mut entries);

    // Compute prizes
    let pool_value = pool.prize_pool.value();
    let prize_bps = PRIZE_BPS;
    let num_prize_slots = if (num_participants < prize_bps.length()) {
        num_participants
    } else {
        prize_bps.length()
    };

    // Calculate total BPs used (for <8 participants, sum only first N)
    let mut total_bp_used: u64 = 0;
    let mut j = 0;
    while (j < num_prize_slots) {
        total_bp_used = total_bp_used + *prize_bps.borrow(j);
        j = j + 1;
    };

    // Assign prizes handling ties
    let mut pos = 0;
    while (pos < num_prize_slots) {
        // Find extent of tie at this position
        let current_points = entries.borrow(pos).points;
        let mut tie_end = pos + 1;
        while (tie_end < num_participants && entries.borrow(tie_end).points == current_points) {
            tie_end = tie_end + 1;
        };
        let tie_count = tie_end - pos;

        // Sum BPs for all tied positions
        let mut tie_bp_sum: u64 = 0;
        let mut k = pos;
        while (k < tie_end && k < num_prize_slots) {
            tie_bp_sum = tie_bp_sum + *prize_bps.borrow(k);
            k = k + 1;
        };

        // Each tied participant gets equal share
        let prize_per_person = if (tie_bp_sum > 0 && pool_value > 0) {
            (
                (pool_value as u128) * (tie_bp_sum as u128)
                    / ((total_bp_used as u128) * (tie_count as u128)),
            ) as u64
        } else {
            0
        };

        // Assign to all tied participants
        let mut t = pos;
        while (t < tie_end) {
            let addr = entries.borrow(t).participant;
            let data = pool.participant_data.borrow_mut(addr);
            data.prize_amount = prize_per_person;
            t = t + 1;
        };

        pos = tie_end;
    };

    pool.leaderboard = entries;
    pool.finalized = true;

    event::emit(PoolFinalized {
        pool_id: object::id(pool),
        participant_count: num_participants,
    });
}

/// Claim your prize. Transfers the computed amount to the caller.
#[allow(lint(self_transfer))]
public fun claim_prize(
    pool: &mut Pool,
    ctx: &mut TxContext,
) {
    assert!(pool.finalized, ENotFinalized);
    let sender = ctx.sender();
    assert!(pool.participant_data.contains(sender), ENotParticipant);

    let data = pool.participant_data.borrow_mut(sender);
    assert!(!data.claimed, EAlreadyClaimed);
    assert!(data.prize_amount > 0, ENoPrize);

    data.claimed = true;
    let amount = data.prize_amount;

    pool.claims_made = pool.claims_made + 1;

    let prize_coin = pool.prize_pool.split(amount).into_coin(ctx);
    transfer::public_transfer(prize_coin, sender);

    event::emit(PrizeClaimed {
        pool_id: object::id(pool),
        participant: sender,
        amount,
    });
}

/// Withdraw any remaining dust from the pool after all prizes are claimed.
/// Only the creator can call this.
#[allow(lint(self_transfer))]
public fun withdraw_remainder(
    pool: &mut Pool,
    cap: &PoolCreatorCap,
    ctx: &mut TxContext,
) {
    assert!(cap.pool_id == object::id(pool));
    assert!(pool.finalized, ENotFinalized);

    // Ensure all prize winners have claimed
    pool.participants.do_ref!(|addr| {
        let data = pool.participant_data.borrow(*addr);
        if (data.prize_amount > 0) {
            assert!(data.claimed, EPoolNotEmpty);
        };
    });

    let remainder = pool.prize_pool.value();
    if (remainder > 0) {
        let remainder_coin = pool.prize_pool.split(remainder).into_coin(ctx);
        transfer::public_transfer(remainder_coin, ctx.sender());
    };
}

// === View Functions ===

/// Returns the entry fee for the pool.
public fun entry_fee(pool: &Pool): u64 {
    pool.entry_fee
}

/// Returns the number of participants.
public fun participant_count(pool: &Pool): u64 {
    pool.participants.length()
}

/// Returns the prize pool value in MIST.
public fun prize_pool_value(pool: &Pool): u64 {
    pool.prize_pool.value()
}

/// Returns the number of results entered.
public fun results_entered(pool: &Pool): u64 {
    pool.results_entered
}

/// Returns whether the pool is finalized.
public fun is_finalized(pool: &Pool): bool {
    pool.finalized
}

/// Returns the points for a participant.
public fun participant_points(pool: &Pool, addr: address): u64 {
    pool.participant_data.borrow(addr).points
}

/// Returns the bet vector for a participant.
public fun participant_bets(pool: &Pool, addr: address): &vector<u8> {
    &pool.participant_data.borrow(addr).bets
}

/// Returns the prize amount for a participant (after finalize).
public fun participant_prize(pool: &Pool, addr: address): u64 {
    pool.participant_data.borrow(addr).prize_amount
}

/// Returns whether a participant has claimed their prize.
public fun participant_claimed(pool: &Pool, addr: address): bool {
    pool.participant_data.borrow(addr).claimed
}

/// Returns the leaderboard.
public fun leaderboard(pool: &Pool): &vector<LeaderboardEntry> {
    &pool.leaderboard
}

/// Returns the participant address from a leaderboard entry.
public fun leaderboard_entry_participant(entry: &LeaderboardEntry): address {
    entry.participant
}

/// Returns the points from a leaderboard entry.
public fun leaderboard_entry_points(entry: &LeaderboardEntry): u64 {
    entry.points
}

/// Returns the deadlines vector.
public fun deadlines(pool: &Pool): &vector<u64> {
    &pool.deadlines
}

/// Returns the results vector.
public fun results(pool: &Pool): &vector<u8> {
    &pool.results
}

/// Returns the participants vector.
public fun participants(pool: &Pool): &vector<address> {
    &pool.participants
}

/// Returns whether an address is a participant.
public fun is_participant(pool: &Pool, addr: address): bool {
    pool.participant_data.contains(addr)
}

/// Returns the pool ID from a creator cap.
public fun cap_pool_id(cap: &PoolCreatorCap): ID {
    cap.pool_id
}

// === Internal Functions ===

/// Creates a new ParticipantData with zeroed bets and no bonuses checked.
fun new_participant_data(): ParticipantData {
    ParticipantData {
        bets: new_zero_vector_u8(TOTAL_MATCHES),
        points: 0,
        group_bonus_checked: new_false_vector(12),
        prize_amount: 0,
        claimed: false,
    }
}

/// Creates a vector of `len` zeroes (u8).
fun new_zero_vector_u8(len: u64): vector<u8> {
    vector::tabulate!(len, |_| 0u8)
}

/// Creates a vector of `len` false values.
fun new_false_vector(len: u64): vector<bool> {
    vector::tabulate!(len, |_| false)
}

/// Insertion sort leaderboard entries by points descending.
fun sort_leaderboard_desc(entries: &mut vector<LeaderboardEntry>) {
    let len = entries.length();
    if (len <= 1) return;

    let mut i = 1;
    while (i < len) {
        let current = *entries.borrow(i);
        let mut j = i;
        while (j > 0 && entries.borrow(j - 1).points < current.points) {
            *entries.borrow_mut(j) = *entries.borrow(j - 1);
            j = j - 1;
        };
        *entries.borrow_mut(j) = current;
        i = i + 1;
    };
}

// === Test-Only Functions ===

#[test_only]
public fun destroy_cap_for_testing(cap: PoolCreatorCap) {
    let PoolCreatorCap { id, .. } = cap;
    id.delete();
}

#[test_only]
public fun results_mut_for_testing(pool: &mut Pool): &mut vector<u8> {
    &mut pool.results
}

#[test_only]
public fun set_results_entered_for_testing(pool: &mut Pool, count: u64) {
    pool.results_entered = count;
}

#[test_only]
public fun set_finalized_for_testing(pool: &mut Pool, finalized: bool) {
    pool.finalized = finalized;
}

#[test_only]
public fun set_participant_points_for_testing(pool: &mut Pool, addr: address, points: u64) {
    pool.participant_data.borrow_mut(addr).points = points;
}

#[test_only]
public fun set_participant_prize_for_testing(pool: &mut Pool, addr: address, amount: u64) {
    pool.participant_data.borrow_mut(addr).prize_amount = amount;
}

#[test_only]
public fun set_participant_claimed_for_testing(pool: &mut Pool, addr: address, claimed: bool) {
    pool.participant_data.borrow_mut(addr).claimed = claimed;
}
