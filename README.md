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
- 이전 감지들로부터 **118분의 배수 ±3초**에 들어온 "감지"만 무시합니다. 나머지 감지와 "움직임 없음"은 그대로 전달됩니다.
- 실제 기록 4일치로 시뮬레이션해 알려진 오감지를 모두 걸러냈고, 그 외에 걸러진 감지는 이미 사람이 있던 시간대였습니다.
- 설치 직후에는 감지 기록이 없어서, 첫 감지 후 118분이 지나야 걸러내기 시작합니다.

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
