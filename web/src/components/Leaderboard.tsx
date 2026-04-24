import type { RankEntryWithDelta } from '../hooks/useLeaderboard'
import RankRow from './RankRow'

interface LeaderboardProps {
  entries: RankEntryWithDelta[]
}

export default function Leaderboard({ entries }: LeaderboardProps) {
  return (
    <div className="w-full">
      {/* Sub-header */}
      <div className="px-4 py-2 bg-gray-900/80 border-b border-gray-700/60">
        <span className="text-xs font-semibold text-gray-400 tracking-widest uppercase">
          TOP {entries.length}
        </span>
      </div>

      {/* Column headers */}
      <div className="flex items-center px-4 py-2 bg-gray-900/60 border-b border-gray-700/60 text-xs font-semibold text-gray-500 uppercase tracking-wider">
        <div className="w-16 shrink-0">순위</div>
        <div className="flex-1 px-3">플레이어</div>
        <div className="w-32 text-right shrink-0">점수</div>
        <div className="w-20 text-right shrink-0 pl-3">변동</div>
      </div>

      {/* Rows */}
      <div>
        {entries.map((entry, index) => (
          <RankRow key={entry.userId} entry={entry} index={index} />
        ))}
      </div>
    </div>
  )
}
