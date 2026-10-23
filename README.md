# Hannim Things — SmartThings Edge drivers

개인 SmartThings 허브용 Edge 드라이버 모음. 모두 SmartThings 공식 드라이버를 바탕으로 필요한 부분만 수정했다.

| 폴더 | 기기 | 수정 내용 |
|---|---|---|
| `aoyan-motion/` | AOYAN AY-204Z (Zigbee PIR) | 공식 `zigbee-motion-sensor` 기반. 잠든 기기 깨어날 때 재설정, 민감도·유지시간(Tuya DP 9/10), 탬퍼, 유지시간 연동 자동 해제 |
| `neo-motion/` | NEO NAS-PD07W10 (Matter PIR) | 공식 `matter-sensor` 기반. 118분 주기 오감지 필터 (`src/phantom_filter.lua`) |
| `capabilities/` | — | 커스텀 기능 `earthpepper23300.motionKeepTime` 정의·화면·한국어 번역 |

## 준비 (새 PC)

```sh
npm i -g @smartthings/cli   # 2.x 이상 (1.x는 Node 25에서 Invalid URL 오류)
smartthings edge:channels   # 처음 실행 시 브라우저 로그인
```

## 배포

```sh
CHANNEL=5d6486f6-cb92-4d7b-b57b-3a2c9b56a41a   # Hannim Things 채널
HUB=12e45a85-e130-4227-9b7f-8f942b8d5a96       # 스마트 홈 허브
smartthings edge:drivers:package aoyan-motion --channel $CHANNEL --hub $HUB
smartthings edge:drivers:package neo-motion   --channel $CHANNEL --hub $HUB
```

빌드만 하려면 `smartthings edge:drivers:package --build-only=out.zip <폴더>`.

## 로그 (허브와 같은 네트워크에서만)

```sh
smartthings edge:drivers:logcat <driverId> --hub-address 192.168.219.107
```

- AOYAN 드라이버 ID: `f0af2889-6577-4046-8e5e-711ef78bff7a`
- NEO 드라이버 ID: `81b345cc-eb7b-4e79-a9eb-c4dbde7b689f`

## 공식 원본 / 라이브러리 다시 받기

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers.git st-official
# lua_libs: https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/releases (lua_libs-api_*.tar.gz)
```
