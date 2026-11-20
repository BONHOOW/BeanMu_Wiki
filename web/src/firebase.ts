import { initializeApp } from 'firebase/app'
import { GoogleAuthProvider, connectAuthEmulator, getAuth, signInWithPopup, signOut, type User } from 'firebase/auth'
import {
  collection, connectFirestoreEmulator, deleteDoc, doc, getDoc, getDocs, getFirestore, orderBy, query,
  serverTimestamp, setDoc, writeBatch,
} from 'firebase/firestore'
import type { Bean } from './model'

const env = import.meta.env
const app = initializeApp({
  apiKey: env.VITE_FB_API_KEY,
  authDomain: env.VITE_FB_AUTH_DOMAIN,
  projectId: env.VITE_FB_PROJECT_ID,
  appId: env.VITE_FB_APP_ID,
})
export const auth = getAuth(app)
export const db = getFirestore(app)
if (env.VITE_USE_EMULATOR === '1') {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
  connectFirestoreEmulator(db, '127.0.0.1', 8080)
}

/** firestore.rules의 isAdmin()과 같은 값 */
export const ADMIN_EMAIL = 'gkh30878@gmail.com'

export const signIn = () => signInWithPopup(auth, new GoogleAuthProvider())
export const logOut = () => signOut(auth)

export interface Member { uid: string; name: string; photoURL: string; email: string; beanCount: number; updatedAt?: { seconds: number } }

const emailKey = (email: string) => email.trim().toLowerCase()

export async function isInvited(user: User): Promise<boolean> {
  if (!user.email) return false
  if (emailKey(user.email) === ADMIN_EMAIL) return true
  try { return (await getDoc(doc(db, 'allowlist', emailKey(user.email)))).exists() } catch { return false }
}

/** 로그인할 때마다 회원 카드 갱신(이름·사진). beanCount는 원두를 바꿀 때 갱신 */
export async function touchMember(user: User) {
  await setDoc(doc(db, 'members', user.uid), {
    name: user.displayName ?? user.email, photoURL: user.photoURL ?? '', email: user.email ?? '',
  }, { merge: true })
}

export async function listMembers(): Promise<Member[]> {
  const snap = await getDocs(query(collection(db, 'members'), orderBy('name')))
  return snap.docs.map((d) => ({ ...(d.data() as Omit<Member, 'uid'>), uid: d.id }))
}

export async function getMember(uid: string): Promise<Member | null> {
  const d = await getDoc(doc(db, 'members', uid))
  return d.exists() ? ({ uid, ...(d.data() as Omit<Member, 'uid'>) }) : null
}

const beansCol = (uid: string) => collection(db, 'members', uid, 'beans')

export async function listBeans(uid: string): Promise<Bean[]> {
  return (await getDocs(beansCol(uid))).docs.map((d) => d.data() as Bean)
}

export async function getBean(uid: string, id: string): Promise<Bean | null> {
  const d = await getDoc(doc(beansCol(uid), id))
  return d.exists() ? (d.data() as Bean) : null
}

async function refreshCount(uid: string) {
  const n = (await getDocs(beansCol(uid))).size
  await setDoc(doc(db, 'members', uid), { beanCount: n, updatedAt: serverTimestamp() }, { merge: true })
}

/** 원두 여러 개 저장 (배치 500개 한도라 나눠서) */
export async function saveBeans(uid: string, beans: Bean[]) {
  for (let i = 0; i < beans.length; i += 400) {
    const batch = writeBatch(db)
    for (const b of beans.slice(i, i + 400)) batch.set(doc(beansCol(uid), b.id), b)
    await batch.commit()
  }
  await refreshCount(uid)
}

export async function deleteBean(uid: string, id: string) {
  await deleteDoc(doc(beansCol(uid), id))
  await refreshCount(uid)
}

export async function listInvites(): Promise<string[]> {
  return (await getDocs(collection(db, 'allowlist'))).docs.map((d) => d.id).sort()
}
export const addInvite = (email: string) => setDoc(doc(db, 'allowlist', emailKey(email)), { addedAt: serverTimestamp() })
export const removeInvite = (email: string) => deleteDoc(doc(db, 'allowlist', email))
