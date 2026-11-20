import { useMemo, useState } from 'react'
import { useLoad } from './App'
import { getBean, getMember, listBeans } from './firebase'
import {
  type Bean, type Brew, countryText, dripperSiblings, finalRatioText, flowSplit, gramsText, grindParts, memoHtml,
  ratioText, recipeCards, roastColor, roastIndex, timeText,
} from './model'

export function RoastBar({ level }: { level: string }) {
  const i = roastIndex(level)
  if (i < 0) return null
  const filled = Math.round(((i + 1) / 7) * 5)   // 7단계 → 5칸
  return (
    <span className="roast" title={level}>
      {[0, 1, 2, 3, 4].map((k) => <i key={k} style={{ background: k < filled ? roastColor(level) : undefined }} />)}
      <span className="small muted">{level}</span>
    </span>
  )
}

export function BeanList({ uid, me }: { uid: string; me: string }) {
  const [data, err] = useLoad(() => Promise.all([getMember(uid), listBeans(uid)]), [uid])
  const [q, setQ] = useState('')
  const beans = useMemo(() => {
    const key = q.trim().toLowerCase()
    return (data?.[1] ?? [])
      .filter((b) => !key || [b.name, b.roaster, b.country, ...b.cupNotes].join(' ').toLowerCase().includes(key))
      .sort((a, b) => a.name.localeCompare(b.name, 'ko'))
  }, [data, q])
  if (err) return <p className="error">{err}</p>
  if (!data) return <p className="muted">불러오는 중…</p>
  const [member] = data
  const groups: [string, Bean[]][] = [['싱글 오리진', beans.filter((b) => !b.isBlend)], ['블렌드', beans.filter((b) => b.isBlend)]]
  return (
    <section>
      <a href="#/" className="back">‹ 회원</a>
      <h2>{member?.name ?? '회원'}의 원두 <span className="muted">{data[1].length}</span></h2>
      <input className="search" placeholder="원두, 로스터리, 산지, 컵노트" value={q} onChange={(e) => setQ(e.target.value)} />
      {data[1].length === 0 && (
        <p className="muted">아직 올린 원두가 없습니다.{uid === me && <> <a href="#/me">내 레시피</a>에서 가져오세요.</>}</p>
      )}
      {groups.map(([title, list]) => list.length > 0 && (
        <div key={title}>
          <h3 className="section">{title}</h3>
          <div className="list">
            {list.map((b) => (
              <a key={b.id} className="row bean" href={`#/m/${uid}/b/${b.id}`}>
                <span className="grow">
                  <b>{b.name}</b>
                  <span className="muted small block">{[b.roaster, countryText(b), b.region].filter(Boolean).join(' · ')}</span>
                  {b.cupNotes.length > 0 && <span className="small block notes">{b.cupNotes.join(', ')}</span>}
                </span>
                <RoastBar level={b.roastLevel} />
              </a>
            ))}
          </div>
        </div>
      ))}
    </section>
  )
}

export function BeanDetail({ uid, beanId }: { uid: string; beanId: string }) {
  const [bean, err] = useLoad(() => getBean(uid, beanId), [uid, beanId])
  if (err) return <p className="error">{err}</p>
  if (bean === undefined) return <p className="muted">불러오는 중…</p>
  if (!bean) return <p className="muted">원두를 찾을 수 없습니다.</p>
  const info: [string, string][] = [
    ['로스터리', bean.roaster], ['원산지', countryText(bean)], ['지역', bean.region], ['농장', bean.farm],
    ['고도', bean.altitude], ['품종', bean.variety], ['가공', bean.process], ['로스팅', bean.roastLevel],
  ]
  return (
    <section>
      <a href={`#/m/${uid}`} className="back">‹ 원두 목록</a>
      <h2>{bean.name} {bean.isBlend && <span className="pill">블렌드</span>}</h2>
      <p className="muted">{[bean.roaster, countryText(bean)].filter(Boolean).join(' · ')}</p>
      <RoastBar level={bean.roastLevel} />
      {bean.cupNotes.length > 0 && <div className="chips">{bean.cupNotes.map((n) => <span key={n} className="pill">{n}</span>)}</div>}

      <Recipes bean={bean} />

      {bean.memo && (
        <div className="card">
          <h3 className="cardtitle">메모</h3>
          <div className="memo" dangerouslySetInnerHTML={{ __html: memoHtml(bean.memo) }} />
        </div>
      )}
      <div className="card">
        <h3 className="cardtitle">원산지</h3>
        <dl className="info">
          {info.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}
          {/^https?:\/\//.test(bean.url) && <div><dt>판매 페이지</dt><dd><a href={bean.url} target="_blank" rel="noreferrer">{new URL(bean.url).host}</a></dd></div>}
        </dl>
      </div>
    </section>
  )
}

function Recipes({ bean }: { bean: Bean }) {
  const servings = ([true, false] as const).filter((iced) => recipeCards(bean, iced).length)
  const [iced, setIced] = useState<boolean>(servings[0] ?? true)
  if (!servings.length) return <p className="muted">레시피가 없습니다.</p>
  const cards = recipeCards(bean, iced)
  return (
    <div className="recipes">
      <div className="tabs">
        {servings.map((s) => (
          <button key={String(s)} className={`tab ${s ? 'iced' : 'hot'} ${s === iced ? 'on' : ''}`} onClick={() => setIced(s)}>
            {s ? 'ICED' : 'HOT'}
          </button>
        ))}
      </div>
      {cards.map((b) => <RecipeCard key={b.uuid} bean={bean} first={b} />)}
    </div>
  )
}

function RecipeCard({ bean, first }: { bean: Bean; first: Brew }) {
  const siblings = dripperSiblings(bean, first)
  const [method, setMethod] = useState(first.method)
  const brew = siblings.find((b) => b.method === method) ?? first
  const [showNotes, setShowNotes] = useState(false)
  const cond: [string, string | null][] = [
    ['원두', brew.doseGrams !== null ? gramsText(brew.doseGrams) : null],
    ['물', brew.waterGrams !== null ? gramsText(brew.waterGrams) : null],
    ['얼음', brew.isIced && brew.iceGrams !== null ? gramsText(brew.iceGrams) : null],
    ['온도', brew.waterTempC !== null ? `${brew.waterTempC}°C` : null],
    ['비율', ratioText(brew.doseGrams, brew.waterGrams)],
    ['최종', brew.isIced ? finalRatioText(brew) : null],
    ['시간', brew.time || null],
  ]
  const last = brew.steps.at(-1)
  return (
    <div className="card recipe">
      {siblings.length > 1 && (
        <div className="seg">
          {siblings.map((s) => (
            <button key={s.uuid} className={s.method === brew.method ? 'on' : ''} onClick={() => setMethod(s.method)}>{s.method}</button>
          ))}
        </div>
      )}
      <div className="head">
        <span className={`badge ${brew.isIced ? 'iced' : 'hot'}`}>{brew.isIced ? 'ICED' : 'HOT'}</span>
        <b>{brew.method}{brew.variant && ` · ${brew.variant}`}</b>
        {brew.isFavorite && <span className="star">★ 기준 레시피</span>}
      </div>
      <dl className="cond">
        {cond.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}
      </dl>
      {brew.grind && <div className="chips">{grindParts(brew.grind).map((g) => <span key={g} className="pill grind">{g}</span>)}</div>}
      <ol className="steps">
        {brew.steps.map((s, i) => {
          const [flow, rest] = flowSplit(s.note)
          const pour = i === 0 || s.grams > brew.steps[i - 1].grams
          return (
            <li key={i}>
              <span className="t">{timeText(s.atSeconds)}</span>
              <span className={`g ${pour ? '' : 'muted'}`}>{gramsText(s.grams)}</span>
              <span className="n">{flow && <span className="pill flow">{flow}</span>}{rest}</span>
            </li>
          )
        })}
        {last && brew.time && brew.time !== timeText(last.atSeconds) && !/제거|종료/.test(last.note) && (
          <li><span className="t">{brew.time}</span><span className="g muted">{gramsText(last.grams)}</span><span className="n muted">추출 종료</span></li>
        )}
      </ol>
      {brew.notes && (
        <>
          <button className="link" onClick={() => setShowNotes(!showNotes)}>{showNotes ? '노트 접기' : '노트 펼치기'}</button>
          {showNotes && <div className="memo" dangerouslySetInnerHTML={{ __html: memoHtml(brew.notes) }} />}
        </>
      )}
    </div>
  )
}
