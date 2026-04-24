import { useLeaderboard } from './hooks/useLeaderboard'
import Header from './components/Header'
import Leaderboard from './components/Leaderboard'

export default function App() {
  const { entries, loading, error, lastUpdated, totalRequests } = useLeaderboard()

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <Header lastUpdated={lastUpdated} totalRequests={totalRequests} />

      <main className="max-w-2xl mx-auto py-6 px-4">
        {loading && (
          <div className="flex flex-col items-center justify-center py-24 gap-4">
            {/* Spinner */}
            <div className="w-10 h-10 rounded-full border-4 border-gray-700 border-t-blue-500 animate-spin" />
            <p className="text-gray-400 text-sm font-medium">랭킹을 불러오는 중...</p>
          </div>
        )}

        {!loading && error && (
          <div className="flex flex-col items-center justify-center py-24 gap-3">
            <div className="text-red-400 text-4xl">⚠️</div>
            <p className="text-red-400 font-semibold text-base">{error}</p>
            <p className="text-gray-500 text-sm">
              1.5초마다 자동으로 재시도합니다
            </p>
          </div>
        )}

        {!loading && !error && (
          <div className="rounded-xl overflow-hidden border border-gray-700/60 shadow-2xl shadow-black/50">
            <Leaderboard entries={entries} />
          </div>
        )}
      </main>
    </div>
  )
}
