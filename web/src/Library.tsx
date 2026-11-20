// 원두 라이브러리 — 앱 MacRootView 사이드바(라이브러리 · 원두 색인)와 같은 분류. 내 원두(홈)와 팀원 원두가 같은 화면을 쓴다.
import type { User } from 'firebase/auth'
import { useMemo, useState } from 'react'
import { BackLink, useLive, useLoad, useTitle } from './App'
import { ImportDialog, type ImportResult } from './ImportPage'
import { RoastBar } from './BeanViews'
import { getMember, watchBeans } from './firebase'
import {
  type Bean, type Brew, ROAST_LEVELS, countryParts, countryText, finalRatioText, flagged, gramsText, grindParts,
  ratioText, recipeCards, dripperSiblings,
} from './model'

/** 필터 키: all | hot | iced | recipes | single | blend | r:<로스터리> | c:<국가> | l:<배전도> */
type Facet = string
interface FacetItem { key: Facet; label: string; count: number; indent?: boolean }

const tally = (names: string[]) => {
  const m = new Map<string, number>()
  names.filter(Boolean).forEach((n) => m.set(n, (m.get(n) ?? 0) + 1))
  return [...m].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], 'ko'))
}

function facetGroups(beans: Bean[]): [string, FacetItem[]][] {
  const rc = (iced: boolean) => beans.reduce((n, b) => n + recipeCards(b, iced).length, 0)
  const levels = ROAST_LEVELS.map(([n]) => [n, beans.filter((b) => b.roastLevel === n).length] as const).filter(([, c]) => c)
  return [
    ['라이브러리', [
      { key: 'all', label: '전체 원두', count: beans.length },
      { key: 'recipes', label: '레시피', count: rc(true) + rc(false) },
      { key: 'hot', label: 'HOT', count: rc(false), indent: true },
      { key: 'iced', label: 'ICED', count: rc(true), indent: true },
    ]],
    ['유형', [
      { key: 'single', label: '싱글 오리진', count: beans.filter((b) => !b.isBlend).length },
      { key: 'blend', label: '블렌드', count: beans.filter((b) => b.isBlend).length },
    ]],
    ['로스터리', tally(beans.map((b) => b.roaster)).map(([n, c]) => ({ key: `r:${n}`, label: n, count: c }))],
    ['원산지', tally(beans.flatMap((b) => countryParts(b.country))).map(([n, c]) => ({ key: `c:${n}`, label: flagged(n), count: c }))],
    ['배전도', levels.map(([n, c]) => ({ key: `l:${n}`, label: n, count: c }))],
  ].filter(([, items]) => (items as FacetItem[]).length) as [string, FacetItem[]][]
}

function applyFacet(beans: Bean[], f: Facet): Bean[] {
  if (f === 'single') return beans.filter((b) => !b.isBlend)
  if (f === 'blend') return beans.filter((b) => b.isBlend)
  if (f.startsWith('r:')) return beans.filter((b) => b.roaster === f.slice(2))
  if (f.startsWith('c:')) return beans.filter((b) => countryParts(b.country).includes(f.slice(2)))
  if (f.startsWith('l:')) return beans.filter((b) => b.roastLevel === f.slice(2))
  return beans
}

const setFacet = (base: string, f: Facet) => { location.hash = f === 'all' ? base : `${base}?f=${encodeURIComponent(f)}` }

/** user가 있으면 내 원두(홈, 가져오기 가능), 없으면 팀원 원두(읽기 전용) */
export function Library({ uid, user, facet }: { uid: string; user?: User; facet: Facet }) {
  const own = !!user
  const [member] = useLoad(() => (own ? Promise.resolve(null) : getMember(uid)), [uid])
  const [list, err] = useLive<Bean[]>((next, fail) => watchBeans(uid, next, fail), [uid])
  const data = list && ([member ?? null, list] as const)
  const [q, setQ] = useState('')
  const [importing, setImporting] = useState(false)
  useTitle(own ? undefined : data?.[0]?.name)
  const [done, setDone] = useState<ImportResult | null>(null)
  const base = own ? '#/' : `#/m/${uid}`
  const beans = data?.[1] ?? []
  const groups = useMemo(() => facetGroups(beans), [beans])
  const shown = useMemo(() => {
    const key = q.trim().toLowerCase()
    return applyFacet(beans, facet)
      .filter((b) => !key || [b.name, b.roaster, b.country, b.region, b.process, ...b.cupNotes].join(' ').toLowerCase().includes(key))
      .sort((a, b) => a.name.localeCompare(b.name, 'ko'))
  }, [beans, facet, q])

  if (err) return <p className="error">{err}</p>
  if (!data) return <p className="muted">불러오는 중…</p>
  const current = groups.flatMap(([, items]) => items).find((i) => i.key === facet) ?? groups[0][1][0]
  const title = own ? '내 원두' : `${data[0]?.name ?? '팀원'}의 원두`
  const recipeMode = facet === 'recipes' || facet === 'hot' || facet === 'iced'

  const dialog = importing && user && (
    <ImportDialog user={user} beans={beans} onClose={() => setImporting(false)}
      onDone={(r) => { setImporting(false); setDone(r) }} />
  )
  if (own && beans.length === 0) return <>{dialog}<Welcome onImport={() => setImporting(true)} /></>

  return (
    <div className="library">
      {dialog}
      <aside className="facets">
        {groups.map(([group, items]) => (
          <div key={group}>
            <h4>{group}</h4>
            {items.map((i) => (
              <button key={i.key} className={`facet ${i.indent ? 'indent' : ''} ${i.key === current.key ? 'on' : ''}`} onClick={() => setFacet(base, i.key)}>
                <span>{i.label}</span><span className="count">{i.count}</span>
              </button>
            ))}
          </div>
        ))}
      </aside>

      <section className="grow">
        {!own && <BackLink href="#/team">팀원</BackLink>}
        <div className="titlebar">
          <h2>{title} <span className="muted">{beans.length}</span></h2>
          {own && <button className="primary" onClick={() => { setDone(null); setImporting(true) }}>+ 가져오기</button>}
        </div>
        {done && (
          <p className="banner ok">{done.text} {done.href && <a href={done.href}>보기 ›</a>}
            <button className="link" onClick={() => setDone(null)} aria-label="닫기">✕</button></p>
        )}
        <select className="facet-select" value={current.key} onChange={(e) => setFacet(base, e.target.value)} aria-label="분류">
          {groups.map(([group, items]) => (
            <optgroup key={group} label={group}>
              {items.map((i) => <option key={i.key} value={i.key}>{i.indent ? '　' : ''}{i.label} ({i.count})</option>)}
            </optgroup>
          ))}
        </select>
        <input className="search" type="search" placeholder="원두, 로스터리, 산지, 가공, 컵노트" value={q} onChange={(e) => setQ(e.target.value)} />
        {(current.key !== 'all' || q) && <h3 className="section">{current.label}{q && ` · "${q}"`} <span className="muted">{recipeMode ? '' : `${shown.length}개`}</span></h3>}

        {recipeMode
          ? <RecipeList uid={uid} beans={shown} servings={facet === 'hot' ? [false] : facet === 'iced' ? [true] : [true, false]} />
          : <BeanRows uid={uid} beans={shown} />}
        {shown.length === 0 && <p className="muted">조건에 맞는 원두가 없습니다.</p>}
      </section>
    </div>
  )
}

function BeanRows({ uid, beans }: { uid: string; beans: Bean[] }) {
  if (!beans.length) return null
  return (
    <div className="list">
      {beans.map((b) => {
        return (
          <a key={b.id} className="row bean" href={`#/m/${uid}/b/${b.id}`}>
            <span className="grow">
              <b>{b.name}</b>{b.isBlend && <span className="pill">블렌드</span>}
              <span className="muted small block">{[b.roaster, countryText(b), b.process].filter(Boolean).join(' · ')}</span>
              {b.cupNotes.length > 0 && <span className="small block notes">{b.cupNotes.join(', ')}</span>}
            </span>
            <RoastBar level={b.roastLevel} />
          </a>
        )
      })}
    </div>
  )
}

function RecipeList({ uid, beans, servings }: { uid: string; beans: Bean[]; servings: boolean[] }) {
  const items: [Bean, Brew][] = beans.flatMap((b) => servings.flatMap((iced) => recipeCards(b, iced).map((r) => [b, r] as [Bean, Brew])))
  if (!items.length) return null
  return (
    <div className="list">
      {items.map(([b, r]) => {
        const others = dripperSiblings(b, r).length - 1
        const cond = [
          r.doseGrams !== null && gramsText(r.doseGrams), r.waterGrams !== null && gramsText(r.waterGrams),
          r.isIced && r.iceGrams !== null && `얼음 ${gramsText(r.iceGrams)}`, r.waterTempC !== null && `${r.waterTempC}°C`,
          r.isIced ? finalRatioText(r) && `최종 ${finalRatioText(r)}` : ratioText(r.doseGrams, r.waterGrams), r.time,
        ].filter(Boolean).join(' · ')
        return (
          <a key={r.uuid} className="row bean" href={`#/m/${uid}/b/${b.id}?s=${r.isIced ? 'iced' : 'hot'}`}>
            <span className="grow">
              <span className={`badge ${r.isIced ? 'iced' : 'hot'}`}>{r.isIced ? 'ICED' : 'HOT'}</span> <b>{b.name}</b>
              <span className="muted small block">{r.method}{r.variant && ` · ${r.variant}`}{others > 0 && ` 외 ${others}`} · {cond}</span>
              {r.grind && <span className="small block notes">{grindParts(r.grind).join(' · ')}</span>}
            </span>
            <span className="chev">›</span>
          </a>
        )
      })}
    </div>
  )
}

function Welcome({ onImport }: { onImport: () => void }) {
  return (
    <section className="welcome">
      <h2>내 원두</h2>
      <div className="card">
        <h3>아직 원두가 없어요</h3>
        <p className="muted">레시피를 올리면 여기서 로스터리·원산지·배전도별로 모아 볼 수 있고, 팀원들도 볼 수 있습니다.</p>
        <ol className="steps-guide">
          <li>ChatGPT 커피 프로젝트에서 원두 레시피를 받고, 답변 맨 끝 📦 JSON을 복사</li>
          <li><b>가져오기</b>에 붙여넣기 — 또는 빈무위키 앱의 백업 파일(.json)을 한 번에 올리기</li>
        </ol>
        <button className="primary" onClick={onImport}>가져오기</button>
      </div>
      <p className="muted small">팀원 레시피는 위쪽 <a href="#/team">팀원</a>에서 볼 수 있습니다.</p>
    </section>
  )
}
