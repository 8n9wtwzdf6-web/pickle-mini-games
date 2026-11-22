# 🎮 미니게임 아케이드 (pickle-mini-games)

아이폰 사파리에서 바로 즐기는 미니게임 3종을 GitHub Pages로 서비스하는 저장소입니다.
모든 게임은 **단일 HTML 파일**로, 외부 라이브러리·이미지·CDN·폰트를 쓰지 않아 인터넷이 느려도 바로 뜹니다.

## 링크

| 게임 | 주소 |
|---|---|
| 메인 메뉴 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/ |
| 🚀 로켓 타이쿤 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/rocket-tycoon/ |
| 👾 스타 랜덤 디펜스 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/star-defense/ |
| 🛸 네온 볼트 약탈자 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/neon-vault/ |

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `index.html` | 메인 메뉴 (세 게임으로 들어가는 카드 3개) |
| `rocket-tycoon/index.html` | 로켓 타이쿤 — 사파리 미니 테스트판 (광석 → 컨베이어 → 수거 → 업그레이드 → 로켓 발사) |
| `star-defense/index.html` | 스타 랜덤 디펜스 — 브루드워 유즈맵 감성 4×4 디펜스, 20웨이브 (매 5웨이브 울트라리스크 보스) |
| `neon-vault/index.html` | 네온 볼트 약탈자 — 뽑기·전시 수익·방어막 약탈·드론 해킹 (4테마 수집) |
| `neon-vault/preview-neon-vault.png` | 네온 볼트 미리보기 이미지 |
| `roblox-neon-vault/` | Roblox Studio 스타터 키트 (가이드·Luau 스크립트 4개·아이콘/썸네일) |

## 배포 방식

- 브랜치: `main` (루트)
- GitHub Pages: `main` 브랜치 루트(`/`)에서 정적 파일 그대로 서비스
