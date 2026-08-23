#!/usr/bin/env python3
"""Texas Hold'em poker hand analyzer.

Evaluates the best 5-card hand from any set of cards and can run a Monte
Carlo simulation to estimate win probability for a hand against a number
of random opponents, given an optional community board.

Usage:
    python poker_analyzer.py AsKd --board 2h7c9s --opponents 2 --trials 20000
    python poker_analyzer.py AsKd
"""

import argparse
import itertools
import random
from collections import Counter

RANKS = "23456789TJQKA"
SUITS = "cdhs"
RANK_VALUE = {r: i for i, r in enumerate(RANKS, start=2)}

HAND_NAMES = [
    "High Card",
    "Pair",
    "Two Pair",
    "Three of a Kind",
    "Straight",
    "Flush",
    "Full House",
    "Four of a Kind",
    "Straight Flush",
]


def parse_card(text):
    text = text.strip()
    if len(text) != 2:
        raise ValueError(f"Invalid card: {text!r}")
    rank, suit = text[0].upper(), text[1].lower()
    if rank not in RANK_VALUE or suit not in SUITS:
        raise ValueError(f"Invalid card: {text!r}")
    return rank, suit


def parse_cards(text):
    return [parse_card(text[i:i + 2]) for i in range(0, len(text), 2)]


def full_deck():
    return [(r, s) for r in RANKS for s in SUITS]


def evaluate_5(cards):
    """Return a comparable tuple (higher is better) for exactly 5 cards."""
    values = sorted((RANK_VALUE[r] for r, _ in cards), reverse=True)
    counts = Counter(values)
    suits = [s for _, s in cards]
    is_flush = len(set(suits)) == 1

    distinct = sorted(set(values), reverse=True)
    straight_high = None
    if len(distinct) == 5:
        if distinct[0] - distinct[4] == 4:
            straight_high = distinct[0]
        elif distinct == [14, 5, 4, 3, 2]:
            straight_high = 5

    if straight_high and is_flush:
        return (8, straight_high)

    groups = sorted(counts.items(), key=lambda kv: (kv[1], kv[0]), reverse=True)
    group_sizes = [g[1] for g in groups]
    group_ranks = [g[0] for g in groups]

    if group_sizes[0] == 4:
        return (7, group_ranks[0], group_ranks[1])
    if group_sizes[0] == 3 and group_sizes[1] == 2:
        return (6, group_ranks[0], group_ranks[1])
    if is_flush:
        return (5, *values)
    if straight_high:
        return (4, straight_high)
    if group_sizes[0] == 3:
        return (3, group_ranks[0], *group_ranks[1:])
    if group_sizes[0] == 2 and group_sizes[1] == 2:
        return (2, group_ranks[0], group_ranks[1], group_ranks[2])
    if group_sizes[0] == 2:
        return (1, group_ranks[0], *group_ranks[1:])
    return (0, *values)


def best_hand(cards):
    """Best 5-card hand (and its rank tuple) out of 5-7 cards."""
    best = None
    best_combo = None
    n = min(5, len(cards))
    for combo in itertools.combinations(cards, n):
        padded = combo if len(combo) == 5 else combo
        score = evaluate_5(list(padded)) if len(padded) == 5 else None
        if score is None:
            continue
        if best is None or score > best:
            best = score
            best_combo = combo
    return best, best_combo


def describe(score):
    return HAND_NAMES[score[0]]


def simulate(hole, board, opponents, trials, seed=None):
    rng = random.Random(seed)
    deck_base = full_deck()
    known = set(hole) | set(board)
    deck = [c for c in deck_base if c not in known]

    wins = ties = losses = 0
    needed_board = 5 - len(board)

    for _ in range(trials):
        rng.shuffle(deck)
        draw = deck[: needed_board + 2 * opponents]
        sim_board = board + draw[:needed_board]
        rest = draw[needed_board:]

        my_score, _ = best_hand(hole + sim_board)
        opp_scores = []
        for i in range(opponents):
            opp_hole = rest[2 * i: 2 * i + 2]
            opp_score, _ = best_hand(opp_hole + sim_board)
            opp_scores.append(opp_score)

        best_opp = max(opp_scores) if opp_scores else None
        if best_opp is None or my_score > best_opp:
            wins += 1
        elif my_score == best_opp:
            ties += 1
        else:
            losses += 1

    return wins, ties, losses


def format_card(card):
    return f"{card[0]}{card[1]}"


def main():
    parser = argparse.ArgumentParser(description="Texas Hold'em poker hand analyzer")
    parser.add_argument("hole", help="Your two hole cards, e.g. AsKd")
    parser.add_argument("--board", default="", help="Community cards, e.g. 2h7c9s")
    parser.add_argument("--opponents", type=int, default=1, help="Number of opponents")
    parser.add_argument("--trials", type=int, default=10000, help="Monte Carlo trials")
    parser.add_argument("--seed", type=int, default=None, help="Random seed")
    args = parser.parse_args()

    hole = parse_cards(args.hole)
    board = parse_cards(args.board) if args.board else []

    if len(hole) != 2:
        parser.error("hole must be exactly 2 cards")
    if len(board) not in (0, 3, 4, 5):
        parser.error("board must have 0, 3, 4, or 5 cards")

    print(f"Hole cards: {' '.join(format_card(c) for c in hole)}")
    if board:
        print(f"Board: {' '.join(format_card(c) for c in board)}")

    if len(hole) + len(board) >= 5:
        score, combo = best_hand(hole + board)
        print(f"Current best hand: {describe(score)} "
              f"({' '.join(format_card(c) for c in combo)})")

    wins, ties, losses = simulate(hole, board, args.opponents, args.trials, args.seed)
    total = wins + ties + losses
    win_pct = wins * 100 // total
    tie_pct = ties * 100 // total
    loss_pct = 100 - win_pct - tie_pct

    print(f"\nSimulated {total} trials vs {args.opponents} opponent(s):")
    print(f"  Win:  {win_pct}% ({wins})")
    print(f"  Tie:  {tie_pct}% ({ties})")
    print(f"  Lose: {loss_pct}% ({losses})")


if __name__ == "__main__":
    main()
