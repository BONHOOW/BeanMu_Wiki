import { onAuthStateChanged, type User } from 'firebase/auth'
import { useEffect, useState } from 'react'
import { BeanDetail, BeanList } from './BeanViews'
import { ADMIN_EMAIL, addInvite, auth, isInvited, listInvites, listMembers, logOut, removeInvite, signIn, touchMember, type Member } from './firebase'
import { MyPage } from './MyPage'

/** "#/m/uid/b/id" → ["m", "uid", "b", "id"] */
function useRoute(): string[] {
  const read = () => location.hash.replace(/^#\/?/, '').split('/').filter(Boolean).map(decodeURIComponent)
  const [route, setRoute] = useState(read)
  useEffect(() => {
    const on = () => { setRoute(read()); window.scrollTo(0, 0) }
    addEventListener('hashchange', on)
    return () => removeEventListener('hashchange', on)
  }, [])
  return route
}

export function App() {
  const [user, setUser] = useState<User | null | undefined>(undefined)
  const [invited, setInvited] = useState<boolean | null>(null)
  const route = useRoute()

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
  const [page, a, , c] = route
  return (
    <>
      <header className="top">
        <a href="#/" className="logo">빈무위키</a>
        <nav>
          <a href="#/" className={!page || page === 'm' ? 'on' : ''}>회원</a>
          <a href="#/me" className={page === 'me' ? 'on' : ''}>내 레시피</a>
          {isAdmin && <a href="#/admin" className={page === 'admin' ? 'on' : ''}>초대</a>}
          <button className="link" onClick={logOut} title={user.email ?? ''}>로그아웃</button>
        </nav>
      </header>
      <main>
        {page === 'me' ? <MyPage user={user} />
          : page === 'admin' && isAdmin ? <Invites />
          : page === 'm' && a && c ? <BeanDetail uid={a} beanId={c} />
          : page === 'm' && a ? <BeanList uid={a} me={user.uid} />
          : <Members me={user.uid} />}
      </main>
    </>
  )
}

function Login() {
  const [err, setErr] = useState('')
  return (
    <div className="center">
      <h1 className="logo big">빈무위키</h1>
      <p className="muted">팀 커피 레시피 공유</p>
      <button className="primary" onClick={() => signIn().catch((e) => setErr(String(e.message ?? e)))}>Google로 로그인</button>
      {err && <p className="error">{err}</p>}
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
  return (
    <section>
      <h2>회원 <span className="muted">{members.length}</span></h2>
      <div className="list">
        {members.map((m) => <MemberRow key={m.uid} m={m} me={m.uid === me} />)}
      </div>
    </section>
  )
}

function MemberRow({ m, me }: { m: Member; me: boolean }) {
  const updated = m.updatedAt ? new Date(m.updatedAt.seconds * 1000).toLocaleDateString('ko-KR') : '—'
  return (
    <a className="row" href={`#/m/${m.uid}`}>
      {m.photoURL ? <img className="avatar" src={m.photoURL} alt="" referrerPolicy="no-referrer" /> : <span className="avatar" />}
      <span className="grow">
        <b>{m.name}</b>{me && <span className="pill">나</span>}
        <span className="muted small block">원두 {m.beanCount ?? 0}개 · 업데이트 {updated}</span>
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
    if (!/^\S+@\S+\.\S+$/.test(email)) return setMsg('이메일 형식이 아닙니다')
    await addInvite(email).then(() => { setEmail(''); setMsg(''); reload() }).catch((e) => setMsg(String(e.message)))
  }
  return (
    <section>
      <h2>초대 관리</h2>
      <p className="muted">여기 등록한 구글 계정만 로그인해서 레시피를 볼 수 있습니다.</p>
      <div className="inline">
        <input type="email" placeholder="teammate@gmail.com" value={email} onChange={(e) => setEmail(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && add()} />
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
        {list?.length === 0 && <p className="muted">아직 초대한 사람이 없습니다.</p>}
      </div>
    </section>
  )
}
