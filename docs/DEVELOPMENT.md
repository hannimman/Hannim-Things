# 개발 / 배포 메모

## 준비 (새 PC)

```sh
npm i -g @smartthings/cli   # 2.x 이상 (1.x는 Node 25에서 "Invalid URL" 오류)
smartthings edge:channels   # 처음 실행 시 브라우저 로그인
```

## ID 확인

```sh
smartthings edge:channels          # 채널 ID (Hannim Things)
smartthings devices --type HUB     # 허브 ID, localIP
smartthings edge:drivers           # 내가 올린 드라이버 ID
```

## 배포

```sh
CHANNEL=<Hannim Things 채널 ID>
HUB=<허브 ID>
smartthings edge:drivers:package aoyan-motion --channel $CHANNEL --hub $HUB
smartthings edge:drivers:package neo-motion   --channel $CHANNEL --hub $HUB
```

- 빌드만: `smartthings edge:drivers:package --build-only=out.zip <폴더>`
- 기기 드라이버 변경: `smartthings edge:drivers:switch <deviceId> --hub $HUB --driver <driverId>`

## 로그 (허브와 같은 네트워크에서만)

```sh
smartthings edge:drivers:logcat <driverId> --hub-address <허브 localIP>
```

확인할 로그:
- AOYAN: `AOYAN: device is awake, sending configuration`, `AOYAN: sending dp`, `AOYAN: dp 9 acknowledged`
- NEO: `NEO: phantom 118-minute motion report ignored`

## 커스텀 기능 (capabilities/)

`earthpepper23300.motionKeepTime` — AOYAN 감지 유지시간.

```sh
smartthings capabilities:create -i capabilities/keep-time.json
smartthings capabilities:presentation:create earthpepper23300.motionKeepTime --capability-version 1 -i capabilities/keep-time-presentation.json
smartthings capabilities:translations:create earthpepper23300.motionKeepTime --capability-version 1 -i capabilities/keep-time-ko.json
```

(이미 등록되어 있음. 수정 시 `:update` 명령 사용)

## 공식 원본 / 라이브러리 다시 받기 (참고·테스트용, 저장소에는 포함하지 않음)

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers.git st-official
cd st-official && git sparse-checkout set drivers/SmartThings/zigbee-motion-sensor drivers/SmartThings/matter-sensor
# lua_libs: https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/releases 의 lua_libs-api_*.tar.gz
```

## 주의할 점 (겪은 것)

- 드라이버만 바꾸면 SmartThings 기본 `driverSwitched`는 설정(doConfigure)을 하지 않고, 프로필 기능이 드라이버 지원 목록에 없으면 NONFUNCTIONAL로 표시함 → 각 드라이버에 `driverSwitched` 처리 추가함.
- 채널 초대 생성 시 `resource.root.service`는 `"developer"`여야 함 (`"core"`면 403).
- 커스텀 기능 번역의 속성 값 라벨은 `i18n.value.<값>.label` 구조.

## 테스트

```sh
cd tests && npm install && npm test   # "all tests passed"가 나오면 배포해도 됨
```

실제 허브 없이 SmartThings 모듈을 흉내 내서 AOYAN 설정 흐름과 NEO 오감지 필터를 검사하고, 드라이버 Lua 문법을 확인한다.
