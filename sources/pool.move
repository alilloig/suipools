/// Module: pool
/// Core module for the World Cup SuiPoolool.
/// Manages pool creation, joining, betting, scoring, and prize distribution.
/// Results are stored globally in the Tournament object (tournament.move).
module world_cup_pool::pool;

use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;
use sui::table::{Self, Table};
use world_cup_pool::scoring;
use world_cup_pool::tournament::Tournament;

// === Errors ===
const ENotParticipant: u64 = 0;
const EAlreadyJoined: u64 = 1;
const EIncorrectFee: u64 = 2;
const EInvalidPrizeBps: u64 = 3;
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
const EPhaseNotOpen: u64 = 14;
const EInvalidMatchIndex: u64 = 15;
const ENoDrawInKnockout: u64 = 16;

// === Constants ===

/// Total matches
const TOTAL_MATCHES: u64 = 104;

/// Hardcoded deadlines (ms) - 1 minute before first match of each phase.
/// 2026 FIFA World Cup schedule (UTC):
///   Group stage:    Jun 11, 2026 15:00 UTC -> deadline 14:59
///   R32:            Jul 1, 2026 15:00 UTC  -> deadline 14:59
///   R16:            Jul 5, 2026 15:00 UTC  -> deadline 14:59
///   QF:             Jul 9, 2026 15:00 UTC  -> deadline 14:59
///   SF:             Jul 13, 2026 19:00 UTC -> deadline 18:59
///   3rd place:      Jul 18, 2026 19:00 UTC -> deadline 18:59
///   Final:          Jul 19, 2026 19:00 UTC -> deadline 18:59
const DEADLINE_GROUP: u64 = 1_781_362_740_000; // Jun 11, 2026 14:59 UTC
const DEADLINE_R32: u64 = 1_783_090_740_000; // Jul 1, 2026 14:59 UTC
const DEADLINE_R16: u64 = 1_783_436_340_000; // Jul 5, 2026 14:59 UTC
const DEADLINE_QF: u64 = 1_783_781_940_000; // Jul 9, 2026 14:59 UTC
const DEADLINE_SF: u64 = 1_784_142_000_000; // Jul 13, 2026 18:59 UTC  (adjusted, these are 19:00 starts)
const DEADLINE_3RD: u64 = 1_784_574_000_000; // Jul 18, 2026 18:59 UTC
const DEADLINE_FINAL: u64 = 1_784_660_400_000; // Jul 19, 2026 18:59 UTC

// === Structs ===

/// The main pool object, shared.
public struct Pool has key {
    id: UID,
    /// Entry fee in MIST (0 = free pool)
    entry_fee: u64,
    /// Prize distribution in basis points (out of 10000), non-increasing
    prize_bps: vector<u64>,
    /// Accumulated prize pool
    prize_pool: Balance<SUI>,
    /// List of participant addresses (for iteration)
    participants: vector<address>,
    /// Participant data keyed by address
    participant_data: Table<address, ParticipantData>,
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
    /// Points (computed at finalize)
    points: u64,
    /// Prize amount (set on finalize)
    prize_amount: u64,
    /// Whether prize has been claimed
    claimed: bool,
}

/// Leaderboard entry for sorting
public struct LeaderboardEntry has copy, drop, store {
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
/// `prize_bps` must sum to 10000, be non-increasing, and have length >= 1.
/// If entry_fee > 0, `fee_coin` must contain exactly that amount.
public fun create(
    entry_fee: u64,
    prize_bps: vector<u64>,
    mut fee_coin: Option<Coin<SUI>>,
    ctx: &mut TxContext,
): PoolCreatorCap {
    // Validate prize_bps
    assert!(prize_bps.length() >= 1, EInvalidPrizeBps);
    let mut sum: u64 = 0;
    let mut i = 0;
    while (i < prize_bps.length()) {
        let bp = *prize_bps.borrow(i);
        assert!(bp > 0, EInvalidPrizeBps);
        sum = sum + bp;
        if (i > 0) {
            assert!(bp <= *prize_bps.borrow(i - 1), EInvalidPrizeBps);
        };
        i = i + 1;
    };
    assert!(sum == 10000, EInvalidPrizeBps);

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
        prize_bps,
        prize_pool,
        participants: vector[creator],
        participant_data,
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
public fun join(pool: &mut Pool, mut fee_coin: Option<Coin<SUI>>, ctx: &mut TxContext) {
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
/// Phase gating: match's phase must be <= tournament.current_phase.
/// Deadline gating: clock must be before the hardcoded deadline for the match's phase.
/// No draws allowed for knockout matches (index >= 72).
public fun place_bets(
    pool: &mut Pool,
    tournament: &Tournament,
    match_indices: vector<u64>,
    outcomes: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    let sender = ctx.sender();
    assert!(pool.participant_data.contains(sender), ENotParticipant);
    assert!(match_indices.length() == outcomes.length(), EVectorLengthMismatch);

    let now = clock.timestamp_ms();
    let current_phase = tournament.current_phase();
    let data = pool.participant_data.borrow_mut(sender);
    let len = match_indices.length();

    let mut i = 0;
    while (i < len) {
        let match_idx = *match_indices.borrow(i);
        let outcome = *outcomes.borrow(i);

        assert!(match_idx < TOTAL_MATCHES, EInvalidMatchIndex);
        assert!(outcome >= 1 && outcome <= 3, EInvalidOutcome);

        // Phase gating
        let match_phase = scoring::phase_for_match(match_idx);
        assert!((match_phase as u8) <= current_phase, EPhaseNotOpen);

        // Deadline gating
        let deadline = deadline_for_phase(match_phase);
        assert!(now < deadline, EBettingClosed);

        // No draws in knockout
        if (match_idx >= 72) {
            assert!(outcome != 2, ENoDrawInKnockout);
        };

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

/// Finalize the pool using tournament results.
/// Requires all 104 tournament results to be entered.
/// Computes scores via compute_total_score and distributes prizes per pool's prize_bps.
public fun finalize(pool: &mut Pool, cap: &PoolCreatorCap, tournament: &Tournament) {
    assert!(cap.pool_id == object::id(pool));
    assert!(!pool.finalized, EAlreadyFinalized);
    assert!(tournament.results_entered() == TOTAL_MATCHES, ENotAllResultsEntered);

    let results = tournament.results();
    let num_participants = pool.participants.length();

    // Compute scores for all participants
    let mut entries = vector[];
    let mut i = 0;
    while (i < num_participants) {
        let addr = *pool.participants.borrow(i);
        let data = pool.participant_data.borrow_mut(addr);
        let score = scoring::compute_total_score(&data.bets, results);
        data.points = score;
        entries.push_back(LeaderboardEntry {
            participant: addr,
            points: score,
        });
        i = i + 1;
    };

    // Sort by points descending
    sort_leaderboard_desc(&mut entries);

    // Compute prizes
    let pool_value = pool.prize_pool.value();
    let prize_bps = &pool.prize_bps;
    let num_prize_slots = if (num_participants < prize_bps.length()) {
        num_participants
    } else {
        prize_bps.length()
    };

    // Calculate total BPs used
    let mut total_bp_used: u64 = 0;
    let mut j = 0;
    while (j < num_prize_slots) {
        total_bp_used = total_bp_used + *prize_bps.borrow(j);
        j = j + 1;
    };

    // Assign prizes handling ties
    let mut pos = 0;
    while (pos < num_prize_slots) {
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
public fun claim_prize(pool: &mut Pool, ctx: &mut TxContext) {
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
#[allow(lint(self_transfer))]
public fun withdraw_remainder(pool: &mut Pool, cap: &PoolCreatorCap, ctx: &mut TxContext) {
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

/// Returns the prize distribution basis points.
public fun prize_bps(pool: &Pool): &vector<u64> {
    &pool.prize_bps
}

/// Returns the number of participants.
public fun participant_count(pool: &Pool): u64 {
    pool.participants.length()
}

/// Returns the prize pool value in MIST.
public fun prize_pool_value(pool: &Pool): u64 {
    pool.prize_pool.value()
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

/// Creates a new ParticipantData with zeroed bets.
fun new_participant_data(): ParticipantData {
    ParticipantData {
        bets: vector::tabulate!(TOTAL_MATCHES, |_| 0u8),
        points: 0,
        prize_amount: 0,
        claimed: false,
    }
}

/// Returns the hardcoded deadline (ms) for a given phase.
fun deadline_for_phase(phase: u8): u64 {
    if (phase == 0) { DEADLINE_GROUP } else if (phase == 1) { DEADLINE_R32 } else if (phase == 2) {
        DEADLINE_R16
    } else if (phase == 3) { DEADLINE_QF } else if (phase == 4) { DEADLINE_SF } else if (
        phase == 5
    ) { DEADLINE_3RD } else { DEADLINE_FINAL }
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
