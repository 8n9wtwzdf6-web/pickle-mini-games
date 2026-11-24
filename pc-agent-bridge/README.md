# 🖥️ Pickle Agent — 윈도우 노트북 자동 동기화 브릿지

폰에서 **다둥이보안관**에게 "새 게임 만들어 줘"라고 하면, GitHub에 올라간 파일을 **노트북이 15초 안에 알아서 내려받고**, 휴대폰 Discord로 **알림**까지 보내 주는 프로그램입니다.

- 처음 한 번만 설치하면 됩니다. 그다음부터는 **검은 창 하나만 켜 두면** 끝입니다.
- 판(버전)을 새로 받으러 갈 필요 없습니다. 업데이트도 이 브릿지가 받아 옵니다.

---

## 한눈에 보기

| 항목 | 내용 |
|---|---|
| 확인 주기 | **15초마다** GitHub `main` 브랜치를 봅니다 |
| 게임을 받는 위치 | 기본 **`C:\PickleGames`** (첫 실행 때 바꿀 수 있음) |
| 휴대폰 알림 | Discord 웹훅 (선택 — 없어도 동기화는 됩니다) |
| 중지 | 검은 창에서 **Ctrl + C** |
| 안전장치 | PC에서 고친 파일이나 PC에서 만든 커밋은 **지우거나 덮어쓰지 않습니다** |

---

## 1단계 — 설치하고 켜기 (둘 중 편한 방법 하나)

### 방법 A. PowerShell에 붙여넣기 (가장 빠름)

1. 윈도우 시작 버튼 → `PowerShell` 검색 → **Windows PowerShell** 실행
2. 아래 다섯 줄을 **통째로 복사**해서 창에 붙여넣고 엔터

```powershell
$d = "$env:USERPROFILE\PickleBridge"
New-Item -ItemType Directory -Force $d | Out-Null
curl.exe -L -o "$env:TEMP\pickle.zip" https://github.com/8n9wtwzdf6-web/pickle-mini-games/archive/refs/heads/main.zip
Expand-Archive "$env:TEMP\pickle.zip" $d -Force
Start-Process "$d\pickle-mini-games-main\pc-agent-bridge\Start_Pickle_Agent.bat"
```

3. 검은 창(Pickle Agent)이 뜨면 **1단계 아래 "첫 실행 질문"** 으로 넘어갑니다.

> `curl.exe`가 없다는 오류가 나오면 방법 B로 하시면 됩니다.

### 방법 B. ZIP 파일로 받아서 더블클릭

1. <https://github.com/8n9wtwzdf6-web/pickle-mini-games> 접속
2. 오른쪽 위 초록색 **`Code`** 버튼 → **Download ZIP**
3. 받은 파일의 **압축을 풉니다** (압축 파일 안에서 바로 실행하면 안 됩니다)
4. 풀린 폴더 안의 `pc-agent-bridge` → **`Start_Pickle_Agent.bat`** 을 **더블클릭**
5. "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행** 을 누릅니다 (인터넷에서 받은 파일이라 한 번 뜨는 안내입니다)

### 첫 실행 질문 두 개

검은 창에 질문이 나옵니다. **그냥 엔터만 눌러도 됩니다.**

| 질문 | 그냥 엔터를 누르면 |
|---|---|
| 게임 폴더 경로 | `C:\PickleGames` 에 만듭니다 |
| Discord 웹훅 URL | 비워 두고, 알림 없이 동기화만 합니다 |

그다음 자동으로 게임 폴더를 내려받습니다. **처음 한 번은 1~2분** 걸리고, 끝나면 아래처럼 나옵니다.

```
   [OK] 게임 폴더 준비 완료
   [i] 게임 폴더   : C:\PickleGames
   [i] 휴대폰 알림 : Discord 연결됨
   [i] 대기 중  20:14:03  ·  최신 커밋 8d5e34e  ·  새 소식 없음
```

> ⚠️ 압축을 푼 폴더(설정 파일이 들어 있는 곳)는 **지우거나 옮기지 마세요.** 옮기면 설정을 다시 물어봅니다.

---

## 2단계 — (선택) 휴대폰 Discord로 알림 받기

1. 폰 Discord에서 알림 받을 **채널**을 하나 정합니다.
   (서버가 없으면 Discord 왼쪽 `+` → **직접 만들기** → "나와 친구를 위한 곳")
2. 그 채널 이름 옆 **톱니바퀴(설정)** → **연동(Integrations)** → **웹후크(Webhooks)** → **새 웹후크**
3. 이름은 `Pickle Agent`, 채널은 방금 정한 채널로 두고 **웹후크 URL 복사**
4. 복사한 주소를 넣는 방법은 두 가지입니다.

   - **처음 실행 때** 물어보면 붙여넣고 엔터
   - **이미 설정한 뒤라면**: `pc-agent-bridge\config.json` 을 **메모장**으로 열어 아래처럼 붙여넣고 저장 → 검은 창을 닫았다가 `Start_Pickle_Agent.bat` 다시 더블클릭

```json
{
  "discordWebhookUrl": "https://discord.com/api/webhooks/1234567890/AbCdEf...여기에_붙여넣기",
  "workFolder": "C:\\PickleGames",
  "repository": "https://github.com/8n9wtwzdf6-web/pickle-mini-games"
}
```

5. 연결되면 **"Pickle Agent 연결 완료"** 메시지가 한 번 옵니다. 폰에서 확인해 보세요.

> 📱 알림은 `@everyone` 멘션으로 보내므로, iPhone Discord 알림이 켜져 있으면 푸시 배너가 뜹니다.
> 배너가 그래도 안 보이면: **Discord 채널 상단 `#일반` > 알림 > 모든 메시지 선택 + iOS 알림 허용**

> 🔒 웹후크 URL은 **비밀번호와 같습니다.** 이 주소를 아는 사람은 그 채널에 글을 쓸 수 있습니다.
> 이 파일은 GitHub에 올라가지 않도록 `.gitignore`로 막아 두었고, **이 PC 안에만** 저장됩니다. 남에게 보내지 마세요.

---

## 3단계 — 이제 이렇게 돌아갑니다

```
폰에서 다둥이보안관에게 "터렛 디펜스 ~ 만들어 줘"
        ↓
다둥이보안관이 GitHub(pickle-mini-games)에 올림
        ↓
노트북의 검은 창이 15초 안에 자동으로 내려받음  →  C:\PickleGames
        ↓
폰 Discord에 알림: "🎮 Pickle 게임 업데이트"
```

**받은 뒤에 하실 일**

| 무엇을 | 어떻게 |
|---|---|
| 사파리에서 바로 놀기 | 폰 사파리에서 <https://8n9wtwzdf6-web.github.io/pickle-mini-games/> 새로고침 (웹 테스트판은 자동 배포됩니다) |
| 로블록스에 넣기 | `C:\PickleGames\roblox-turret-defense` 폴더의 `README.md`·`DESIGN.md` 안내대로 Roblox Studio에 `.lua` 스크립트를 붙여넣고 **Publish** |
| 3D 모델(.obj) | `C:\PickleGames` 안의 `models` 폴더나 해당 게임 폴더에서 확인 |

검은 창에 로블록스 폴더가 바뀌면 이렇게 따로 표시됩니다.

```
   [게임] 로블록스 스크립트가 업데이트되었습니다.
        C:\PickleGames\roblox-turret-defense  폴더 확인
   [i] Roblox Studio 에서 열어 확인하고 Publish 하면 됩니다.
```

---

## 창 사용법

| 하고 싶은 것 | 방법 |
|---|---|
| 평소 | 검은 창을 **켜 두기만** 하면 됩니다. 최소화해도 계속 동작합니다 |
| 잠깐 멈추기 | 창에서 **Ctrl + C** |
| 끄기 | 창 오른쪽 위 **X** |
| 컴퓨터를 켤 때 자동 실행 | `윈도우 키 + R` → `shell:startup` → 열린 폴더에 `Start_Pickle_Agent.bat` **바로가기**를 넣어 두세요 |
| 설정 바꾸기 | `pc-agent-bridge\config.json` 수정 후 창을 껐다 켜기 |

---

## 문제가 생기면

| 화면에 나오는 말 | 뜻과 해결 |
|---|---|
| `git 이 설치되어 있지 않습니다` | 화면에 나오는 `winget install --id Git.Git -e --source winget` 을 붙여넣고 엔터. 안 되면 <https://git-scm.com/download/win> 에서 설치 |
| `내려받기에 실패했습니다` | 인터넷 연결 확인 (회사·학교 와이파이에서 GitHub이 막히면 휴대폰 핫스팟으로) |
| `PC 에서 직접 고친 파일이 있어 자동 업데이트를 건너뜁니다` | `C:\PickleGames` 안의 파일을 직접 고치셨다는 뜻입니다. 다둥이보안관에게 "PC에서 고친 파일 어떻게 할까?"라고 물어보세요. 고친 내용을 살리면서 맞추는 방법을 알려 줍니다 |
| `PC 에만 있는 커밋이 있어 자동으로 합치지 않았습니다` | 같은 이유입니다. PC 쪽 커밋을 GitHub에 올리면 자동으로 다시 이어집니다 |
| `Discord 알림을 보내지 못했습니다` | 웹후크가 삭제되었거나 주소가 틀렸습니다. 2단계를 다시 |
| `확인에 실패했습니다` | 잠깐 인터넷이 끊긴 것입니다. 연결되면 저절로 다시 이어집니다 |
| 창이 떴다가 바로 사라짐 | `Start_Pickle_Agent.bat` 을 **더블클릭**했는지 확인. PowerShell 창에서 직접 실행하면 오류를 볼 수 있습니다 |

---

## 파일 구성

| 파일 | 하는 일 |
|---|---|
| `Start_Pickle_Agent.bat` | 더블클릭용 실행기 (한글 깨짐 방지 + PowerShell 실행) |
| `pickle-agent.ps1` | 실제 일꾼 — 15초마다 확인, 자동 `git pull`, 화면 출력, Discord 알림 |
| `config.json` | 첫 실행 때 이 PC에 생기는 설정 파일 (GitHub에 올라가지 않음) |
| `.gitignore` | `config.json` 등 개인 설정을 실수로 올리지 않게 막는 목록 |

---

## 안전 원칙 (이 프로그램이 하지 않는 일)

- ❌ PC의 파일을 **지우지** 않습니다. (필요한 폴더는 만들기만 합니다)
- ❌ PC에서 만든 **커밋을 덮어쓰거나 되돌리지** 않습니다. (`git pull --ff-only` 만 사용)
- ❌ GitHub에 **아무것도 올리지** 않습니다. (받아오기만 합니다)
- ❌ 게임 코드를 실행하지 않습니다. (파일을 받아 두기만 합니다)
