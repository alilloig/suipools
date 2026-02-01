# Super Bowl Squares Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Super Bowl Squares pool type to SuiPools — a 10x10 grid game where players pick cells, numbers are randomized via `sui::random`, and winners are determined by last-digit score matching at each quarter.

**Architecture:** Single new Move module (`squares.move`) alongside the existing `pool.move`. Frontend gets a new catalog entry, 3 new pages, transaction builders, hooks, and a grid component. No changes to existing World Cup code.

**Tech Stack:** Move 2024 Edition on Sui, React + TypeScript + Vite frontend, `@mysten/dapp-kit`, TailwindCSS.

---

## Task 1: Squares Move Module — Structs, Errors, and `create()`

**Files:**
- Create: `sources/squares.move`

**Step 1: Write the failing test**

Create `tests/squares_tests.move`:

```move
#[test_only]
module world_cup_pool::squares_tests;

use sui::test_scenario::{Self as ts};
use world_cup_pool::squares::{Self, SquaresPool};
use world_cup_pool::test_utils::{Self as tu};

#[test]
fun create_squares_pool() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();
    let prize_bps = vector[2000, 2000, 2000, 4000];

    let cap = squares::create(
        fee,
        5,
        prize_bps,
        ts::ctx(&mut scenario),
    );

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
    let prize_bps = vector[2000, 2000, 2000]; // Sum != 10000

    let cap = squares::create(
        0,
        5,
        prize_bps,
        ts::ctx(&mut scenario),
    );

    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
```

**Step 2: Run test to verify it fails**

Run: `sui move test --filter create_squares_pool`
Expected: FAIL — module `squares` does not exist

**Step 3: Write the module with structs and `create()`**

Create `sources/squares.move`:

```move
/// Module: squares
/// Super Bowl Squares pool — 10x10 grid game.
/// Players pick grid cells, numbers are randomized after the grid fills,
/// and winners are determined by last-digit score matching at each quarter.
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
    /// 100-cell grid: index = row * 10 + col. None = unclaimed.
    grid: vector<Option<address>>,
    /// Digit assignments for rows (empty until randomized)
    row_numbers: vector<u8>,
    /// Digit assignments for columns (empty until randomized)
    col_numbers: vector<u8>,
    /// Count of claimed squares
    squares_claimed: u64,
    /// Cost per square in MIST
    entry_fee: u64,
    /// Max squares one player can own
    max_per_player: u64,
    /// 4-element prize distribution: [Q1, Q2, Q3, Final] summing to 10000
    prize_bps: vector<u64>,
    /// How many squares each player owns
    player_squares: Table<address, u64>,
    /// Accumulated entry fees
    prize_pool: Balance<SUI>,
    /// Quarterly scores (None = not yet entered)
    quarterly_scores: vector<Option<QuarterScore>>,
    /// Resolved winner for each quarter (None = not yet resolved)
    quarterly_winners: vector<Option<address>>,
    /// Whether each quarter's prize has been claimed
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
/// `prize_bps` must be a 4-element vector summing to 10000.
/// `max_per_player` must be >= 1.
public fun create(
    entry_fee: u64,
    max_per_player: u64,
    prize_bps: vector<u64>,
    ctx: &mut TxContext,
): SquaresCreatorCap {
    // Validate prize_bps: must be exactly 4 elements summing to 10000
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

    let cap = SquaresCreatorCap {
        id: object::new(ctx),
        pool_id,
    };

    event::emit(SquaresPoolCreated { pool_id, creator, entry_fee, max_per_player });
    transfer::share_object(pool);
    cap
}

// === View Functions ===

public fun entry_fee(pool: &SquaresPool): u64 { pool.entry_fee }

public fun max_per_player(pool: &SquaresPool): u64 { pool.max_per_player }

public fun squares_claimed(pool: &SquaresPool): u64 { pool.squares_claimed }

public fun prize_pool_value(pool: &SquaresPool): u64 { pool.prize_pool.value() }

public fun numbers_assigned(pool: &SquaresPool): bool { !pool.row_numbers.is_empty() }

public fun row_numbers(pool: &SquaresPool): &vector<u8> { &pool.row_numbers }

public fun col_numbers(pool: &SquaresPool): &vector<u8> { &pool.col_numbers }

public fun grid_cell(pool: &SquaresPool, position: u64): &Option<address> {
    pool.grid.borrow(position)
}

public fun quarterly_winner(pool: &SquaresPool, quarter: u64): &Option<address> {
    pool.quarterly_winners.borrow(quarter)
}

public fun quarterly_claimed(pool: &SquaresPool, quarter: u64): bool {
    *pool.quarterly_claimed.borrow(quarter)
}

public fun cap_pool_id(cap: &SquaresCreatorCap): ID { cap.pool_id }

// === Test-Only Functions ===

#[test_only]
public fun destroy_cap_for_testing(cap: SquaresCreatorCap) {
    let SquaresCreatorCap { id, .. } = cap;
    id.delete();
}
```

**Step 4: Run tests to verify they pass**

Run: `sui move test --filter create_squares`
Expected: PASS (both `create_squares_pool` and `create_invalid_prize_bps`)

**Step 5: Commit**

```bash
git add sources/squares.move tests/squares_tests.move
git commit -m "feat(squares): add SquaresPool struct and create() function"
```

---

## Task 2: `buy_square()` Function

**Files:**
- Modify: `sources/squares.move`
- Modify: `tests/squares_tests.move`

**Step 1: Write failing tests**

Append to `tests/squares_tests.move`:

```move
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

    // User1 buys square 0
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // User2 tries same square
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

    // max_per_player = 1
    let cap = squares::create(fee, 1, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin1 = tu::mint_sui(fee, &mut scenario);
    pool.buy_square(0, coin1, ts::ctx(&mut scenario));

    // Try buying a second
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
    pool.buy_square(100, coin, ts::ctx(&mut scenario)); // Out of bounds

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
```

**Step 2: Run tests to verify they fail**

Run: `sui move test --filter buy_single_square`
Expected: FAIL — `buy_square` not found

**Step 3: Implement `buy_square()`**

Add to `sources/squares.move` after `create()`:

```move
/// Buy a square at the given position (0-99).
/// Payment must match `entry_fee`. Position must be unclaimed.
/// Player must not exceed `max_per_player`.
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

    // Check max_per_player
    let current_count = if (pool.player_squares.contains(buyer)) {
        *pool.player_squares.borrow(buyer)
    } else {
        0
    };
    assert!(current_count < pool.max_per_player, EMaxSquaresReached);

    // Handle payment
    if (pool.entry_fee > 0) {
        assert!(coin.value() == pool.entry_fee, EIncorrectFee);
        pool.prize_pool.join(coin.into_balance());
    } else {
        assert!(coin.value() == 0, EIncorrectFee);
        coin.destroy_zero();
    };

    // Claim the square
    *pool.grid.borrow_mut(position) = option::some(buyer);
    pool.squares_claimed = pool.squares_claimed + 1;

    // Update player count
    if (pool.player_squares.contains(buyer)) {
        let count = pool.player_squares.borrow_mut(buyer);
        *count = *count + 1;
    } else {
        pool.player_squares.add(buyer, 1);
    };

    event::emit(SquareBought {
        pool_id: object::id(pool),
        position,
        buyer,
    });
}
```

**Step 4: Run tests to verify they pass**

Run: `sui move test --filter squares`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add sources/squares.move tests/squares_tests.move
git commit -m "feat(squares): add buy_square() with position and limit validation"
```

---

## Task 3: `assign_numbers()` with `sui::random`

**Files:**
- Modify: `sources/squares.move`
- Modify: `tests/squares_tests.move`

**Step 1: Write failing tests**

Append to `tests/squares_tests.move`:

```move
use sui::random::{Self, Random};

#[test]
fun assign_numbers_after_grid_full() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    // Fill all 100 squares with user1 (max_per_player = 100)
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    assert!(pool.squares_claimed() == 100);
    ts::return_shared(pool);

    // Create Random for testing
    ts::next_tx(&mut scenario, tu::creator());
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

    // Only buy 1 square
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let coin = tu::mint_sui(0, &mut scenario);
    pool.buy_square(0, coin, ts::ctx(&mut scenario));
    ts::return_shared(pool);

    // Try to assign numbers
    ts::next_tx(&mut scenario, tu::creator());
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
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    // Try again
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
```

**Step 2: Run tests to verify they fail**

Run: `sui move test --filter assign_numbers`
Expected: FAIL — `assign_numbers` not found

**Step 3: Implement `assign_numbers()`**

Add to `sources/squares.move`:

```move
/// Randomly assign digits 0-9 to rows and columns.
/// Requires all 100 squares to be claimed. Anyone can call this.
/// Uses sui::random for verifiable on-chain randomness (Fisher-Yates shuffle).
public fun assign_numbers(
    pool: &mut SquaresPool,
    random: &Random,
    ctx: &mut TxContext,
) {
    assert!(pool.squares_claimed == GRID_SIZE, EGridNotFull);
    assert!(pool.row_numbers.is_empty(), ENumbersAlreadyAssigned);

    let mut gen = random.new_generator(ctx);

    // Fisher-Yates shuffle for rows
    let mut rows = vector::tabulate!(SIDE, |i| (i as u8));
    let mut i = SIDE;
    while (i > 1) {
        i = i - 1;
        let j = gen.generate_u64_in_range(0, i);
        rows.swap(i, j);
    };

    // Fisher-Yates shuffle for columns
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
```

**Step 4: Run tests to verify they pass**

Run: `sui move test --filter squares`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add sources/squares.move tests/squares_tests.move
git commit -m "feat(squares): add assign_numbers() with Fisher-Yates shuffle via sui::random"
```

---

## Task 4: `enter_score()` and Winner Resolution

**Files:**
- Modify: `sources/squares.move`
- Modify: `tests/squares_tests.move`

**Step 1: Write failing tests**

Append to `tests/squares_tests.move`:

```move
#[test]
fun enter_score_resolves_winner() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    // Fill grid — user1 gets all squares
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    // Assign numbers
    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    // Enter Q1 score: 7-3
    pool.enter_score(&cap, 0, 7, 3);

    // A winner should be resolved for Q1
    assert!(pool.quarterly_winner(0).is_some());

    ts::return_shared(random);
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

    // Try to enter score before numbers assigned
    pool.enter_score(&cap, 0, 7, 3);

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 8, location = world_cup_pool::squares)]
fun invalid_quarter() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    // Quarter 4 is out of bounds (valid: 0-3)
    pool.enter_score(&cap, 4, 7, 3);

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 9, location = world_cup_pool::squares)]
fun cannot_enter_score_twice() {
    let mut scenario = tu::begin();

    let cap = squares::create(0, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    pool.enter_score(&cap, 0, 7, 3);
    pool.enter_score(&cap, 0, 14, 10); // Same quarter again

    ts::return_shared(random);
    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
```

**Step 2: Run tests to verify they fail**

Run: `sui move test --filter enter_score`
Expected: FAIL — `enter_score` not found

**Step 3: Implement `enter_score()` and `resolve_winner()`**

Add to `sources/squares.move`:

```move
/// Admin enters the score for a quarter (0=Q1, 1=Q2, 2=Q3, 3=Final).
/// Resolves the winner for that quarter based on last-digit matching.
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

    // Resolve winner
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

// === Internal Functions ===

/// Find the owner of the cell matching the last digits of the scores.
fun resolve_winner(pool: &SquaresPool, team_a_score: u64, team_b_score: u64): address {
    let digit_a = team_a_score % 10;
    let digit_b = team_b_score % 10;

    // Find which row index has digit_a
    let mut row_idx: u64 = 0;
    let mut i: u64 = 0;
    while (i < SIDE) {
        if ((*pool.row_numbers.borrow(i) as u64) == digit_a) {
            row_idx = i;
            break
        };
        i = i + 1;
    };

    // Find which col index has digit_b
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
    pool.grid.borrow(position).destroy_some()
}
```

**Step 4: Run tests to verify they pass**

Run: `sui move test --filter squares`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add sources/squares.move tests/squares_tests.move
git commit -m "feat(squares): add enter_score() with last-digit winner resolution"
```

---

## Task 5: `claim_prize()` and `withdraw_remainder()`

**Files:**
- Modify: `sources/squares.move`
- Modify: `tests/squares_tests.move`

**Step 1: Write failing tests**

Append to `tests/squares_tests.move`:

```move
#[test]
fun claim_quarterly_prize() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    // Equal quarterly split
    let cap = squares::create(fee, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    // Fill grid — user1 gets all squares (pays 100 * fee)
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(fee, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    let total_prize = pool.prize_pool_value();
    ts::return_shared(pool);

    // Assign numbers
    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));

    // Enter Q1 score
    pool.enter_score(&cap, 0, 7, 3);
    ts::return_shared(random);
    ts::return_shared(pool);

    // Winner claims Q1 prize
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.claim_prize(0, ts::ctx(&mut scenario));

    assert!(pool.quarterly_claimed(0));
    // Q1 = 25% of total
    assert!(pool.prize_pool_value() == total_prize - (total_prize * 2500 / 10000));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}

#[test, expected_failure(abort_code = 10, location = world_cup_pool::squares)]
fun non_winner_cannot_claim() {
    let mut scenario = tu::begin();
    let fee = tu::default_fee();

    let cap = squares::create(fee, 100, vector[2500, 2500, 2500, 2500], ts::ctx(&mut scenario));

    // User1 fills grid
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(fee, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::creator());
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
    let mut i: u64 = 0;
    while (i < 100) {
        let coin = tu::mint_sui(0, &mut scenario);
        pool.buy_square(i, coin, ts::ctx(&mut scenario));
        i = i + 1;
    };
    ts::return_shared(pool);

    ts::next_tx(&mut scenario, tu::creator());
    random::create_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, tu::creator());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    let random = ts::take_shared<Random>(&scenario);
    pool.assign_numbers(&random, ts::ctx(&mut scenario));
    pool.enter_score(&cap, 0, 7, 3);
    ts::return_shared(random);
    ts::return_shared(pool);

    // Claim once
    ts::next_tx(&mut scenario, tu::user1());
    let mut pool = ts::take_shared<SquaresPool>(&scenario);
    pool.claim_prize(0, ts::ctx(&mut scenario));

    // Claim again — should fail
    pool.claim_prize(0, ts::ctx(&mut scenario));

    ts::return_shared(pool);
    squares::destroy_cap_for_testing(cap);
    scenario.end();
}
```

**Step 2: Run tests to verify they fail**

Run: `sui move test --filter claim`
Expected: FAIL — `claim_prize` not found

**Step 3: Implement `claim_prize()` and `withdraw_remainder()`**

Add to `sources/squares.move`:

```move
/// Winner claims their prize for a specific quarter.
/// Caller must be the resolved winner for that quarter.
#[allow(lint(self_transfer))]
public fun claim_prize(
    pool: &mut SquaresPool,
    quarter: u64,
    ctx: &mut TxContext,
) {
    assert!(quarter < QUARTERS, EInvalidQuarter);
    assert!(pool.quarterly_scores.borrow(quarter).is_some(), EScoreNotEntered);
    assert!(!*pool.quarterly_claimed.borrow(quarter), EAlreadyClaimed);

    let winner = pool.quarterly_winners.borrow(quarter).destroy_some();
    let sender = ctx.sender();
    assert!(sender == winner, ENotWinner);

    *pool.quarterly_claimed.borrow_mut(quarter) = true;

    let total = pool.prize_pool.value() + prize_already_paid(pool);
    let bps = *pool.prize_bps.borrow(quarter);
    let amount = (((total as u128) * (bps as u128)) / 10000u128) as u64;

    let prize_coin = pool.prize_pool.split(amount).into_coin(ctx);
    transfer::public_transfer(prize_coin, sender);

    event::emit(QuarterPrizeClaimed {
        pool_id: object::id(pool),
        quarter,
        winner: sender,
        amount,
    });
}

/// Creator withdraws any remaining dust after all 4 quarters are claimed.
#[allow(lint(self_transfer))]
public fun withdraw_remainder(
    pool: &mut SquaresPool,
    cap: &SquaresCreatorCap,
    ctx: &mut TxContext,
) {
    assert!(cap.pool_id == object::id(pool));

    // All 4 quarters must be claimed
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

/// Sum of prizes already paid out (for computing each quarter's share of original total).
fun prize_already_paid(pool: &SquaresPool): u64 {
    // Original total = current balance + amounts already withdrawn
    // We compute this by recognizing that total * (sum of claimed bps) / 10000 = paid
    // But it's simpler: total prize pool at creation = entry_fee * 100
    pool.entry_fee * GRID_SIZE
}
```

> **Note for implementor:** The `prize_already_paid` helper computes the original total prize pool. Since every cell pays `entry_fee`, the original total is always `entry_fee * 100`. This avoids tracking a separate `original_total` field. Each quarter's payout = `original_total * bps / 10000`.

**Step 4: Run tests to verify they pass**

Run: `sui move test --filter squares`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add sources/squares.move tests/squares_tests.move
git commit -m "feat(squares): add claim_prize() and withdraw_remainder()"
```

---

## Task 6: Frontend — Catalog Entry, Constants, Types, Routes

**Files:**
- Modify: `web/src/data/poolTypes.ts`
- Modify: `web/src/constants/blockchain.ts`
- Modify: `web/src/types/sui.ts`
- Modify: `web/src/App.tsx`

**Step 1: Add catalog entry**

In `web/src/data/poolTypes.ts`, add to `POOL_TYPES` array:

```typescript
  {
    id: "super-bowl-squares",
    title: "Super Bowl Squares",
    icon: "🏈",
    tagline: "Pick your squares, pray for the right digits",
    route: "/super-bowl-squares",
    enabled: true,
  },
```

**Step 2: Add blockchain constants**

In `web/src/constants/blockchain.ts`, add after the existing pool/tournament constants:

```typescript
export const SQUARES_MODULE = "squares";

export const SQUARES_ENTRY_FUNCTIONS = {
  create: "create",
  buySquare: "buy_square",
  assignNumbers: "assign_numbers",
  enterScore: "enter_score",
  claimPrize: "claim_prize",
  withdrawRemainder: "withdraw_remainder",
} as const;

export function squaresTarget(fn: string): `${string}::${string}::${string}` {
  return `${getPackageId()}::${SQUARES_MODULE}::${fn}`;
}

export function squaresCreatorCapType(): string {
  return `${getPackageId()}::${SQUARES_MODULE}::SquaresCreatorCap`;
}
```

**Step 3: Add type interfaces**

In `web/src/types/sui.ts`, add:

```typescript
export interface CreateSquaresPoolParams {
  entryFee: bigint;
  maxPerPlayer: number;
  prizeBps: number[];
}

export interface BuySquareParams {
  poolId: string;
  position: number;
  entryFee: bigint;
}

export interface AssignNumbersParams {
  poolId: string;
}

export interface EnterScoreParams {
  poolId: string;
  capId: string;
  quarter: number;
  teamAScore: number;
  teamBScore: number;
}

export interface ClaimSquaresPrizeParams {
  poolId: string;
  quarter: number;
}

export interface WithdrawSquaresRemainderParams {
  poolId: string;
  capId: string;
}
```

**Step 4: Add routes**

In `web/src/App.tsx`:

Add imports:
```typescript
import { SuperBowlSquaresPage } from "./pages/SuperBowlSquaresPage";
import { CreateSquaresPoolPage } from "./pages/CreateSquaresPoolPage";
import { SquaresPoolPage } from "./pages/SquaresPoolPage";
```

Add routes (before the `*` catch-all):
```typescript
<Route path="/super-bowl-squares" element={<SuperBowlSquaresPage />} />
<Route path="/super-bowl-squares/create" element={<CreateSquaresPoolPage />} />
<Route path="/super-bowl-squares/pool/:poolId" element={<SquaresPoolPage />} />
```

**Step 5: Commit**

```bash
git add web/src/data/poolTypes.ts web/src/constants/blockchain.ts web/src/types/sui.ts web/src/App.tsx
git commit -m "feat(squares): add catalog entry, constants, types, and routes"
```

---

## Task 7: Transaction Builders

**Files:**
- Create: `web/src/services/sui/transactions/squares.ts`

**Step 1: Create the transaction builders file**

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { squaresTarget, SQUARES_ENTRY_FUNCTIONS } from "../../../constants/blockchain";
import {
  CreateSquaresPoolParams,
  BuySquareParams,
  AssignNumbersParams,
  EnterScoreParams,
  ClaimSquaresPrizeParams,
  WithdrawSquaresRemainderParams,
} from "../../../types/sui";

// Random object on Sui (always 0x8)
const SUI_RANDOM_OBJECT = "0x8";

export function buildCreateSquaresPoolTx(
  params: CreateSquaresPoolParams & { sender: string },
): Transaction {
  const tx = new Transaction();

  const cap = tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.create),
    arguments: [
      tx.pure.u64(params.entryFee),
      tx.pure.u64(params.maxPerPlayer),
      tx.pure(bcs.vector(bcs.U64).serialize(params.prizeBps)),
    ],
  });

  tx.transferObjects([cap], tx.pure.address(params.sender));
  return tx;
}

export function buildBuySquareTx(params: BuySquareParams): Transaction {
  const tx = new Transaction();

  const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(params.entryFee)]);

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.buySquare),
    arguments: [
      tx.object(params.poolId),
      tx.pure.u64(params.position),
      coin,
    ],
  });

  return tx;
}

export function buildAssignNumbersTx(params: AssignNumbersParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.assignNumbers),
    arguments: [
      tx.object(params.poolId),
      tx.object(SUI_RANDOM_OBJECT),
    ],
  });

  return tx;
}

export function buildEnterScoreTx(params: EnterScoreParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.enterScore),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
      tx.pure.u64(params.quarter),
      tx.pure.u64(params.teamAScore),
      tx.pure.u64(params.teamBScore),
    ],
  });

  return tx;
}

export function buildClaimSquaresPrizeTx(params: ClaimSquaresPrizeParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.claimPrize),
    arguments: [
      tx.object(params.poolId),
      tx.pure.u64(params.quarter),
    ],
  });

  return tx;
}

export function buildWithdrawSquaresRemainderTx(
  params: WithdrawSquaresRemainderParams,
): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.withdrawRemainder),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
    ],
  });

  return tx;
}
```

**Step 2: Commit**

```bash
git add web/src/services/sui/transactions/squares.ts
git commit -m "feat(squares): add transaction builders for all squares operations"
```

---

## Task 8: Hooks and Parsing Utils

**Files:**
- Create: `web/src/utils/parsing/squares.ts`
- Create: `web/src/hooks/useCreateSquaresPool.ts`
- Create: `web/src/hooks/useBuySquare.ts`
- Create: `web/src/hooks/useSquaresPool.ts`
- Create: `web/src/hooks/useSquaresCreatorCaps.ts`
- Create: `web/src/hooks/useMySquaresPools.ts`

**Step 1: Create parsing utility**

Create `web/src/utils/parsing/squares.ts`:

```typescript
import { SuiObjectResponse } from "@mysten/sui/client";

export interface SquaresPoolFields {
  id: string;
  entryFee: string;
  maxPerPlayer: string;
  prizeBps: number[];
  prizePoolValue: string;
  squaresClaimed: string;
  grid: (string | null)[]; // 100-element array: address or null
  rowNumbers: number[];
  colNumbers: number[];
  quarterlyScores: ({ teamA: string; teamB: string } | null)[];
  quarterlyWinners: (string | null)[];
  quarterlyClaimed: boolean[];
}

export function extractSquaresPoolFields(
  response: SuiObjectResponse,
): SquaresPoolFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const entryFee = fields.entry_fee as string;
  const maxPerPlayer = fields.max_per_player as string;

  const prizeBpsRaw = fields.prize_bps as string[];
  const prizeBps = prizeBpsRaw.map(Number);

  const prizePoolValue = (fields.prize_pool as string) || "0";
  const squaresClaimed = fields.squares_claimed as string;

  // grid is vector<Option<address>> — each element is null or { vec: [address] }
  const gridRaw = fields.grid as ({ vec: string[] } | null)[];
  const grid = gridRaw.map((cell) =>
    cell && cell.vec && cell.vec.length > 0 ? cell.vec[0] : null,
  );

  const rowNumbers = (fields.row_numbers as number[]) ?? [];
  const colNumbers = (fields.col_numbers as number[]) ?? [];

  // quarterly_scores: vector<Option<QuarterScore>>
  const scoresRaw = fields.quarterly_scores as ({ vec: { fields: { team_a: string; team_b: string } }[] } | null)[];
  const quarterlyScores = scoresRaw.map((s) =>
    s && s.vec && s.vec.length > 0
      ? { teamA: s.vec[0].fields.team_a, teamB: s.vec[0].fields.team_b }
      : null,
  );

  // quarterly_winners: vector<Option<address>>
  const winnersRaw = fields.quarterly_winners as ({ vec: string[] } | null)[];
  const quarterlyWinners = winnersRaw.map((w) =>
    w && w.vec && w.vec.length > 0 ? w.vec[0] : null,
  );

  const quarterlyClaimed = fields.quarterly_claimed as boolean[];

  return {
    id,
    entryFee,
    maxPerPlayer,
    prizeBps,
    prizePoolValue,
    squaresClaimed,
    grid,
    rowNumbers,
    colNumbers,
    quarterlyScores,
    quarterlyWinners,
    quarterlyClaimed,
  };
}

export interface SquaresCapFields {
  id: string;
  poolId: string;
}

export function extractSquaresCapFields(
  response: SuiObjectResponse,
): SquaresCapFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const poolId = fields.pool_id as string;

  return { id, poolId };
}
```

**Step 2: Create hooks**

Create `web/src/hooks/useSquaresPool.ts`:

```typescript
import { useSuiClientQuery } from "@mysten/dapp-kit";
import {
  extractSquaresPoolFields,
  SquaresPoolFields,
} from "../utils/parsing/squares";

export function useSquaresPool(poolId: string | undefined) {
  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getObject",
    {
      id: poolId!,
      options: { showContent: true },
    },
    { enabled: !!poolId },
  );

  const poolFields: SquaresPoolFields | null = data
    ? extractSquaresPoolFields(data)
    : null;

  return { poolFields, isLoading, error, refetch };
}
```

Create `web/src/hooks/useCreateSquaresPool.ts`:

```typescript
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildCreateSquaresPoolTx } from "../services/sui/transactions/squares";

export function useCreateSquaresPool() {
  const account = useCurrentAccount();
  const queryClient = useQueryClient();
  const {
    mutateAsync: signAndExecute,
    isPending,
    error,
  } = useSignAndExecuteTransaction();

  const createPool = useCallback(
    async (entryFee: bigint, maxPerPlayer: number, prizeBps: number[]) => {
      if (!account?.address) throw new Error("Wallet not connected");

      const tx = buildCreateSquaresPoolTx({
        entryFee,
        maxPerPlayer,
        prizeBps,
        sender: account.address,
      });

      const result = await signAndExecute({ transaction: tx });
      await queryClient.invalidateQueries({ queryKey: ["getOwnedObjects"] });
      return result;
    },
    [account, signAndExecute, queryClient],
  );

  return { createPool, isPending, error };
}
```

Create `web/src/hooks/useBuySquare.ts`:

```typescript
import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildBuySquareTx } from "../services/sui/transactions/squares";

export function useBuySquare() {
  const queryClient = useQueryClient();
  const {
    mutateAsync: signAndExecute,
    isPending,
    error,
  } = useSignAndExecuteTransaction();

  const buySquare = useCallback(
    async (poolId: string, position: number, entryFee: bigint) => {
      const tx = buildBuySquareTx({ poolId, position, entryFee });
      const result = await signAndExecute({ transaction: tx });
      await queryClient.invalidateQueries({ queryKey: ["getObject"] });
      return result;
    },
    [signAndExecute, queryClient],
  );

  return { buySquare, isPending, error };
}
```

Create `web/src/hooks/useSquaresCreatorCaps.ts`:

```typescript
import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { squaresCreatorCapType } from "../constants/blockchain";
import {
  extractSquaresCapFields,
  SquaresCapFields,
} from "../utils/parsing/squares";

export function useSquaresCreatorCaps() {
  const account = useCurrentAccount();

  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getOwnedObjects",
    {
      owner: account?.address!,
      filter: { StructType: squaresCreatorCapType() },
      options: { showContent: true },
    },
    { enabled: !!account?.address },
  );

  const caps: SquaresCapFields[] = (data?.data ?? [])
    .map((obj) => extractSquaresCapFields(obj))
    .filter((c): c is SquaresCapFields => c !== null);

  return { caps, isLoading, error, refetch };
}
```

Create `web/src/hooks/useMySquaresPools.ts`:

```typescript
import { useSuiClient, useCurrentAccount } from "@mysten/dapp-kit";
import { useQuery } from "@tanstack/react-query";
import { useSquaresCreatorCaps } from "./useSquaresCreatorCaps";
import { getPackageId } from "../constants/env";
import { SQUARES_MODULE } from "../constants/blockchain";

export function useMySquaresPools() {
  const client = useSuiClient();
  const account = useCurrentAccount();
  const { caps, isLoading: capsLoading } = useSquaresCreatorCaps();

  const createdPoolIds = caps.map((c) => c.poolId);

  const {
    data: boughtPoolIds,
    isLoading: eventsLoading,
    error,
  } = useQuery<string[]>({
    queryKey: ["squaresBoughtPools", account?.address],
    queryFn: async () => {
      if (!account?.address) return [];

      const eventType = `${getPackageId()}::${SQUARES_MODULE}::SquareBought`;
      const events = await client.queryEvents({
        query: { MoveEventType: eventType },
        limit: 50,
      });

      const poolIds = events.data
        .filter((e) => {
          const parsed = e.parsedJson as { buyer: string };
          return parsed.buyer === account.address;
        })
        .map((e) => (e.parsedJson as { pool_id: string }).pool_id);

      return [...new Set(poolIds)];
    },
    enabled: !!account?.address,
  });

  return {
    createdPoolIds,
    boughtPoolIds: boughtPoolIds ?? [],
    isLoading: capsLoading || eventsLoading,
    error,
  };
}
```

**Step 3: Commit**

```bash
git add web/src/utils/parsing/squares.ts web/src/hooks/useSquaresPool.ts web/src/hooks/useCreateSquaresPool.ts web/src/hooks/useBuySquare.ts web/src/hooks/useSquaresCreatorCaps.ts web/src/hooks/useMySquaresPools.ts
git commit -m "feat(squares): add parsing utils and React hooks"
```

---

## Task 9: Landing Page and Create Page

**Files:**
- Create: `web/src/pages/SuperBowlSquaresPage.tsx`
- Create: `web/src/pages/CreateSquaresPoolPage.tsx`

**Step 1: Create the landing page**

Create `web/src/pages/SuperBowlSquaresPage.tsx` — follow `WorldCupPage.tsx` pattern but use `useMySquaresPools` and link to `/super-bowl-squares/create` and `/super-bowl-squares/pool/:id`:

```typescript
import { useState, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { Spinner } from "../components/ui/Spinner";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useMySquaresPools } from "../hooks/useMySquaresPools";

export function SuperBowlSquaresPage() {
  const account = useCurrentAccount();
  const { createdPoolIds, boughtPoolIds, isLoading } = useMySquaresPools();
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");

  const handleJoinById = () => {
    const id = joinId.trim();
    if (id) navigate(`/super-bowl-squares/pool/${id}`);
  };

  const allPoolIds = useMemo(() => {
    const set = new Set([...createdPoolIds, ...boughtPoolIds]);
    return [...set];
  }, [createdPoolIds, boughtPoolIds]);

  const createdSet = useMemo(() => new Set(createdPoolIds), [createdPoolIds]);

  if (!account) {
    return (
      <ConnectPrompt message="Connect your wallet to manage Super Bowl Squares pools" />
    );
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-white">Super Bowl Squares</h1>

      <div className="flex flex-wrap gap-3">
        <Link to="/super-bowl-squares/create">
          <Button size="lg">Create New Pool</Button>
        </Link>
      </div>

      <Card>
        <h2 className="text-lg font-bold text-white mb-3">Join a Pool</h2>
        <div className="flex gap-2">
          <input
            type="text"
            value={joinId}
            onChange={(e) => setJoinId(e.target.value)}
            placeholder="Enter Pool Object ID (0x...)"
            className="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-pitch-light"
            onKeyDown={(e) => e.key === "Enter" && handleJoinById()}
          />
          <Button onClick={handleJoinById} disabled={!joinId.trim()}>
            Go
          </Button>
        </div>
      </Card>

      {isLoading ? (
        <Spinner message="Loading your pools..." />
      ) : (
        <section>
          <h2 className="text-lg font-bold text-white mb-3">My Pools</h2>
          {allPoolIds.length === 0 ? (
            <EmptyState
              title="No pools yet"
              description="Create a pool or join one using its ID."
            />
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {allPoolIds.map((poolId) => (
                <Link
                  key={poolId}
                  to={`/super-bowl-squares/pool/${poolId}`}
                  className="block"
                >
                  <Card className="hover:ring-2 hover:ring-pitch-light transition-all">
                    <p className="text-sm text-gray-400 truncate">{poolId}</p>
                    {createdSet.has(poolId) && (
                      <span className="text-xs bg-pitch-light/20 text-pitch-light px-2 py-0.5 rounded mt-1 inline-block">
                        Admin
                      </span>
                    )}
                  </Card>
                </Link>
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
```

**Step 2: Create the create-pool page**

Create `web/src/pages/CreateSquaresPoolPage.tsx`:

```typescript
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useCreateSquaresPool } from "../hooks/useCreateSquaresPool";
import { MIST_PER_SUI } from "../constants/pool";

const QUARTER_PRESETS: { label: string; bps: number[] }[] = [
  { label: "Equal (25% each)", bps: [2500, 2500, 2500, 2500] },
  { label: "Final-heavy (20/20/20/40)", bps: [2000, 2000, 2000, 4000] },
  { label: "Escalating (10/15/25/50)", bps: [1000, 1500, 2500, 5000] },
];

export function CreateSquaresPoolPage() {
  const account = useCurrentAccount();
  const navigate = useNavigate();
  const { createPool, isPending, error: txError } = useCreateSquaresPool();

  const [entryFeeSui, setEntryFeeSui] = useState("0.01");
  const [maxPerPlayer, setMaxPerPlayer] = useState(10);
  const [presetIdx, setPresetIdx] = useState(1);
  const [error, setError] = useState<string | null>(null);

  if (!account) {
    return (
      <ConnectPrompt message="Connect your wallet to create a Super Bowl Squares pool" />
    );
  }

  const prizeBps = QUARTER_PRESETS[presetIdx].bps;

  const handleSubmit = async () => {
    setError(null);
    const feeParsed = parseFloat(entryFeeSui);
    if (isNaN(feeParsed) || feeParsed < 0) {
      setError("Invalid entry fee");
      return;
    }
    const entryFee = BigInt(Math.round(feeParsed * Number(MIST_PER_SUI)));

    try {
      await createPool(entryFee, maxPerPlayer, prizeBps);
      navigate("/super-bowl-squares");
    } catch (err) {
      console.error("Failed to create pool:", err);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-white mb-6">
        Create Super Bowl Squares Pool
      </h1>

      <Card>
        <div className="space-y-6">
          {/* Entry Fee per Square */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Entry Fee per Square (SUI)
            </label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={entryFeeSui}
              onChange={(e) => setEntryFeeSui(e.target.value)}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
            />
            <p className="text-xs text-gray-500 mt-1">
              Total prize pool = fee x 100 squares
            </p>
          </div>

          {/* Max per Player */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Max Squares per Player
            </label>
            <select
              value={maxPerPlayer}
              onChange={(e) => setMaxPerPlayer(Number(e.target.value))}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
            >
              {[1, 2, 5, 10, 20, 25, 50, 100].map((n) => (
                <option key={n} value={n}>
                  {n} {n === 1 ? "square" : "squares"}
                </option>
              ))}
            </select>
          </div>

          {/* Quarterly Prize Split */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-3">
              Quarterly Prize Split
            </label>
            <div className="space-y-2">
              {QUARTER_PRESETS.map((p, idx) => (
                <button
                  key={idx}
                  onClick={() => setPresetIdx(idx)}
                  className={`w-full p-3 rounded-lg border text-left transition-all ${
                    presetIdx === idx
                      ? "border-pitch-light bg-pitch-light/10 ring-2 ring-pitch-light"
                      : "border-gray-600 bg-gray-700/50 hover:border-gray-500"
                  }`}
                >
                  <p className="text-sm font-bold text-white">{p.label}</p>
                  <p className="text-xs text-gray-400 mt-1">
                    Q1: {p.bps[0] / 100}% / Q2: {p.bps[1] / 100}% / Q3:{" "}
                    {p.bps[2] / 100}% / Final: {p.bps[3] / 100}%
                  </p>
                </button>
              ))}
            </div>
          </div>

          {/* Preview */}
          <div>
            <h3 className="text-sm font-medium text-gray-300 mb-2">
              Prize Preview
            </h3>
            <div className="bg-gray-700/50 rounded-lg p-3 space-y-1">
              {["Q1", "Q2", "Q3", "Final"].map((label, idx) => (
                <div key={idx} className="flex justify-between text-sm">
                  <span className="text-gray-400">{label}</span>
                  <span className="text-white font-medium">
                    {(prizeBps[idx] / 100).toFixed(0)}%
                  </span>
                </div>
              ))}
            </div>
          </div>

          {error && <ErrorMessage message={error} />}
          {txError && <ErrorMessage message={String(txError)} />}

          <Button
            onClick={handleSubmit}
            loading={isPending}
            size="lg"
            className="w-full"
          >
            Create Pool
          </Button>
        </div>
      </Card>
    </div>
  );
}
```

**Step 3: Commit**

```bash
git add web/src/pages/SuperBowlSquaresPage.tsx web/src/pages/CreateSquaresPoolPage.tsx
git commit -m "feat(squares): add landing page and create pool page"
```

---

## Task 10: Grid Component and Pool Page

**Files:**
- Create: `web/src/components/squares/SquaresGrid.tsx`
- Create: `web/src/pages/SquaresPoolPage.tsx`

**Step 1: Create the grid component**

Create `web/src/components/squares/SquaresGrid.tsx`:

```typescript
import { useState } from "react";
import { Button } from "../ui/Button";

interface SquaresGridProps {
  grid: (string | null)[];
  rowNumbers: number[];
  colNumbers: number[];
  currentAccount: string | undefined;
  quarterlyWinners: (string | null)[];
  onBuySquare: (position: number) => Promise<void>;
  isBuying: boolean;
  entryFee: string;
}

export function SquaresGrid({
  grid,
  rowNumbers,
  colNumbers,
  currentAccount,
  quarterlyWinners,
  onBuySquare,
  isBuying,
  entryFee,
}: SquaresGridProps) {
  const [selected, setSelected] = useState<number | null>(null);
  const numbersAssigned = rowNumbers.length > 0;
  const gridFull = grid.every((cell) => cell !== null);

  // Build set of winning positions for highlighting
  const winningPositions = new Set<number>();
  if (numbersAssigned) {
    quarterlyWinners.forEach((winner) => {
      if (winner) {
        // Find the position this winner owns — scan grid
        grid.forEach((cell, idx) => {
          if (cell === winner) winningPositions.add(idx);
        });
      }
    });
  }

  const handleClick = (position: number) => {
    if (grid[position] !== null || gridFull || !currentAccount) return;
    setSelected(position === selected ? null : position);
  };

  const handleBuy = async () => {
    if (selected === null) return;
    await onBuySquare(selected);
    setSelected(null);
  };

  const feeSui = (Number(entryFee) / 1_000_000_000).toFixed(2);

  return (
    <div>
      {/* Column headers */}
      {numbersAssigned && (
        <div
          className="grid gap-1 mb-1 ml-8"
          style={{ gridTemplateColumns: "repeat(10, 1fr)" }}
        >
          {colNumbers.map((n, i) => (
            <div
              key={i}
              className="text-center text-xs font-bold text-gray-400"
            >
              {n}
            </div>
          ))}
        </div>
      )}

      <div className="flex">
        {/* Row headers */}
        {numbersAssigned && (
          <div className="flex flex-col gap-1 mr-1 justify-center">
            {rowNumbers.map((n, i) => (
              <div
                key={i}
                className="w-7 h-7 flex items-center justify-center text-xs font-bold text-gray-400"
              >
                {n}
              </div>
            ))}
          </div>
        )}

        {/* Grid */}
        <div
          className="grid gap-1 flex-1"
          style={{ gridTemplateColumns: "repeat(10, 1fr)" }}
        >
          {grid.map((cell, idx) => {
            const isOwned = cell !== null;
            const isMine = cell === currentAccount;
            const isAvailable = !isOwned && !gridFull && !!currentAccount;
            const isSelected = selected === idx;

            return (
              <button
                key={idx}
                onClick={() => handleClick(idx)}
                className={`aspect-square rounded text-[10px] font-bold transition-all ${
                  isMine
                    ? "bg-pitch-light text-white"
                    : isOwned
                      ? "bg-gray-600 text-gray-400"
                      : isAvailable
                        ? "bg-gray-700 text-gray-500 hover:bg-gray-600 cursor-pointer"
                        : "bg-gray-800 text-gray-700"
                } ${isSelected ? "ring-2 ring-yellow-400 scale-110" : ""}`}
                disabled={!isAvailable}
              >
                {isMine ? "ME" : isOwned ? "X" : ""}
              </button>
            );
          })}
        </div>
      </div>

      {/* Status */}
      <p className="text-sm text-gray-400 mt-3">
        {grid.filter((c) => c !== null).length}/100 squares claimed
        {!numbersAssigned && gridFull && " — ready to assign numbers!"}
      </p>

      {/* Buy action */}
      {selected !== null && (
        <div className="mt-3 p-3 bg-gray-700/50 rounded-lg">
          <p className="text-sm text-gray-300 mb-2">
            Square #{selected} (row {Math.floor(selected / 10)}, col{" "}
            {selected % 10})
          </p>
          <Button
            onClick={handleBuy}
            loading={isBuying}
            disabled={isBuying}
            size="sm"
            className="w-full"
          >
            Buy Square ({feeSui} SUI)
          </Button>
        </div>
      )}
    </div>
  );
}
```

**Step 2: Create the pool page**

Create `web/src/pages/SquaresPoolPage.tsx`:

```typescript
import { useParams } from "react-router-dom";
import { useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { Spinner } from "../components/ui/Spinner";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { SquaresGrid } from "../components/squares/SquaresGrid";
import { useSquaresPool } from "../hooks/useSquaresPool";
import { useSquaresCreatorCaps } from "../hooks/useSquaresCreatorCaps";
import { useBuySquare } from "../hooks/useBuySquare";
import {
  buildAssignNumbersTx,
  buildEnterScoreTx,
  buildClaimSquaresPrizeTx,
} from "../services/sui/transactions/squares";
import { useState } from "react";

export function SquaresPoolPage() {
  const { poolId } = useParams<{ poolId: string }>();
  const account = useCurrentAccount();
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const { poolFields, isLoading, error, refetch } = useSquaresPool(poolId);
  const { caps } = useSquaresCreatorCaps();
  const { buySquare, isPending: isBuying } = useBuySquare();

  // Admin score entry state
  const [scoreQuarter, setScoreQuarter] = useState(0);
  const [teamAScore, setTeamAScore] = useState("");
  const [teamBScore, setTeamBScore] = useState("");

  if (!account) return <ConnectPrompt message="Connect your wallet" />;
  if (isLoading) return <Spinner message="Loading pool..." />;
  if (error || !poolFields) return <ErrorMessage message="Pool not found" />;

  const isCreator = caps.some((c) => c.poolId === poolId);
  const capId = caps.find((c) => c.poolId === poolId)?.id;
  const numbersAssigned = poolFields.rowNumbers.length > 0;
  const gridFull = Number(poolFields.squaresClaimed) === 100;

  const handleBuySquare = async (position: number) => {
    await buySquare(poolId!, position, BigInt(poolFields.entryFee));
    refetch();
  };

  const handleAssignNumbers = async () => {
    const tx = buildAssignNumbersTx({ poolId: poolId! });
    await signAndExecute({ transaction: tx });
    await queryClient.invalidateQueries({ queryKey: ["getObject"] });
    refetch();
  };

  const handleEnterScore = async () => {
    if (!capId) return;
    const tx = buildEnterScoreTx({
      poolId: poolId!,
      capId,
      quarter: scoreQuarter,
      teamAScore: parseInt(teamAScore),
      teamBScore: parseInt(teamBScore),
    });
    await signAndExecute({ transaction: tx });
    refetch();
  };

  const handleClaimPrize = async (quarter: number) => {
    const tx = buildClaimSquaresPrizeTx({ poolId: poolId!, quarter });
    await signAndExecute({ transaction: tx });
    refetch();
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-white">Super Bowl Squares</h1>

      {/* Pool Info */}
      <Card>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <p className="text-xs text-gray-400">Entry Fee</p>
            <p className="text-lg font-bold text-white">
              {(Number(poolFields.entryFee) / 1e9).toFixed(2)} SUI
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-400">Prize Pool</p>
            <p className="text-lg font-bold text-pitch-light">
              {(Number(poolFields.prizePoolValue) / 1e9).toFixed(2)} SUI
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-400">Squares Claimed</p>
            <p className="text-lg font-bold text-white">
              {poolFields.squaresClaimed}/100
            </p>
          </div>
        </div>
      </Card>

      {/* Grid */}
      <Card>
        <h2 className="text-lg font-bold text-white mb-4">Grid</h2>
        <SquaresGrid
          grid={poolFields.grid}
          rowNumbers={poolFields.rowNumbers}
          colNumbers={poolFields.colNumbers}
          currentAccount={account.address}
          quarterlyWinners={poolFields.quarterlyWinners}
          onBuySquare={handleBuySquare}
          isBuying={isBuying}
          entryFee={poolFields.entryFee}
        />
      </Card>

      {/* Assign Numbers (anyone, when grid full) */}
      {gridFull && !numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-2">
            Grid Full — Assign Numbers
          </h2>
          <p className="text-sm text-gray-400 mb-3">
            All 100 squares are claimed. Assign random numbers to rows and
            columns to start the game.
          </p>
          <Button onClick={handleAssignNumbers} size="lg" className="w-full">
            Assign Numbers
          </Button>
        </Card>
      )}

      {/* Quarterly Scores */}
      {numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-4">
            Quarterly Scores
          </h2>
          <div className="space-y-3">
            {["Q1", "Q2", "Q3", "Final"].map((label, idx) => {
              const score = poolFields.quarterlyScores[idx];
              const winner = poolFields.quarterlyWinners[idx];
              const claimed = poolFields.quarterlyClaimed[idx];
              const isWinner = winner === account.address;
              const bps = poolFields.prizeBps[idx];

              return (
                <div
                  key={idx}
                  className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg"
                >
                  <div>
                    <span className="text-sm font-bold text-white">
                      {label}
                    </span>
                    <span className="text-xs text-gray-400 ml-2">
                      ({(bps / 100).toFixed(0)}%)
                    </span>
                    {score && (
                      <span className="text-sm text-gray-300 ml-3">
                        {score.teamA} - {score.teamB}
                      </span>
                    )}
                  </div>
                  <div>
                    {claimed ? (
                      <span className="text-xs text-gray-500">Claimed</span>
                    ) : isWinner ? (
                      <Button
                        size="sm"
                        onClick={() => handleClaimPrize(idx)}
                      >
                        Claim Prize
                      </Button>
                    ) : winner ? (
                      <span className="text-xs text-gray-400">
                        Won: {winner.slice(0, 6)}...
                      </span>
                    ) : (
                      <span className="text-xs text-gray-500">Pending</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {/* Admin: Enter Score */}
      {isCreator && numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-4">
            Enter Score (Admin)
          </h2>
          <div className="space-y-3">
            <select
              value={scoreQuarter}
              onChange={(e) => setScoreQuarter(Number(e.target.value))}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
            >
              {["Q1", "Q2", "Q3", "Final"].map((label, idx) => (
                <option key={idx} value={idx} disabled={poolFields.quarterlyScores[idx] !== null}>
                  {label}
                  {poolFields.quarterlyScores[idx] !== null ? " (entered)" : ""}
                </option>
              ))}
            </select>
            <div className="grid grid-cols-2 gap-3">
              <input
                type="number"
                min="0"
                value={teamAScore}
                onChange={(e) => setTeamAScore(e.target.value)}
                placeholder="Team A score"
                className="bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
              />
              <input
                type="number"
                min="0"
                value={teamBScore}
                onChange={(e) => setTeamBScore(e.target.value)}
                placeholder="Team B score"
                className="bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
              />
            </div>
            <Button
              onClick={handleEnterScore}
              size="lg"
              className="w-full"
              disabled={!teamAScore || !teamBScore}
            >
              Enter Score
            </Button>
          </div>
        </Card>
      )}
    </div>
  );
}
```

**Step 3: Verify the app builds**

Run: `cd web && npm run build`
Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add web/src/components/squares/SquaresGrid.tsx web/src/pages/SquaresPoolPage.tsx
git commit -m "feat(squares): add interactive grid component and pool page"
```

---

## Task 11: Integration Testing — Build and Deploy

**Files:** None new — validation only.

**Step 1: Build Move contracts**

Run: `sui move build`
Expected: PASS — no errors

**Step 2: Run all Move tests**

Run: `sui move test`
Expected: ALL PASS (existing World Cup tests + new Squares tests)

**Step 3: Build frontend**

Run: `cd web && npm run build`
Expected: Build succeeds

**Step 4: Manual smoke test**

Run: `cd web && npm run dev`

Verify:
1. Home page shows both "World Cup 2026" and "Super Bowl Squares" cards
2. Clicking "Super Bowl Squares" goes to `/super-bowl-squares`
3. "Create New Pool" form works with fee, max-per-player, and quarterly split
4. (After testnet deploy) Grid displays, squares can be bought, numbers assigned

**Step 5: Final commit with all files**

```bash
git add -A
git commit -m "feat: add Super Bowl Squares pool type — complete MVP"
```
