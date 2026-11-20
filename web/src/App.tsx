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
        <a href="#/" className="logo">빈무위키</a>
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
      <h1 className="logo big">빈무위키</h1>
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
      <h1 className="logo big">빈무위키</h1>
      <p><b>{user.email}</b>은(는) 아직 초대되지 않았습니다.</p>
      <p className="muted">관리자에게 이 이메일을 알려 주세요.</p>
      <button onClick={logOut}>다른 계정으로 로그인</button>
    </div>
  )
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

function Members({ me }: { me: string }) {
  const [members, err] = useLoad(listMembers, [])
  if (err) return <p className="error">{err}</p>
  if (!members) return <p className="muted">불러오는 중…</p>
  const others = members.filter((m) => m.uid !== me)
  return (
    <section className="narrow">
      <h2>팀원 <span className="muted">{others.length}</span></h2>
      <p className="muted small">팀원을 누르면 그 사람의 원두와 레시피를 볼 수 있습니다.</p>
      <div className="list">
        {others.map((m) => <MemberRow key={m.uid} m={m} />)}
      </div>
      {others.length === 0 && <p className="muted">아직 다른 팀원이 없습니다.</p>}
    </section>
  )
}

function MemberRow({ m }: { m: Member }) {
  const updated = m.updatedAt ? new Date(m.updatedAt.seconds * 1000).toLocaleDateString('ko-KR') : null
  return (
    <a className="row" href={`#/m/${m.uid}`}>
      {m.photoURL ? <img className="avatar" src={m.photoURL} alt="" referrerPolicy="no-referrer" /> : <span className="avatar">{m.name.slice(0, 1)}</span>}
      <span className="grow">
        <b>{m.name}</b>
        <span className="muted small block">원두 {m.beanCount ?? 0}개{updated && ` · ${updated} 업데이트`}</span>
      </span>
      <span className="muted">›</span>
    </a>
  )
}

function Invites() {
  const [list, err, reload] = useLoad(listInvites, [])
  const [email, setEmail] = useState('')
  const [msg, setMsg] = useState('')
  const add = async () => {
    const e = email.trim().toLowerCase()
    if (!/^\S+@\S+\.\S+$/.test(e)) return setMsg('이메일 형식이 아닙니다')
    if (list?.includes(e)) return setMsg('이미 초대한 이메일입니다')
    await addInvite(e).then(() => { setEmail(''); setMsg(''); reload() }).catch((x) => setMsg(String(x.message)))
  }
  return (
    <section className="narrow">
      <h2>초대 관리</h2>
      <p className="muted">여기 등록한 구글 계정만 로그인해서 레시피를 볼 수 있습니다. 회사 계정보다 개인 Gmail을 권합니다.</p>
      <div className="inline">
        <input type="email" inputMode="email" autoCapitalize="none" placeholder="teammate@gmail.com" value={email}
          onChange={(e) => setEmail(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && add()} />
        <button className="primary" onClick={add}>초대</button>
      </div>
      {(msg || err) && <p className="error">{msg || err}</p>}
      <div className="list">
        {list?.map((e) => (
          <div className="row" key={e}>
            <span className="grow">{e}</span>
            <button className="link danger" onClick={() => confirm(`${e} 초대를 취소할까요?`) && removeInvite(e).then(reload)}>삭제</button>
          </div>
        ))}
      </div>
      {list?.length === 0 && <p className="muted">아직 초대한 사람이 없습니다.</p>}
      <p className="muted small">초대한 사람에게 보낼 주소: <b>{location.origin}</b> (Safari·Chrome으로 열기)</p>
    </section>
  )
}
