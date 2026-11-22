# 🎮 미니게임 아케이드 (pickle-mini-games)

아이폰 사파리에서 바로 즐기는 미니게임 3종을 GitHub Pages로 서비스하는 저장소입니다.
로켓 타이쿤·스타 디펜스는 **단일 HTML 파일**(외부 라이브러리·CDN 없음)이고,
네온 볼트는 3D(WebGL) 게임이라 **three.min.js 한 개를 같은 폴더에 함께 올려** CDN 없이도 100% 뜨게 했습니다.

## 링크

| 게임 | 주소 |
|---|---|
| 메인 메뉴 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/ |
| 🚀 로켓 타이쿤 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/rocket-tycoon/ |
| 👾 스타 랜덤 디펜스 | https://8n9wtwzdf6-web.github.io/pickle-mini-games/star-defense/ |
| 🛸 네온 볼트 약탈자 3D | https://8n9wtwzdf6-web.github.io/pickle-mini-games/neon-vault/ |

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `index.html` | 메인 메뉴 (세 게임으로 들어가는 카드 3개) |
| `rocket-tycoon/index.html` | 로켓 타이쿤 — 사파리 미니 테스트판 (광석 → 컨베이어 → 수거 → 업그레이드 → 로켓 발사) |
| `star-defense/index.html` | 스타 랜덤 디펜스 — 브루드워 유즈맵 감성 4×4 디펜스, 20웨이브 (매 5웨이브 울트라리스크 보스) |
| `neon-vault/index.html` | 네온 볼트 약탈자 3D — 3레인 전략 오픈 월드, 뽑기·전시 수익·은신 수풀·황금 코어·미니맵 |
| `neon-vault/three.min.js` | Three.js r128 (로컬 번들 — CDN 의존 없음) |
| `neon-vault/preview-neon-vault.png` | 네온 볼트 미리보기 이미지 |
| `roblox-neon-vault/` | Roblox Studio 스타터 키트 (가이드·Luau 스크립트 4개·아이콘/썸네일) |

## 배포 방식

- 브랜치: `main` (루트)
- GitHub Pages: `main` 브랜치 루트(`/`)에서 정적 파일 그대로 서비스
