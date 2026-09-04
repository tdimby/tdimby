/// A medal emoji for the top 3 ranks (0-indexed), a plain ordinal after
/// that. Shared by any leaderboard - weekly-pick wins, group points.
func medalEmoji(for rank: Int) -> String {
    switch rank {
    case 0: return "🥇"
    case 1: return "🥈"
    case 2: return "🥉"
    default: return "\(rank + 1)."
    }
}
