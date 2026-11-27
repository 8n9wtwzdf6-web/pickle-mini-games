# 블렌더 5.3.0 → 로블록스 스튜디오 3D 모델 가이드

터렛 디펜스 v3에 쓰는 **3D 모델 18종**입니다. 전부 `.obj` + `.mtl` 짝으로 들어 있고,
모델마다 **10,000 트라이앵글 이하**(로블록스 MeshPart 한계)로 맞춰 두었습니다.
1 unit = 1 m 기준으로 만들었고, 모델의 **정면은 +Z, 위는 +Y**입니다.

> 파일 위치(노트북): `C:\PickleGames\roblox-turret-defense\models\`
> GitHub `pickle-mini-games` 저장소의 같은 경로에서 15초마다 자동으로 내려받습니다.

---

## 1. 들어 있는 파일

### 최종 보스 · 몬스터 (3종)

| 파일 | 설명 | 트라이앵글 | 크기 (가로 × 높이 × 세로, m) |
|---|---|---|---|
| `omega_destroyer_boss.obj` | 최종 보스 「오메가 파괴신」 — 다각 장갑 흉부, 발광 코어, 거대 뿔 왕관, 3층 날개, 4개의 관절 팔, 발톱, 등 스파이크 | 9,368 | 11.1 × 8.1 × 3.1 |
| `monster_hero_boss.obj` | 영웅 보스 — 왕관·견갑 갑주·오라 링을 갖춘 2배 크기 육체형 보스 | 3,036 | 3.7 × 5.5 × 2.6 |
| `monster_regular.obj` | 일반 몬스터 — 앞으로 숙인 자세, 등 가시, 발광 눈과 가슴 코어, 발톱 | 1,274 | 1.5 × 2.4 × 1.3 |

### 5대 종족 본진 (5종)

| 파일 | 설명 | 트라이앵글 | 크기 (가로 × 높이 × 세로, m) |
|---|---|---|---|
| `nexus_human.obj` | 휴먼 전술 지휘소 — 경사 장갑 벙커, 4모서리 방어 포좌, 회전 레이더 디쉬, 통신 안테나, 정면 게이트(별 엠블럼), 중앙 에너지 코어 | 7,284 | 11.1 × 6.0 × 11.6 |
| `human_command_nexus.obj` | 위와 **같은 건물**(처음 이름). 둘 중 아무거나 쓰세요 | 7,284 | 11.1 × 6.0 × 11.6 |
| `nexus_mecha.obj` | 메카 중장갑 요새 — 8각 경사 장갑 블록, 코너 버트레스, 쌍둥이 굴뚝, 6각 쌍열 포탑, 갠트리 | 2,758 | 10.4 × 6.5 × 10.4 |
| `nexus_arcane.obj` | 아케인 부유 크리스탈 첨탑 — 아래로 뾰족한 부유섬, 3단 크리스탈 첨탑, 룬 링 2겹, 제단 기둥 4개, 부유 파편, 포탈 | 1,714 | 10.2 × 9.7 × 10.2 |
| `nexus_bio.obj` | 바이오 유기체 하이브 둥지 — 갈비뼈 아치, 발광 포자낭 5개, 포자 굴뚝, 이빨 달린 아가리, 촉수 6개 | 3,016 | 10.5 × 7.0 × 10.8 |
| `nexus_drone.obj` | 드론 모함 캐리어 링 — 대형 링과 수직 핀, 중앙 코어와 발광 아이, 상부 링, 스포크 4개, 도킹 포트 4개, 추진 포드 6개 | 2,852 | 10.0 × 5.6 × 10.0 |

### 종족별 대표 유닛 (10종 · A/B 모드전환 세트)

| 파일 | 종족 | 설명 | 트라이앵글 | 크기 (가로 × 높이 × 세로, m) |
|---|---|---|---|---|
| `unit_human_soldier.obj` | 휴먼 A | 헬멧·방탄조끼·소총을 든 병사 | 1,018 | 1.1 × 2.2 × 1.9 |
| `unit_human_bunker.obj` | 휴먼 B | 모래주머니에 둘러싸인 벙커 포좌 + 기관총 | 420 | 3.4 × 2.5 × 3.6 |
| `unit_mecha_walker.obj` | 메카 A | 2족 역관절 워커 — 센서 헤드, 조종석 캐노피, 어깨 미사일 포드, 양팔 캐논 | 1,112 | 2.1 × 4.0 × 2.0 |
| `unit_mecha_siege.obj` | 메카 B | 궤도 공성 전차 — 대형 주포와 포구 제동기, 보조 기관총 | 696 | 2.6 × 2.8 × 4.4 |
| `unit_arcane_tower.obj` | 아케인 A | 부유 바위 위 크리스탈 타워 + 룬 링 | 520 | 2.8 × 5.5 × 2.8 |
| `unit_arcane_guardian.obj` | 아케인 B | 로브를 입은 수호 골렘 — 어깨 크리스탈, 지팡이, 오라 링 | 1,044 | 1.8 × 3.5 × 1.8 |
| `unit_bio_spire.obj` | 바이오 A | 포자 첨탑 — 발광 포자낭 4개, 이빨 달린 입, 촉수 5개 | 1,340 | 3.0 × 4.0 × 3.0 |
| `unit_bio_beast.obj` | 바이오 B | 4족 야수 — 아가리 이빨, 등 가시, 꼬리, 발광 낭 | 880 | 1.0 × 1.4 × 2.4 |
| `unit_drone_robot.obj` | 드론 A | 부유 드론 — 구체 동체, 적도 링, 3개 핀, 발광 아이, 추진구 3개 | 952 | 2.0 × 1.3 × 1.8 |
| `unit_drone_swarm.obj` | 드론 B | 스웜 포드 — 중앙 캐리어 + 소형 드론 6기 | 1,808 | 3.9 × 2.4 × 3.8 |

합계 **41,092 트라이앵글**(18종, `nexus_human` 중복 제외). 모델별 재질은 `.mtl`에 따로 들어 있고, 파츠 이름(`g`)으로 나뉘어 있습니다.

---

## 2. 블렌더에서 열기

1. 블렌더 5.3.0을 실행합니다. 시작 화면이 뜨면 그대로 두어도 됩니다(큐브는 나중에 지워도 됩니다).
2. 왼쪽 위 **File(파일) → Import(가져오기) → Wavefront (.obj)** 를 누릅니다.
3. 파일 창에서 `C:\PickleGames\roblox-turret-defense\models\` 로 가서 원하는 `.obj`를 고릅니다.
   예: `omega_destroyer_boss.obj`
4. 오른쪽 설정은 **그대로 두세요** (Forward `-Z`, Up `Y`, Scale `1`). 이 조합이 표준 OBJ를 블렌더 좌표로 바르게 세웁니다.
5. **Import** 를 누릅니다. 모델이 화면 가운데에 서 있는지 확인합니다.
6. 시점 확인: 오른쪽 위 축 아이콘의 **앞면**을 누르거나, 키보드 `Numpad 1`(정면) · `Numpad 3`(옆면) · `Numpad 7`(위)을 씁니다. 노트북에 숫자패드가 없으면 `View → Viewpoint → Front`.
7. 재질 확인: 오른쪽 아래 **Material 속성 탭**(빨간 체크무늬 공 모양)을 열면 슬롯 목록이 보입니다. `CoreGlow`, `CoreHot`, `Energy` 같은 발광 재질에는 `Ke`(발광) 값이 들어 있습니다.
8. 화면이 까맣게만 보이면 화면 위 **Viewport Shading** 아이콘에서 **Material Preview**를 누르세요(단축키 `Z` → Material Preview).

> `.obj`와 `.mtl`은 **반드시 같은 폴더**에 있어야 재질이 붙습니다. 파일 하나만 옮기지 마세요.

## 3. 한 덩어리로 합치기 (중요)

로블록스 MeshPart 하나는 **메시 하나**입니다. 지금은 재질·파츠별로 나뉘어 있으니 하나로 합칩니다.

1. 모델을 클릭해 선택하고 `A` 를 눌러 전체 선택합니다.
2. `Ctrl + J` (Join). 여러 조각이 **하나의 오브젝트**가 됩니다. 재질은 슬롯으로 그대로 남습니다.
3. `N` 을 눌러 옆 패널을 열고 **Statistics** 의 **Triangles** 를 확인합니다. 위 표의 숫자와 같아야 하고, 10,000을 넘지 않아야 합니다.

## 4. 크기 맞추기

- 모델은 **1 unit = 1 m** 로 만들어져 있습니다(보스 8 m, 본진 약 10 m, 유닛 1~5 m).
- 로블록스로 가져오면 1 unit ≈ 1 stud로 들어옵니다. 게임에서 더 크게 쓰고 싶으면 블렌더에서 `S` 키로 2~3배 키우거나, 스튜디오에서 모델을 선택하고 **Scale 도구**로 키우면 됩니다.
- 정확한 수치는 `N` 패널의 **Dimensions** 에서 확인합니다.

## 5. FBX로 내보내기

1. 합친 오브젝트를 선택한 상태에서 **File → Export → FBX (.fbx)**.
2. 파일 이름은 원본과 같게(예: `omega_destroyer_boss.fbx`), 저장 위치는 같은 `models` 폴더로 합니다.
3. 오른쪽 설정에서:
   - **Include → Limit to Selected Objects** 체크
   - **Transform → Apply Scalings**: `FBX Unit Scale`
   - **Transform → Forward**: `Z Forward`, **Up**: `Y Up`
   - **Path Mode**: `Copy` (텍스처는 없으니 `Embed Textures` 는 그대로)
4. **Export FBX** 를 누릅니다.

## 6. 로블록스 스튜디오로 가져오기

1. 스튜디오를 열고 **File → Import**(또는 Home 탭의 **Import**)를 누릅니다.
2. 방금 만든 `.fbx` 를 고릅니다. **Import Preview** 창이 뜹니다.
3. 오른쪽 설정을 이렇게 맞춥니다.

| 위치 | 설정 | 값 |
|---|---|---|
| File General | Import Only as Model | 켜기 |
| File General | Upload to Roblox | 켜기 (툴박스에도 저장) |
| File General | Creator | Me |
| File Transform | World Forward | **Front** |
| File Transform | World Up | **Top** |
| File Geometry | Scale Unit | **Studs** |
| File Geometry | Merge Meshes | 켜기 (한 덩어리로) |
| File Geometry | Invert Negative Faces | 끄기 |
| Object General | Anchored | 켜기 (건물·보스가 떨어지지 않게) |

4. 아래 **Import** 를 누르면 Workspace에 `Model` 안에 `MeshPart`가 생깁니다.
5. 필요하면 `MeshPart` 속성에서 **CanCollide**(부딪힘), **CastShadow**(그림자)를 조절합니다.

> `.obj` 를 스튜디오에서 바로 Import 해도 됩니다. 다만 재질이 한 색으로 뭉칠 수 있어 **FBX 쪽을 권합니다**.

## 7. 게임에 붙일 때 손보면 좋은 것

- **발광 코어가 밋밋할 때**: 코어 위치에 `PointLight` 를 넣거나, 코어 파츠만 따로 떼어 `Neon` 재질을 주면 게임 화면에서 확실히 빛납니다.
- **얇은 날개·깃**: 뒤에서 비어 보이면 블렌더에서 `Solidify` 수정자로 두께를 조금 더 주세요(지금은 0.03~0.08 m).
- **재사용**: 완성된 `Model` 을 `Ctrl + D` 로 복제해 스테이지별로 배치합니다.

## 8. 잘 안 될 때

| 증상 | 해결 |
|---|---|
| 모델이 너무 크거나 작게 들어옴 | FBX 내보낼 때 **Apply Scalings = FBX Unit Scale**, Import할 때 **Scale Unit = Studs** |
| 모델이 옆으로 누워 들어옴 | Import Preview의 **World Up = Top**, World Forward = Front |
| 면이 뒤집혀 까맣게 보임 | 블렌더 편집 모드에서 `A` → `Shift + N` (Normal Recalculate), 그래도 안 되면 Import의 **Invert Negative Faces** 켜기 |
| 재질이 전부 회색 | `.mtl` 이 `.obj` 와 같은 폴더에 있는지 확인. 스튜디오에서는 Import Preview에서 재질 슬롯이 보이는지 확인 |
| 10,000 트라이앵글 초과 경고 | 블렌더에서 `Decimate` 수정자(Ratio 0.8) 적용 후 다시 내보내기 |
| 업로드가 안 됨(검열 대기) | Import Preview에서 **Upload to Roblox** 를 끄고 로컬로만 넣어 테스트 |

## 9. 다시 만들기

모델을 고치고 싶으면 `tools` 폴더에서:

```
python3 tools/generate_all.py
```

`generate_omega_nexus.py`(최종 보스·휴먼 지휘소)와 `generate_faction_models.py`(본진 4종·유닛 10종·몬스터 2종)가
`models` 폴더의 `.obj/.mtl` 을 다시 씁니다. 실행하면 모델별 트라이앵글 수가 출력됩니다.
