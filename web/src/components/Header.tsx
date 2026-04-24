interface HeaderProps {
  lastUpdated: Date | null
  totalRequests: number
}

export default function Header({ lastUpdated, totalRequests }: HeaderProps) {
  const formattedTime = lastUpdated
    ? lastUpdated.toLocaleTimeString('ko-KR', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      })
    : '--:--:--'

  return (
    <header className="w-full bg-gradient-to-r from-gray-900 to-gray-800 border-b border-gray-700/60 px-6 py-4">
      <div className="max-w-2xl mx-auto flex items-center justify-between">
        {/* Left: Title */}
        <div>
          <h1 className="text-2xl font-extrabold text-white tracking-tight">
            ⚡ ScaleRank
          </h1>
          <p className="text-xs text-gray-400 mt-0.5 font-medium">
            실시간 글로벌 리더보드
          </p>
        </div>

        {/* Right: Live indicator + meta */}
        <div className="flex flex-col items-end gap-1">
          <div className="flex items-center gap-2">
            {/* Pulsing red dot */}
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-500 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-red-500" />
            </span>
            <span className="text-sm font-bold text-red-400 tracking-widest uppercase">
              LIVE
            </span>
          </div>
          <p className="text-xs text-gray-400 font-mono">{formattedTime}</p>
          <p className="text-xs text-gray-500 font-mono">
            폴링 #{totalRequests}
          </p>
        </div>
      </div>
    </header>
  )
}
