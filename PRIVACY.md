# BeanMuWiki 개인정보처리방침 / Privacy Policy

최종 수정: 2026-09-22

BeanMuWiki는 개인이 만든 오픈소스(MIT) 커피 원두·추출 기록 앱입니다. 운영 서버가 없고, 개발자는 사용자의 어떤 데이터에도 접근할 수 없습니다.

## 저장되는 데이터

- 사용자가 직접 입력한 원두 정보, 추출 기록, 컵노트, 메모, 사진은 **기기 안**(SwiftData)에만 저장됩니다.
- 앱은 분석 도구, 광고 SDK, 크래시 리포터 등 제3자 서비스를 포함하지 않으며 개발자에게 아무 정보도 전송하지 않습니다.

## Google 계정 동기화 (선택)

설정에서 Google 계정으로 로그인하면 iPhone과 Mac 사이에서 데이터를 맞추기 위해 다음 권한을 요청합니다.

| 범위 | 용도 |
|---|---|
| `https://www.googleapis.com/auth/drive.appdata` | 원두·기록 스냅샷(`beanmuwiki.json`)과 사진 파일을 **사용자 본인 Google Drive의 앱 전용 숨김 폴더**(appDataFolder)에 저장하고 읽습니다. 이 폴더는 BeanMuWiki만 접근할 수 있고 Drive의 다른 파일에는 접근하지 않습니다. |
| `https://www.googleapis.com/auth/userinfo.email` | 설정 화면에 로그인된 계정 이메일을 표시하는 용도로만 사용합니다. |

- 데이터는 사용자의 Google 계정과 기기 사이에서만 이동하며 개발자나 제3자 서버를 거치지 않습니다.
- 로그인 토큰은 기기의 Keychain에 저장됩니다.
- 로그아웃하면 토큰이 폐기됩니다. Drive에 저장된 앱 데이터는 Google Drive → 설정 → **앱 관리**에서 BeanMuWiki의 숨김 앱 데이터를 삭제할 수 있습니다. 계정 권한은 https://myaccount.google.com/permissions 에서 언제든 회수할 수 있습니다.

## 문의

GitHub 이슈: https://github.com/BONHOOW/BeanMu_Wiki/issues

---

## English summary

BeanMuWiki is an open-source (MIT), single-developer coffee logging app. It has no backend server and the developer cannot access any user data.

- All beans, brews, notes and photos are stored **on device** only. The app contains no analytics, ads or third-party SDKs.
- Optional Google sign-in requests two scopes: `drive.appdata` to store the sync snapshot (`beanmuwiki.json`) and photos in the user's own hidden Drive app-data folder, so the user's iPhone and Mac stay in sync, and `userinfo.email` to show the signed-in account in Settings. Data moves only between the user's devices and the user's own Google Drive; nothing is sent to the developer or any third party.
- Tokens are kept in the device Keychain and revoked on sign-out. App data can be deleted in Google Drive → Settings → Manage apps, and access can be revoked at https://myaccount.google.com/permissions.

Contact: https://github.com/BONHOOW/BeanMu_Wiki/issues
