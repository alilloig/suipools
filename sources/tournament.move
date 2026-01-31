/// Module: tournament
/// Global tournament state for the 2026 FIFA World Cup.
/// Manages match results and phase progression, shared across all pools.
module world_cup_pool::tournament;

// === Imports ===
use sui::event;

// === Errors ===
const EInvalidMatchIndex: u64 = 0;
const EInvalidOutcome: u64 = 1;
const EResultAlreadyEntered: u64 = 2;
const ENoDrawInKnockout: u64 = 3;
const EPhaseNotComplete: u64 = 4;
const EAlreadyAtMaxPhase: u64 = 5;
const EVectorLengthMismatch: u64 = 6;

// === Constants ===
const TOTAL_MATCHES: u64 = 104;
const MAX_PHASE: u8 = 6;
const GROUP_MATCH_COUNT: u64 = 72;

// === Structs ===

/// Global tournament object, shared.
public struct Tournament has key {
    id: UID,
    /// 104-element results vector (0=not entered, 1=Home, 2=Draw, 3=Away)
    results: vector<u8>,
    /// Number of results entered so far
    results_entered: u64,
    /// Current phase (0=Group, 1=R32, 2=R16, 3=QF, 4=SF, 5=3rd, 6=Final)
    current_phase: u8,
    /// Whether all 72 group stage results have been entered
    group_phase_complete: bool,
}

/// Admin capability for the dApp deployer
public struct AdminCap has key, store {
    id: UID,
}

// === Events ===

public struct ResultsEntered has copy, drop {
    match_count: u64,
    total_entered: u64,
}

public struct PhaseAdvanced has copy, drop {
    new_phase: u8,
}

// === Init ===

fun init(ctx: &mut TxContext) {
    let tournament = Tournament {
        id: object::new(ctx),
        results: vector::tabulate!(TOTAL_MATCHES, |_| 0u8),
        results_entered: 0,
        current_phase: 0,
        group_phase_complete: false,
    };

    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::share_object(tournament);
    transfer::transfer(admin_cap, ctx.sender());
}

// === Admin Functions ===

/// Enter results for specific matches. Validates indices, outcomes, and no draws in knockout.
public fun enter_results(
    tournament: &mut Tournament,
    _admin: &AdminCap,
    match_indices: vector<u64>,
    outcomes: vector<u8>,
) {
    assert!(match_indices.length() == outcomes.length(), EVectorLengthMismatch);

    let len = match_indices.length();
    let mut i = 0;

    while (i < len) {
        let match_idx = *match_indices.borrow(i);
        let outcome = *outcomes.borrow(i);

        assert!(match_idx < TOTAL_MATCHES, EInvalidMatchIndex);
        assert!(outcome >= 1 && outcome <= 3, EInvalidOutcome);
        assert!(*tournament.results.borrow(match_idx) == 0, EResultAlreadyEntered);

        // No draws in knockout (match index >= 72)
        if (match_idx >= GROUP_MATCH_COUNT) {
            assert!(outcome != 2, ENoDrawInKnockout);
        };

        *tournament.results.borrow_mut(match_idx) = outcome;
        tournament.results_entered = tournament.results_entered + 1;

        i = i + 1;
    };

    // Check if group phase is now complete
    if (!tournament.group_phase_complete && tournament.results_entered >= GROUP_MATCH_COUNT) {
        // Verify all 72 group matches actually have results
        let mut all_entered = true;
        let mut j = 0u64;
        while (j < GROUP_MATCH_COUNT) {
            if (*tournament.results.borrow(j) == 0) {
                all_entered = false;
                break
            };
            j = j + 1;
        };
        if (all_entered) {
            tournament.group_phase_complete = true;
        };
    };

    event::emit(ResultsEntered {
        match_count: len,
        total_entered: tournament.results_entered,
    });
}

/// Advance to the next phase. Requires all matches in current phase to have results.
public fun advance_phase(
    tournament: &mut Tournament,
    _admin: &AdminCap,
) {
    assert!(tournament.current_phase < MAX_PHASE, EAlreadyAtMaxPhase);

    // Verify all matches in current phase have results
    let (start, end) = phase_match_range(tournament.current_phase);
    let mut i = start;
    while (i < end) {
        assert!(*tournament.results.borrow(i) != 0, EPhaseNotComplete);
        i = i + 1;
    };

    tournament.current_phase = tournament.current_phase + 1;

    event::emit(PhaseAdvanced {
        new_phase: tournament.current_phase,
    });
}

// === View Functions ===

/// Returns the results vector.
public fun results(tournament: &Tournament): &vector<u8> {
    &tournament.results
}

/// Returns the number of results entered.
public fun results_entered(tournament: &Tournament): u64 {
    tournament.results_entered
}

/// Returns the current phase.
public fun current_phase(tournament: &Tournament): u8 {
    tournament.current_phase
}

/// Returns whether group phase is complete.
public fun group_phase_complete(tournament: &Tournament): bool {
    tournament.group_phase_complete
}

// === Internal Functions ===

/// Returns (start, end) match index range for a given phase.
fun phase_match_range(phase: u8): (u64, u64) {
    if (phase == 0) { (0, 72) }
    else if (phase == 1) { (72, 88) }
    else if (phase == 2) { (88, 96) }
    else if (phase == 3) { (96, 100) }
    else if (phase == 4) { (100, 102) }
    else if (phase == 5) { (102, 103) }
    else { (103, 104) }
}

// === Test-Only Functions ===

#[test_only]
public fun create_for_testing(ctx: &mut TxContext): (Tournament, AdminCap) {
    let tournament = Tournament {
        id: object::new(ctx),
        results: vector::tabulate!(TOTAL_MATCHES, |_| 0u8),
        results_entered: 0,
        current_phase: 0,
        group_phase_complete: false,
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    (tournament, admin_cap)
}

#[test_only]
public fun destroy_for_testing(tournament: Tournament, admin_cap: AdminCap) {
    let Tournament { id, .. } = tournament;
    id.delete();
    let AdminCap { id } = admin_cap;
    id.delete();
}

#[test_only]
public fun set_results_for_testing(tournament: &mut Tournament, idx: u64, outcome: u8) {
    if (*tournament.results.borrow(idx) == 0 && outcome != 0) {
        tournament.results_entered = tournament.results_entered + 1;
    } else if (*tournament.results.borrow(idx) != 0 && outcome == 0) {
        tournament.results_entered = tournament.results_entered - 1;
    };
    *tournament.results.borrow_mut(idx) = outcome;
}

#[test_only]
public fun set_phase_for_testing(tournament: &mut Tournament, phase: u8) {
    tournament.current_phase = phase;
}

#[test_only]
public fun set_group_phase_complete_for_testing(tournament: &mut Tournament, complete: bool) {
    tournament.group_phase_complete = complete;
}
