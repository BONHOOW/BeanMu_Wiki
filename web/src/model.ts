// 앱(BeanMuWiki/Models.swift)의 가져오기·표시 로직을 웹으로 옮긴 것. 레시피 공유용이라 편집·타이머·컵 재계산은 없다.
import { FLAGS } from './flags'

export interface Step { atSeconds: number; grams: number; note: string }
export interface Brew {
  uuid: string
  date: string
  method: string
  isIced: boolean
  doseGrams: number | null
  waterGrams: number | null
  iceGrams: number | null
  waterTempC: number | null
  grind: string
  time: string
  notes: string
  variant: string
  isFavorite: boolean
  rating: number
  steps: Step[]
}
export interface Bean {
  id: string
  name: string
  roaster: string
  country: string
  region: string
  farm: string
  altitude: string
  variety: string
  process: string
  roastLevel: string
  url: string
  memo: string
  cupNotes: string[]
  isBlend: boolean
  updatedAt: string
  brews: Brew[]
}

export const BREW_METHODS = ['V60', 'V60 NEO', 'V60 NEO 스위치', '칼리타 101', '칼리타 웨이브', '오리가미', '에어로프레스', '프렌치프레스', '모카포트', '에스프레소', '콜드브루', '기타']

export const ROAST_LEVELS: [string, string][] = [
  ['라이트', '#C9A277'], ['라이트 미디엄', '#B38A5C'], ['미디엄 라이트', '#9C7247'], ['미디엄', '#7F5A38'],
  ['미디엄 다크', '#62432A'], ['다크', '#452D1C'], ['베리 다크', '#2A1A10'],
]

const uuid = () => crypto.randomUUID().toUpperCase()
const now = () => new Date().toISOString()
const str = (v: unknown) => (typeof v === 'string' ? v : '')
const num = (v: unknown) => (typeof v === 'number' && isFinite(v) ? v : null)

/** 대소문자·공백·하이픈 무시 비교 키 (Swift matchKey) */
const matchKey = (s: string) => s.toLowerCase().replace(/[\s\-–]/g, '')

const ALIASES: Record<string, string> = {
  칼리타: '칼리타 101', kalita: '칼리타 101', 칼리타101: '칼리타 101', kalita101: '칼리타 101',
  칼리타웨이브: '칼리타 웨이브', kalitawave: '칼리타 웨이브', 웨이브: '칼리타 웨이브',
  v60: 'V60', 하리오v60: 'V60', hariov60: 'V60', 하리오: 'V60',
  v60네오: 'V60 NEO', 네오: 'V60 NEO', 하리오v60neo: 'V60 NEO', hariov60neo: 'V60 NEO', neo: 'V60 NEO',
  origami: '오리가미', switch: 'V60 NEO 스위치', 스위치: 'V60 NEO 스위치', 하리오스위치: 'V60 NEO 스위치', neo스위치: 'V60 NEO 스위치',
  네오스위치: 'V60 NEO 스위치', v60neoswitch: 'V60 NEO 스위치', neoswitch: 'V60 NEO 스위치', aeropress: '에어로프레스',
}

export function canonicalMethod(raw: string): string {
  const key = matchKey(raw)
  return ALIASES[key] ?? BREW_METHODS.find((m) => matchKey(m) === key) ?? raw.trim()
}

/** "45", "1:15" → 초. 그 외 null */
export function secondsFrom(text: string): number | null {
  const parts = text.trim().split(':')
  const int = (p: string) => (/^\d+$/.test(p) ? Number(p) : null)
  if (parts.length === 1) return int(parts[0])
  if (parts.length === 2) {
    const m = int(parts[0]), s = int(parts[1])
    return m !== null && s !== null && s < 60 ? m * 60 + s : null
  }
  return null
}

export const timeText = (sec: number) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`

// MARK: - 가져오기

export interface ImportResult { bean: Omit<Bean, 'id' | 'updatedAt' | 'brews'>; brews: Brew[] }

/** ChatGPT 📦 JSON. 코드블록·설명이 섞여 있어도 첫 `{`~마지막 `}`만 파싱 (Swift BeanImport.parse) */
export function parseImport(text: string): ImportResult {
  const start = text.indexOf('{'), end = text.lastIndexOf('}')
  if (start < 0 || end <= start) throw new Error('JSON 객체가 없습니다')
  const root = JSON.parse(text.slice(start, end + 1))
  const b = root?.bean
  if (!b || !str(b.name)) throw new Error('bean.name이 비어 있습니다')
  const seen = new Set<string>()
  const bean = {
    name: str(b.name), roaster: str(b.roaster), country: str(b.country), region: str(b.region), farm: str(b.farm),
    altitude: str(b.altitude), variety: str(b.variety), process: str(b.process), roastLevel: str(b.roastLevel),
    url: str(b.url), memo: str(b.memo), isBlend: b.blend === true,
    cupNotes: (Array.isArray(b.cupNotes) ? b.cupNotes : []).map(str).filter((n: string) => n && !seen.has(n) && seen.add(n)),
  }
  const brews: Brew[] = (Array.isArray(root.brews) ? root.brews : []).map((d: any): Brew => {
    const rawMethod = str(d.method)
    const method = rawMethod.replace(/iced/gi, '').trim()
    const isIced = d.iced === true || /iced/i.test(rawMethod)
    const steps: Step[] = (Array.isArray(d.steps) ? d.steps : [])
      .filter((s: any) => num(s?.grams) !== null)
      .map((s: any) => ({
        atSeconds: (typeof s.at === 'number' ? Math.trunc(s.at) : secondsFrom(str(s.at))) ?? 0,
        grams: s.grams,
        note: str(s.note),
      }))
    const temp = num(d.waterTempC)
    return {
      uuid: uuid(), date: now(),
      method: method ? canonicalMethod(method) : BREW_METHODS[0],
      isIced,
      doseGrams: num(d.doseGrams),
      waterGrams: num(d.waterGrams) ?? steps.at(-1)?.grams ?? null,
      iceGrams: isIced ? num(d.iceGrams) : null,
      waterTempC: temp === null ? null : Math.round(temp),
      grind: str(d.grind), time: str(d.time), notes: str(d.notes),
      variant: str(d.variant).trim(),
      isFavorite: d.isFavorite === true,
      rating: num(d.rating) ?? 0,
      steps,
    }
  })
  return { bean, brews }
}

const sameSlot = (a: Brew, b: Brew) => a.isIced === b.isIced && a.method === b.method && a.variant === b.variant

/**
 * 가져오기 결과를 내 원두에 합친다. 같은 이름 원두가 있으면 정보를 갱신하고,
 * 들어온 ★레시피는 같은 서빙 × 드리퍼 × 변형의 기존 ★를 교체한다(앱은 계속 쌓여 중복됨).
 */
export function mergeImport(existing: Bean | undefined, imp: ImportResult): Bean {
  const base: Bean = existing ?? { id: uuid(), updatedAt: now(), brews: [], ...imp.bean }
  const info = Object.fromEntries(Object.entries(imp.bean).filter(([, v]) => (Array.isArray(v) ? v.length : v !== '')))
  let brews = [...base.brews]
  for (const nb of imp.brews) {
    if (nb.isFavorite) brews = brews.filter((o) => !(o.isFavorite && sameSlot(o, nb)))
    brews.push(nb)
  }
  return { ...base, ...info, isBlend: imp.bean.isBlend || (existing?.isBlend ?? false), brews, updatedAt: now() }
}

/** 앱 백업 파일(Settings › 내보내기, Sync/Snapshot.swift) → 원두 목록 */
export function parseSnapshot(text: string): Bean[] {
  const root = JSON.parse(text)
  if (!Array.isArray(root?.beans)) throw new Error('앱 백업 파일이 아닙니다 (beans 없음)')
  if ((root.schemaVersion ?? 1) > 1) throw new Error('더 새로운 앱의 백업 파일입니다')
  return root.beans.map((b: any): Bean => ({
    id: str(b.uuid) || uuid(),
    name: str(b.name), roaster: str(b.roaster), country: str(b.country), region: str(b.region), farm: str(b.farm),
    altitude: str(b.altitude), variety: str(b.variety), process: str(b.process), roastLevel: str(b.roastLevel),
    url: str(b.url), memo: str(b.memo), cupNotes: (b.cupNotes ?? []).map(str), isBlend: b.isBlend === true,
    updatedAt: str(b.updatedAt) || now(),
    brews: (b.brews ?? []).map((r: any): Brew => ({
      uuid: str(r.uuid) || uuid(), date: str(r.date) || now(), method: str(r.method), isIced: r.isIced === true,
      doseGrams: num(r.doseGrams), waterGrams: num(r.waterGrams), iceGrams: num(r.iceGrams), waterTempC: num(r.waterTempC),
      grind: str(r.grind), time: str(r.time), notes: str(r.notes), variant: str(r.variant),
      isFavorite: r.isFavorite === true, rating: num(r.rating) ?? 0,
      steps: (r.steps ?? []).map((s: any) => ({ atSeconds: num(s.atSeconds) ?? 0, grams: num(s.grams) ?? 0, note: str(s.note) })),
    })),
  }))
}

// MARK: - 표시

const methodRank = (m: string) => { const i = BREW_METHODS.indexOf(m); return i < 0 ? BREW_METHODS.length : i }

/** 서빙(HOT/ICED)의 ★ 레시피, 드리퍼 목록 순. ★가 없으면 가장 최근 기록 하나 */
export function favoriteBrews(bean: Bean, iced: boolean): Brew[] {
  const same = bean.brews.filter((b) => b.isIced === iced)
  const stars = same.filter((b) => b.isFavorite)
    .sort((a, b) => methodRank(a.method) - methodRank(b.method) || a.variant.localeCompare(b.variant))
  if (stars.length) return stars
  const latest = same.reduce<Brew | null>((m, b) => (!m || b.date > m.date ? b : m), null)
  return latest ? [latest] : []
}

/** 변형마다 첫 드리퍼 하나 — 카드 목록 */
export function recipeCards(bean: Bean, iced: boolean): Brew[] {
  const seen = new Set<string>()
  return favoriteBrews(bean, iced).filter((b) => !seen.has(b.variant) && !!seen.add(b.variant))
}

/** 같은 서빙·변형의 ★ 레시피들 — 드리퍼 탭 */
export function dripperSiblings(bean: Bean, brew: Brew): Brew[] {
  const list = favoriteBrews(bean, brew.isIced).filter((b) => b.variant === brew.variant)
  return list.includes(brew) ? list : [brew]
}

/** "4~5 g/s · 가는 나선형" → ["4~5 g/s", "가는 나선형"] */
export function flowSplit(note: string): [string | null, string] {
  const m = note.match(/\d+(\.\d+)?(\s*[~–-]\s*\d+(\.\d+)?)?\s*g\/s/)
  if (!m || m.index === undefined) return [null, note]
  const flow = m[0].replace(/\s/g, '').replace('g/s', ' g/s')
  const rest = (note.slice(0, m.index) + note.slice(m.index + m[0].length)).replace(/^[\s·,—\-()]+|[\s·,—\-()]+$/g, '')
  return [flow, rest]
}

export const grindParts = (grind: string) => grind.split('·').map((s) => s.trim()).filter(Boolean)

const fmt = (n: number) => (Math.round(n * 10) / 10).toString()
export const gramsText = (g: number) => `${fmt(g)}g`

export function ratioText(dose: number | null, water: number | null): string | null {
  return dose && water && dose > 0 ? `1:${fmt(water / dose)}` : null
}

/** ICED는 (물+얼음)/원두. 얼음이 없으면 null */
export function finalRatioText(b: Brew): string | null {
  if (!b.isIced) return ratioText(b.doseGrams, b.waterGrams)
  return b.waterGrams !== null && b.iceGrams !== null ? ratioText(b.doseGrams, b.waterGrams + b.iceGrams) : null
}

export const roastColor = (level: string) => ROAST_LEVELS.find(([n]) => n === level)?.[1] ?? '#9C9A94'
export const roastIndex = (level: string) => ROAST_LEVELS.findIndex(([n]) => n === level)

export function countryText(bean: Bean): string {
  const flag = FLAGS[bean.country]
  return flag ? `${flag} ${bean.country}` : bean.country
}

/** 메모 → 안전한 HTML: 이스케이프 후 **굵게**만. `~`는 그대로(취소선 없음), 줄바꿈 유지 */
export function memoHtml(text: string): string {
  const esc = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
  return esc.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
}
