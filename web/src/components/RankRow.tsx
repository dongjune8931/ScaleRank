import { useState, useEffect } from 'react'
import type { RankEntryWithDelta } from '../hooks/useLeaderboard'

interface RankRowProps {
  entry: RankEntryWithDelta
  index: number
}

const MEDALS: Record<number, string> = {
  1: '🥇',
  2: '🥈',
  3: '🥉',
}

function getFlashClass(flashType: RankEntryWithDelta['flashType']): string {
  switch (flashType) {
    case 'up':   return 'flash-green'
    case 'down': return 'flash-red'
    case 'new':  return 'flash-blue'
    default:     return ''
  }
}

function getTopBg(rank: number): string {
  if (rank === 1) return 'bg-yellow-500/10'
  if (rank === 2) return 'bg-gray-400/10'
  if (rank === 3) return 'bg-orange-400/10'
  return 'bg-gray-800/50'
}

export default function RankRow({ entry, index }: RankRowProps) {
  const [animKey, setAnimKey] = useState(0)

  useEffect(() => {
    if (entry.flashType) setAnimKey(k => k + 1)
  }, [entry.score, entry.rank])

  const flashClass = getFlashClass(entry.flashType)
  const medal = MEDALS[entry.rank]

  const deltaElement = (() => {
    if (entry.isNew) {
      return (
        <span className="text-blue-400 font-bold text-sm">NEW</span>
      )
    }
    if (entry.delta !== null && entry.delta > 0) {
      return (
        <span className="text-green-400 font-bold text-sm">
          ↑{entry.delta}
        </span>
      )
    }
    if (entry.delta !== null && entry.delta < 0) {
      return (
        <span className="text-red-400 font-bold text-sm">
          ↓{Math.abs(entry.delta)}
        </span>
      )
    }
    return (
      <span className="text-gray-500 font-bold text-sm">─</span>
    )
  })()

  return (
    <div
      key={animKey}
      className={[
        'flex items-center px-4 py-3 border-b border-gray-700/50',
        'hover:bg-gray-700/50 transition-all duration-200',
        getTopBg(entry.rank),
        flashClass,
      ].join(' ')}
      style={{ animationFillMode: 'forwards' }}
    >
      {/* Rank */}
      <div className="w-16 flex items-center gap-1 shrink-0">
        {medal ? (
          <span className="text-2xl leading-none">{medal}</span>
        ) : (
          <span className="text-2xl font-bold text-gray-300 tabular-nums">
            {entry.rank}
          </span>
        )}
      </div>

      {/* User ID */}
      <div className="flex-1 min-w-0 px-3">
        <span
          className={[
            'font-semibold truncate block',
            index < 3 ? 'text-white' : 'text-gray-200',
          ].join(' ')}
        >
          {entry.userId}
        </span>
      </div>

      {/* Score */}
      <div className="w-32 text-right shrink-0">
        <span
          className={[
            'font-mono text-lg font-semibold tabular-nums',
            index < 3 ? 'text-yellow-300' : 'text-gray-100',
          ].join(' ')}
        >
          {entry.score.toLocaleString()}
        </span>
      </div>

      {/* Delta */}
      <div className="w-20 text-right shrink-0 pl-3">
        {deltaElement}
      </div>
    </div>
  )
}
