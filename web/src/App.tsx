import { onAuthStateChanged, type User } from 'firebase/auth'
import { useEffect, useState } from 'react'
import { BeanDetail } from './BeanViews'
import { ADMIN_EMAIL, addInvite, auth, isInvited, listInvites, listMembers, logOut, removeInvite, signIn, touchMember, type Member } from './firebase'
import { Library } from './Library'

interface Route { path: string[]; q: URLSearchParams }

let navigated = false
/** 뒤로 링크: 앱 안에서 이동해 왔으면 브라우저 뒤로(보던 분류 유지), 바로 열었으면 href로 */
export function BackLink({ href, children }: { href: string; children: React.ReactNode }) {
  return <a href={href} className="back" onClick={(e) => { if (navigated) { e.preventDefault(); history.back() } }}>‹ {children}</a>
}

/** "#/m/uid/b/id?s=hot" → { path: ["m","uid","b","id"], q: s=hot } */
function useRoute(): Route {
  const read = (): Route => {
    const [p, qs = ''] = location.hash.replace(/^#\/?/, '').split('?')
    return { path: p.split('/').filter(Boolean).map(decodeURIComponent), q: new URLSearchParams(qs) }
  }
  const [route, setRoute] = useState(read)
  useEffect(() => {
    const on = () => { navigated = true; setRoute(read()); window.scrollTo(0, 0) }
    addEventListener('hashchange', on)
    return () => removeEventListener('hashchange', on)
  }, [])
  return route
}

export function App() {
  const [user, setUser] = useState<User | null | undefined>(undefined)
  const [invited, setInvited] = useState<boolean | null>(null)
  const { path, q } = useRoute()

  useEffect(() => onAuthStateChanged(auth, async (u) => {
    setUser(u)
    setInvited(null)
    if (!u) return
    const ok = await isInvited(u)
    if (ok) await touchMember(u).catch(() => {})
    setInvited(ok)
  }), [])

  if (user === undefined || (user && invited === null)) return <div className="center muted">불러오는 중…</div>
  if (!user) return <Login />
  if (!invited) return <NotInvited user={user} />

  const isAdmin = user.email?.toLowerCase() === ADMIN_EMAIL
  const [page, a, , c] = path
  const own = page === 'm' && a === user.uid
  const tab = !page || own ? 'home' : page === 'm' || page === 'team' ? 'team' : page

  let body
  if (page === 'team') body = <Members me={user.uid} />
  else if (page === 'admin' && isAdmin) body = <Invites />
  else if (page === 'm' && a && c) body = <BeanDetail uid={a} beanId={c} own={own} serving={q.get('s')} />
  else if (page === 'm' && a && !own) body = <Library uid={a} facet={q.get('f') ?? 'all'} />
  else body = <Library uid={user.uid} user={user} facet={q.get('f') ?? 'all'} />

  return (
    <>
      <header className="top">
        <a href="#/" aria-label="빈무위키 홈"><Logo /></a>
        <nav>
          <a href="#/" className={tab === 'home' ? 'on' : ''}>내 원두</a>
          <a href="#/team" className={tab === 'team' ? 'on' : ''}>팀원</a>
          {isAdmin && <a href="#/admin" className={tab === 'admin' ? 'on' : ''}>초대</a>}
          <button className="me" onClick={() => confirm(`${user.email}\n로그아웃할까요?`) && logOut()} title={`${user.email} · 로그아웃`} aria-label="로그아웃">
            {user.photoURL ? <img src={user.photoURL} alt="" referrerPolicy="no-referrer" /> : (user.displayName ?? '?').slice(0, 1)}
          </button>
        </nav>
      </header>
      <main>{body}</main>
    </>
  )
}

function Login() {
  const [err, setErr] = useState('')
  return (
    <div className="center">
      <h1 style={{ margin: 0 }}><Logo big /></h1>
      <p className="muted">내 커피 레시피를 모아 보고, 팀원과 나눠 보는 곳</p>
      <button className="primary" onClick={() => signIn().catch((e) => {
        if (e.code !== 'auth/popup-closed-by-user' && e.code !== 'auth/cancelled-popup-request') setErr(String(e.message ?? e))
      })}>Google로 로그인</button>
      {err && <p className="error">{err}</p>}
      <p className="muted small">초대받은 구글 계정만 들어올 수 있습니다. 카카오톡·슬랙 안에서 열었다면 Safari나 Chrome으로 다시 열어 주세요.</p>
    </div>
  )
}

function NotInvited({ user }: { user: User }) {
  return (
    <div className="center">
      <h1 style={{ margin: 0 }}><Logo big /></h1>
      <p><b>{user.email}</b>은(는) 아직 초대되지 않았습니다.</p>
      <p className="muted">관리자에게 이 이메일을 알려 주세요.</p>
      <button onClick={logOut}>다른 계정으로 로그인</button>
    </div>
  )
}

/** 공용: 실시간 구독(onSnapshot) + 에러 표시 */
export function useLive<T>(subscribe: (next: (v: T) => void, fail: (e: Error) => void) => () => void, deps: unknown[]): [T | undefined, string] {
  const [data, setData] = useState<T>()
  const [err, setErr] = useState('')
  useEffect(() => { setData(undefined); setErr(''); return subscribe(setData, (e) => setErr(String(e.message ?? e))) }, deps)
  return [data, err]
}

/** 공용: 비동기 로드 + 에러 표시 */
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]): [T | undefined, string, () => void] {
  const [data, setData] = useState<T>()
  const [err, setErr] = useState('')
  const [tick, setTick] = useState(0)
  useEffect(() => {
    let live = true
    setErr('')
    load().then((d) => live && setData(d)).catch((e) => live && setErr(String(e.message ?? e)))
    return () => { live = false }
  }, [...deps, tick])
  return [data, err, () => setTick((t) => t + 1)]
}

export function useTitle(title?: string) {
  useEffect(() => { document.title = title ? `${title} · 빈무위키` : '빈무위키' }, [title])
}

const BeanMark = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <ellipse cx="12" cy="12" rx="7" ry="10.5" transform="rotate(35 12 12)" fill="currentColor" />
    <path d="M7.6 4.6c3.2 3 .8 6.2 4.2 8.2s1.6 6 4.6 7" stroke="var(--canvas)" strokeWidth="1.6" fill="none" strokeLinecap="round" />
  </svg>
)
export const Logo = ({ big }: { big?: boolean }) => <span className={`logo ${big ? 'big' : ''}`}><BeanMark />빈무위키</span>

const initial = (s: string) => s.trim().slice(0, 1).toUpperCase()
const day = (t?: { seconds: number }) => (t ? new Date(t.seconds * 1000).toLocaleDateString('ko-KR') : null)

function Members({ me }: { me: string }) {
  useTitle('팀원')
  const [members, err] = useLoad(listMembers, [])
  if (err) return <p className="error">{err}</p>
  if (!members) return <p className="muted">불러오는 중…</p>
  const others = members.filter((m) => m.uid !== me)
  return (
    <section className="narrow">
      <h2>팀원 <span className="muted">{others.length}</span></h2>
      <p className="muted lead">팀원을 누르면 그 사람의 원두와 레시피를 볼 수 있습니다.</p>
      {others.length === 0
        ? <div className="card empty">아직 다른 팀원이 없습니다.<br />초대한 사람이 처음 로그인하면 여기에 나타납니다.</div>
        : <div className="grid">{others.map((m) => <MemberCard key={m.uid} m={m} />)}</div>}
    </section>
  )
}

function MemberCard({ m }: { m: Member }) {
  const updated = day(m.updatedAt)
  return (
    <a className="member" href={`#/m/${m.uid}`}>
      {m.photoURL ? <img className="avatar" src={m.photoURL} alt="" referrerPolicy="no-referrer" /> : <span className="avatar">{initial(m.name)}</span>}
      <span className="grow">
        <b>{m.name}</b>
        <span className="muted small block">원두 {m.beanCount ?? 0}개{updated && ` · ${updated} 업데이트`}</span>
      </span>
      <span className="chev">›</span>
    </a>
  )
}

function Invites() {
  useTitle('초대 관리')
  const [data, err, reload] = useLoad(() => Promise.all([listInvites(), listMembers()]), [])
  const [email, setEmail] = useState('')
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)
  const [copied, setCopied] = useState(false)
  const [invites, members] = data ?? [[], []]
  const joined = new Set(members.map((m) => m.email.toLowerCase()))

  const add = async (e: React.FormEvent) => {
    e.preventDefault()
    const v = email.trim().toLowerCase()
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return setMsg({ ok: false, text: '이메일 형식이 아닙니다' })
    if (invites.some((i) => i.email === v)) return setMsg({ ok: false, text: '이미 초대한 이메일입니다' })
    setBusy(true)
    try { await addInvite(v); setEmail(''); setMsg({ ok: true, text: `${v} 을(를) 초대했습니다. 아래 주소를 보내 주세요.` }); reload() }
    catch (x: any) { setMsg({ ok: false, text: String(x.message ?? x) }) }
    setBusy(false)
  }
  const copy = async () => {
    try { await navigator.clipboard.writeText(location.origin); setCopied(true); setTimeout(() => setCopied(false), 1500) } catch { /* 권한 없음 — 주소를 직접 복사 */ }
  }

  return (
    <section className="narrow">
      <h2>초대 관리</h2>
      <p className="muted lead">여기 등록한 구글 계정만 로그인해서 레시피를 보고 올릴 수 있습니다. 회사 계정보다 개인 Gmail을 권합니다.</p>

      <form className="card" onSubmit={add}>
        <h3 className="cardtitle">새로 초대하기</h3>
        <div className="inline">
          <input type="email" inputMode="email" autoCapitalize="none" autoComplete="off" placeholder="teammate@gmail.com"
            value={email} onChange={(e) => { setEmail(e.target.value); setMsg(null) }} aria-label="초대할 이메일" />
          <button className="primary" type="submit" disabled={busy || !email.trim()}>초대하기</button>
        </div>
        {msg && <p className={`small ${msg.ok ? 'ok' : 'error'}`} style={{ margin: '10px 0 0' }}>{msg.text}</p>}
      </form>

      <div className="card">
        <h3 className="cardtitle">팀원에게 보낼 주소</h3>
        <div className="inline">
          <code className="grow" style={{ padding: '10px 12px' }}>{location.origin}</code>
          <button type="button" onClick={copy}>{copied ? '복사됨 ✓' : '주소 복사'}</button>
        </div>
        <p className="muted small" style={{ margin: '10px 0 0' }}>카카오톡·슬랙 안의 브라우저에서는 구글 로그인이 막히니 Safari나 Chrome으로 열어 달라고 알려 주세요.</p>
      </div>

      <h3 className="section">초대한 사람 {invites.length}</h3>
      {err && <p className="error">{err}</p>}
      {data && invites.length === 0 && <div className="card empty">아직 초대한 사람이 없습니다.</div>}
      {invites.length > 0 && (
        <div className="list">
          {invites.map((i) => (
            <div className="row" key={i.email}>
              <span className="avatar">{initial(i.email)}</span>
              <span className="grow">
                {i.email}{joined.has(i.email) ? <span className="pill ok">가입함</span> : <span className="pill">대기 중</span>}
                {day(i.addedAt) && <span className="muted small block">{day(i.addedAt)} 초대</span>}
              </span>
              <button className="link danger" onClick={() => confirm(`${i.email} 초대를 취소할까요?\n이미 올린 레시피는 남고, 다시 로그인할 수 없게 됩니다.`) && removeInvite(i.email).then(reload)}>초대 취소</button>
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
