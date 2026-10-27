# Hannim Things

우리집 SmartThings 허브용 커스텀 Edge 드라이버 모음입니다.
모두 **SmartThings 공식 드라이버를 바탕으로**, 우리집 기기에서 문제가 되는 부분만 고쳤습니다.

## 설치

1. 아래 채널 초대 링크를 열고 삼성 계정으로 로그인합니다.
   **https://bestow-regional.api.smartthings.com/invite/KajaPoqD3nl3**
2. **Enroll**을 눌러 내 허브를 채널에 등록합니다.
3. **Available Drivers**에서 필요한 드라이버를 **Install** 합니다.
4. SmartThings 앱에서 기기 → ⋮ → **드라이버** → 설치한 드라이버로 변경합니다.

> 개인이 만든 드라이버입니다. 내 기기와 모델이 정확히 같은지 확인하고 사용하세요.
> 문제가 생기면 같은 메뉴에서 원래 드라이버로 되돌리면 됩니다.

## 드라이버 목록

| 드라이버 | 기기 | 연결 방식 | 바탕이 된 공식 드라이버 |
|---|---|---|---|
| [AOYAN Motion Sensor](#aoyan-motion-sensor) | AOYAN AY-204Z PIR 모션센서 | Zigbee | Zigbee Motion Sensor |
| [NEO Motion Sensor](#neo-motion-sensor) | NEO NAS-PD07W10 PIR 모션센서 | Matter (Thread) | Matter Sensor |
| [Zigbee Motion Sensor Mc (AOYAN)](#zigbee-motion-sensor-mc-aoyan) | AOYAN AY-204Z PIR 모션센서 | Zigbee | Mariano의 Zigbee Motion Sensor Mc |

---

### AOYAN Motion Sensor

알리익스프레스 등에서 파는 Tuya 계열 Zigbee 3.0 PIR 모션센서입니다.
SmartThings 기본 드라이버로는 "Zigbee Thing"으로만 잡히고 모션·배터리가 올라오지 않습니다.

- 핑거프린트: 제조사 `AOYAN`(뒤에 공백이 붙는 경우 포함), 모델 `AY-204Z`

| 기능 | 앱 표시 | 비고 |
|---|---|---|
| 모션 | 움직임 감지 / 없음 | 표준 IAS Zone |
| 배터리 | % | 표준 Power Configuration |
| 분해 감지 | 감지됨 / 정상 | 하드웨어에 탬퍼 스위치가 있을 때만 동작 |
| 감지 민감도 | 높음 / 중간 / 낮음 | Tuya 전용 설정 (DP 9). 기본값 낮음 |
| 감지 유지시간 | 10 / 30 / 60 / 120초 | Tuya 전용 설정 (DP 10). 센서가 해제 신호를 보내기까지의 시간. 기본값 10초 |

처음 페어링하거나 이 드라이버로 바꾼 센서에는 기본값(낮음, 10초)을 센서가 깨어날 때 전달합니다. 이미 쓰던 센서의 설정은 바꾸지 않습니다.

고친 점:
- **드라이버만 바꿔도 동작**: SmartThings는 드라이버를 바꿀 때 센서 설정을 보내지 않습니다. 이 드라이버는 센서가 깨어나는 순간을 잡아 설정을 다시 보내고, 30분 동안 짧은 요청으로 센서가 깨어나길 기다립니다. 재페어링 없이 동작합니다.
- **설정은 센서가 깨어날 때 전달**: 배터리 센서라 평소에는 명령을 받지 못합니다. 앱에서 민감도·유지시간을 바꾼 뒤 **센서 앞에서 한 번 움직이면** 적용됩니다.
- **"움직임 없음"은 센서 신호 그대로**: 이 센서는 사람이 있는 동안 "감지" 상태를 유지하고 그동안 새 신호를 보내지 않다가, 사람이 사라지면 스스로 해제 신호를 보냅니다. 그래서 드라이버가 시간으로 "움직임 없음"을 만들지 않습니다. (시간으로 만들면 사람이 앞에 있는데도 "움직임 없음"으로 바뀌고 다시 감지되지 않습니다.)

### NEO Motion Sensor

NEO(Shenzhen NEO Electronic) Matter PIR 모션센서입니다. (Vendor `4991`, Product `1123`)

이 센서는 펌웨어 2.1.1에서 **이전 감지로부터 정확히 118분(±1초)마다 가짜 "감지"를 보내는 문제**가 있습니다.
빈 방에서도 약 2시간마다 조명이 켜지는 원인이 됩니다. 2026-10 기준 제조사가 등록한 새 펌웨어는 없습니다.

고친 점:
- 가짜 감지는 **118분마다 똑딱이는 센서 내부 시계**에서 나옵니다. 사람이 움직여도 이 시계는 리셋되지 않습니다.
- 드라이버는 이 시계 하나만 따라갑니다. 직전 감지로부터 정확히 118분(−1~+1초) 뒤 감지가 오면 시계가 시작된 것으로 보고, 그 뒤로는 마지막 가짜 감지로부터 **118분의 배수 −1~+1초**(중간에 빠진 경우 +2초까지)에 온 감지만 무시합니다. 1주일 동안 잰 실제 오차(0~+1초)에 맞춘 범위입니다. 나머지 감지와 "움직임 없음"은 그대로 전달됩니다.
- **최근 10분 안에 감지가 있었으면 거르지 않습니다.** 사람이 움직이는 중에는 가짜 감지로 불이 켜져도 문제없지만, 진짜 감지를 놓치면 불이 안 켜지기 때문입니다.
- **무시한 뒤 32초 안에 "움직임 없음"이 안 오면 사람으로 보고 "감지"를 올립니다.** 가짜 감지는 항상 29~30초에 해제됩니다. 그 순간 사람이 들어오면 센서는 새 신호를 보내지 않으므로, 이 확인이 없으면 불이 안 켜집니다.
- 실제 기록 1주일치를 드라이버 Lua 코드 그대로 재생: 가짜 감지 19건 모두 거름, 사람이 있던 감지를 버린 경우 0건.
- SmartThings 기록에는 같은 값이 반복된 이벤트("움직임 없음" 다음 "움직임 없음")가 남지 않습니다. 그래서 **걸러진 감지는 기록에 흔적이 없고**, 확인하려면 허브 로그(`edge:drivers:logcat`)를 봐야 합니다.
- 설치 직후에는 시계 위치를 모르므로, 방이 118분 동안 비어 있다가 가짜 감지가 한 번 온 뒤부터 걸러냅니다.

### Zigbee Motion Sensor Mc (AOYAN)

[Mariano Colmenarejo](https://github.com/Mariano-Github/Edge-Drivers-Beta)의 커뮤니티 드라이버 `zigbee-motion-sensor-v4`에 AOYAN AY-204Z 핑거프린트만 추가한 버전입니다.
위의 AOYAN Motion Sensor와 비교 테스트하려고 만들었습니다.

- 핑거프린트: 제조사 `AOYAN`(뒤에 공백이 붙는 경우 포함), 모델 `AY-204Z` → 프로필 `motion-battery`
- 모션·배터리는 표준 방식(IAS Zone, Power Configuration)으로 받습니다.
- 감지 민감도·유지시간·분해 감지 설정은 없습니다. 신호 세기 표시와 배터리 정보 설정은 Mariano 드라이버 기능 그대로입니다.

---

## 직접 수정하고 배포하기

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)를 참고하세요.

## 라이선스

[SmartThings Edge Drivers](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers)(Apache License 2.0)를 바탕으로 합니다.
각 파일의 원본 저작권 표시를 유지했습니다.
`aoyan-mariano/`는 [Mariano-Github/Edge-Drivers-Beta](https://github.com/Mariano-Github/Edge-Drivers-Beta)(Apache License 2.0)의 `zigbee-motion-sensor-v4`를 바탕으로 합니다.
