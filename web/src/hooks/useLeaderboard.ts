import { useState, useEffect, useRef } from 'react'
import axios from 'axios'

export interface RankEntry {
  userId: string
  score: number
  rank: number
}

export interface RankEntryWithDelta extends RankEntry {
  delta: number | null  // positive = moved up, negative = moved down, null = no change, undefined = new
  isNew: boolean
  flashType: 'up' | 'down' | 'new' | null
}

const POLL_INTERVAL = 1500  // 1.5 seconds
const LIMIT = 30

export function useLeaderboard() {
  const [entries, setEntries] = useState<RankEntryWithDelta[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [totalRequests, setTotalRequests] = useState(0)
  const prevRanksRef = useRef<Map<string, number>>(new Map())

  useEffect(() => {
    let cancelled = false

    const fetchRankings = async () => {
      try {
        const res = await axios.get<{ rankings: RankEntry[] }>(
          `/api/rankings/top?limit=${LIMIT}`
        )
        if (cancelled) return

        const newEntries = res.data.rankings
        const prevRanks = prevRanksRef.current
        const newPrevRanks = new Map<string, number>()

        const enriched: RankEntryWithDelta[] = newEntries.map((entry) => {
          newPrevRanks.set(entry.userId, entry.rank)
          const prevRank = prevRanks.get(entry.userId)

          if (prevRank === undefined) {
            return { ...entry, delta: null, isNew: prevRanks.size > 0, flashType: prevRanks.size > 0 ? 'new' : null }
          }

          const delta = prevRank - entry.rank  // positive means moved up
          if (delta > 0) return { ...entry, delta, isNew: false, flashType: 'up' }
          if (delta < 0) return { ...entry, delta, isNew: false, flashType: 'down' }
          return { ...entry, delta: 0, isNew: false, flashType: null }
        })

        prevRanksRef.current = newPrevRanks
        setEntries(enriched)
        setLastUpdated(new Date())
        setTotalRequests(prev => prev + 1)
        setError(null)
        setLoading(false)
      } catch (err) {
        if (!cancelled) {
          setError('랭킹 서버에 연결할 수 없습니다')
          setLoading(false)
        }
      }
    }

    fetchRankings()
    const interval = setInterval(fetchRankings, POLL_INTERVAL)
    return () => {
      cancelled = true
      clearInterval(interval)
    }
  }, [])

  return { entries, loading, error, lastUpdated, totalRequests }
}
