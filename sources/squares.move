/// Module: squares
/// Super Bowl Squares pool -- 10x10 grid game.
module world_cup_pool::squares;

use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::event;
use sui::random::Random;
use sui::sui::SUI;
use sui::table::{Self, Table};

// === Errors ===
const EGridFull: u64 = 0;
const ESquareTaken: u64 = 1;
const EInvalidPosition: u64 = 2;
const EInvalidPrizeBps: u64 = 3;
const EMaxSquaresReached: u64 = 4;
const EGridNotFull: u64 = 5;
const ENumbersAlreadyAssigned: u64 = 6;
const ENumbersNotAssigned: u64 = 7;
const EInvalidQuarter: u64 = 8;
const EScoreAlreadyEntered: u64 = 9;
const ENotWinner: u64 = 10;
const EAlreadyClaimed: u64 = 11;
const EScoreNotEntered: u64 = 12;
const EIncorrectFee: u64 = 13;
const ENotAllClaimed: u64 = 14;

// === Constants ===
const GRID_SIZE: u64 = 100;
const SIDE: u64 = 10;
const QUARTERS: u64 = 4;

// === Structs ===
public struct SquaresPool has key {
    id: UID,
    grid: vector<Option<address>>,
    row_numbers: vector<u8>,
    col_numbers: vector<u8>,
    squares_claimed: u64,
    entry_fee: u64,
    max_per_player: u64,
    prize_bps: vector<u64>,
    player_squares: Table<address, u64>,
    prize_pool: Balance<SUI>,
    quarterly_scores: vector<Option<QuarterScore>>,
    quarterly_winners: vector<Option<address>>,
    quarterly_claimed: vector<bool>,
}

public struct QuarterScore has store, copy, drop {
    team_a: u64,
    team_b: u64,
}

public struct SquaresCreatorCap has key, store {
    id: UID,
    pool_id: ID,
}

// === Events ===
public struct SquaresPoolCreated has copy, drop {
    pool_id: ID,
    creator: address,
    entry_fee: u64,
    max_per_player: u64,
}

public struct SquareBought has copy, drop {
    pool_id: ID,
    position: u64,
    buyer: address,
}

public struct NumbersAssigned has copy, drop {
    pool_id: ID,
    row_numbers: vector<u8>,
    col_numbers: vector<u8>,
}

public struct QuarterScoreEntered has copy, drop {
    pool_id: ID,
    quarter: u64,
    team_a: u64,
    team_b: u64,
    winner: address,
}

public struct QuarterPrizeClaimed has copy, drop {
    pool_id: ID,
    quarter: u64,
    winner: address,
    amount: u64,
}

// === Public Functions ===

/// Create a new Super Bowl Squares pool.
public fun create(
    entry_fee: u64,
    max_per_player: u64,
    prize_bps: vector<u64>,
    ctx: &mut TxContext,
): SquaresCreatorCap {
    assert!(prize_bps.length() == QUARTERS, EInvalidPrizeBps);
    let mut sum: u64 = 0;
    let mut i = 0;
    while (i < QUARTERS) {
        sum = sum + *prize_bps.borrow(i);
        i = i + 1;
    };
    assert!(sum == 10000, EInvalidPrizeBps);
    assert!(max_per_player >= 1, EMaxSquaresReached);

    let creator = ctx.sender();

    let pool = SquaresPool {
        id: object::new(ctx),
        grid: vector::tabulate!(GRID_SIZE, |_| option::none<address>()),
        row_numbers: vector[],
        col_numbers: vector[],
        squares_claimed: 0,
        entry_fee,
        max_per_player,
        prize_bps,
        player_squares: table::new(ctx),
        prize_pool: balance::zero(),
        quarterly_scores: vector::tabulate!(QUARTERS, |_| option::none<QuarterScore>()),
        quarterly_winners: vector::tabulate!(QUARTERS, |_| option::none<address>()),
        quarterly_claimed: vector[false, false, false, false],
    };

    let pool_id = object::id(&pool);
    let cap = SquaresCreatorCap { id: object::new(ctx), pool_id };

    event::emit(SquaresPoolCreated { pool_id, creator, entry_fee, max_per_player });
    transfer::share_object(pool);
    cap
}

/// Buy a square at the given position (0-99).
public fun buy_square(
    pool: &mut SquaresPool,
    position: u64,
    coin: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert!(position < GRID_SIZE, EInvalidPosition);
    assert!(pool.grid.borrow(position).is_none(), ESquareTaken);
    assert!(pool.squares_claimed < GRID_SIZE, EGridFull);

    let buyer = ctx.sender();

    let current_count = if (pool.player_squares.contains(buyer)) {
        *pool.player_squares.borrow(buyer)
    } else {
        0
    };
    assert!(current_count < pool.max_per_player, EMaxSquaresReached);

    if (pool.entry_fee > 0) {
        assert!(coin.value() == pool.entry_fee, EIncorrectFee);
        pool.prize_pool.join(coin.into_balance());
    } else {
        assert!(coin.value() == 0, EIncorrectFee);
        coin.destroy_zero();
    };

    *pool.grid.borrow_mut(position) = option::some(buyer);
    pool.squares_claimed = pool.squares_claimed + 1;

    if (pool.player_squares.contains(buyer)) {
        let count = pool.player_squares.borrow_mut(buyer);
        *count = *count + 1;
    } else {
        pool.player_squares.add(buyer, 1);
    };

    event::emit(SquareBought { pool_id: object::id(pool), position, buyer });
}

/// Randomly assign digits 0-9 to rows and columns via Fisher-Yates shuffle.
public fun assign_numbers(
    pool: &mut SquaresPool,
    random: &Random,
    ctx: &mut TxContext,
) {
    assert!(pool.squares_claimed == GRID_SIZE, EGridNotFull);
    assert!(pool.row_numbers.is_empty(), ENumbersAlreadyAssigned);

    let mut gen = random.new_generator(ctx);

    let mut rows = vector::tabulate!(SIDE, |i| (i as u8));
    let mut i = SIDE;
    while (i > 1) {
        i = i - 1;
        let j = gen.generate_u64_in_range(0, i);
        rows.swap(i, j);
    };

    let mut cols = vector::tabulate!(SIDE, |i| (i as u8));
    let mut k = SIDE;
    while (k > 1) {
        k = k - 1;
        let j = gen.generate_u64_in_range(0, k);
        cols.swap(k, j);
    };

    pool.row_numbers = rows;
    pool.col_numbers = cols;

    event::emit(NumbersAssigned {
        pool_id: object::id(pool),
        row_numbers: pool.row_numbers,
        col_numbers: pool.col_numbers,
    });
}

/// Admin enters score for a quarter and resolves winner.
public fun enter_score(
    pool: &mut SquaresPool,
    cap: &SquaresCreatorCap,
    quarter: u64,
    team_a_score: u64,
    team_b_score: u64,
) {
    assert!(cap.pool_id == object::id(pool));
    assert!(!pool.row_numbers.is_empty(), ENumbersNotAssigned);
    assert!(quarter < QUARTERS, EInvalidQuarter);
    assert!(pool.quarterly_scores.borrow(quarter).is_none(), EScoreAlreadyEntered);

    let score = QuarterScore { team_a: team_a_score, team_b: team_b_score };
    *pool.quarterly_scores.borrow_mut(quarter) = option::some(score);

    let winner = resolve_winner(pool, team_a_score, team_b_score);
    *pool.quarterly_winners.borrow_mut(quarter) = option::some(winner);

    event::emit(QuarterScoreEntered {
        pool_id: object::id(pool),
        quarter,
        team_a: team_a_score,
        team_b: team_b_score,
        winner,
    });
}

/// Winner claims their prize for a specific quarter.
#[allow(lint(self_transfer))]
public fun claim_prize(
    pool: &mut SquaresPool,
    quarter: u64,
    ctx: &mut TxContext,
) {
    assert!(quarter < QUARTERS, EInvalidQuarter);
    assert!(pool.quarterly_scores.borrow(quarter).is_some(), EScoreNotEntered);
    assert!(!*pool.quarterly_claimed.borrow(quarter), EAlreadyClaimed);

    let winner = option::destroy_some(*pool.quarterly_winners.borrow(quarter));
    let sender = ctx.sender();
    assert!(sender == winner, ENotWinner);

    *pool.quarterly_claimed.borrow_mut(quarter) = true;

    let original_total = pool.entry_fee * GRID_SIZE;
    let bps = *pool.prize_bps.borrow(quarter);
    let amount = (((original_total as u128) * (bps as u128)) / 10000u128) as u64;

    let prize_coin = pool.prize_pool.split(amount).into_coin(ctx);
    transfer::public_transfer(prize_coin, sender);

    event::emit(QuarterPrizeClaimed {
        pool_id: object::id(pool),
        quarter,
        winner: sender,
        amount,
    });
}

/// Creator withdraws remaining dust after all 4 quarters claimed.
#[allow(lint(self_transfer))]
public fun withdraw_remainder(
    pool: &mut SquaresPool,
    cap: &SquaresCreatorCap,
    ctx: &mut TxContext,
) {
    assert!(cap.pool_id == object::id(pool));
    let mut i = 0;
    while (i < QUARTERS) {
        assert!(*pool.quarterly_claimed.borrow(i), ENotAllClaimed);
        i = i + 1;
    };

    let remainder = pool.prize_pool.value();
    if (remainder > 0) {
        let coin = pool.prize_pool.split(remainder).into_coin(ctx);
        transfer::public_transfer(coin, ctx.sender());
    };
}

// === View Functions ===
public fun entry_fee(pool: &SquaresPool): u64 { pool.entry_fee }
public fun max_per_player(pool: &SquaresPool): u64 { pool.max_per_player }
public fun squares_claimed(pool: &SquaresPool): u64 { pool.squares_claimed }
public fun prize_pool_value(pool: &SquaresPool): u64 { pool.prize_pool.value() }
public fun numbers_assigned(pool: &SquaresPool): bool { !pool.row_numbers.is_empty() }
public fun row_numbers(pool: &SquaresPool): &vector<u8> { &pool.row_numbers }
public fun col_numbers(pool: &SquaresPool): &vector<u8> { &pool.col_numbers }
public fun grid_cell(pool: &SquaresPool, position: u64): &Option<address> { pool.grid.borrow(position) }
public fun quarterly_winner(pool: &SquaresPool, quarter: u64): &Option<address> { pool.quarterly_winners.borrow(quarter) }
public fun quarterly_claimed(pool: &SquaresPool, quarter: u64): bool { *pool.quarterly_claimed.borrow(quarter) }
public fun cap_pool_id(cap: &SquaresCreatorCap): ID { cap.pool_id }

// === Internal Functions ===
fun resolve_winner(pool: &SquaresPool, team_a_score: u64, team_b_score: u64): address {
    let digit_a = team_a_score % 10;
    let digit_b = team_b_score % 10;

    let mut row_idx: u64 = 0;
    let mut i: u64 = 0;
    while (i < SIDE) {
        if ((*pool.row_numbers.borrow(i) as u64) == digit_a) {
            row_idx = i;
            break
        };
        i = i + 1;
    };

    let mut col_idx: u64 = 0;
    let mut j: u64 = 0;
    while (j < SIDE) {
        if ((*pool.col_numbers.borrow(j) as u64) == digit_b) {
            col_idx = j;
            break
        };
        j = j + 1;
    };

    let position = row_idx * SIDE + col_idx;
    option::destroy_some(*pool.grid.borrow(position))
}

// === Test-Only Functions ===
#[test_only]
public fun destroy_cap_for_testing(cap: SquaresCreatorCap) {
    let SquaresCreatorCap { id, .. } = cap;
    id.delete();
}
