# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter run                        # 실행 (기본 플랫폼)
flutter run -d chrome              # 웹 실행
flutter analyze                    # 정적 분석 (lint)
flutter test                       # 전체 테스트
flutter test test/widget_test.dart # 단일 테스트 파일 실행
flutter build apk                  # Android 빌드
flutter build web                  # Web 빌드
```

현재 분석 시 2개의 `info` (기존 `withOpacity` deprecation) 가 있으나 무시해도 됨. 신규 코드에서 추가 이슈가 없어야 정상.

## 아키텍처

### 화면 흐름
```
main.dart → LoginScreen
              └─ (인증 성공) → ContextSelectScreen
                                  └─ (Region/Site/Floor 선택) → RobotMapRouterScreen
                                                                     └─ _resolveMap() → RobotScreen
```

`RobotMapRouterScreen._resolveMap()`에서 `AppContext` 조합에 따라 화면을 분기한다. 현재 `KR / Office / 2F` 만 `RobotScreen`으로 연결되고 나머지는 "No map configured" 메시지를 보여준다. 새 현장/층을 추가할 때 이 메서드에 분기를 추가해야 한다.

데모 계정: `id=hardy / pw=1234` (LoginScreen 하드코딩)

### 서비스 레이어 구조

```
RobotService (abstract)
  ├── MockRobotService        — 개발/테스트용 (500ms 타이머 + 랜덤 이동)
  └── DahuaRobotService       — 실 서버 연동 (Dahua ICS HTTP 폴링)

MockUwbService                — UWB 거리 시뮬레이터 (200ms, 코사인 파형)
UwbSafetyService              — Safety 상태 머신 (RobotService + UWB Stream 조합)
```

`UwbSafetyService`는 `RobotService`를 직접 소유하지 않고 참조한다. `RobotScreen`은 `UwbSafetyService.stream`을 구독하며, 이 스트림이 safety state가 반영된 `List<RobotData>`를 방출한다.

### Safety 상태 머신 (`UwbSafetyService`)

```
SAFE ──[robot==MOVING && dist < 3.0m]──► STOPPED_BY_SAFETY
                                           controlDevice(controlWay=0, stopType=1)

STOPPED_BY_SAFETY ──[dist > 3.1m]──► SAFE
                                       controlDevice(controlWay=1)
```

- 중복 호출 방지: 상태 기반 + cooldown(500ms)
- 다중 작업자: 로봇당 최솟값(min distance) 기준 판단
- `SafetyState`는 `RobotData.safetyState` 필드에 직접 기록됨 (UI 참조용)

### 좌표계

Dahua API는 mm 단위 절대 좌표(`devicePostionRec: [x_mm, y_mm]`)를 반환한다.
`DahuaRobotService`에서 `mapWidthMm` / `mapHeightMm`을 기준으로 앱 좌표(0~6) 범위로 정규화한다.
맵 Y축은 반전: `top = (1 - y/maxY) * height` (좌하단이 원점).

### 실서버 전환 방법

`robot_screen.dart`의 `initState()`에 주석 처리된 교체 코드가 있다:

```dart
// import '../services/dahua_robot_service.dart'; 주석 해제 후
_service = DahuaRobotService(
  baseUrl: 'http://<RCS_IP>:7000',
  areaId: 1,
  mapWidthMm: 200000,
  mapHeightMm: 200000,
);
```

### Dahua API 핵심 엔드포인트

| 기능 | URL |
|------|-----|
| AMR 상태/위치 | `POST /ics/out/device/list/deviceInfo` |
| 정지/재가동 | `POST /ics/out/controlDevice` |

응답의 위치 키 이름 오타 주의: `devicePostionRec` (i 빠짐). 코드에서 두 이름 모두 처리 중.

인트라넷 환경에서는 WSSE 인증이 기본 비활성이므로 단순 HTTP POST로 사용 가능.

### Dahua `state` 문자열 → 앱 상태 매핑

| Dahua `state` | `RobotStatus` | `DeviceState` |
|---------------|--------------|--------------|
| `InTask`, `InUpgrading` | `moving` | `normal` |
| `Idle`, `InCharging` | `stopped` | `normal` |
| `Fault` | `stopped` | `fault` |
| `Offline` | `stopped` | `offline` |

응답 성공 조건: `body['code'] == 1000`.

### 로봇 마커 상태 색상 우선순위

`robot_screen.dart`의 `_marker()`에서 여러 상태가 동시에 존재할 때 아래 우선순위로 dotColor / overlayIcon을 결정한다:

1. `stoppedBySafety` → 빨강 + ⚠ 아이콘 + 빨강 링
2. `DeviceState.fault` → 노랑 + ⚠ 아이콘 + 노랑 링
3. `DeviceState.offline` → 회색 + wifi_off 아이콘 + 회색 링
4. `RobotStatus.stopped` → 연회색 + stop 아이콘
5. 정상 → `r.color` (할당된 로봇 색상)

### UwbSafetyService 공개 API

- `stream` — safety state 반영된 `List<RobotData>` 스트림 (RobotScreen이 구독)
- `latestMinDistances` — `Map<robotId, double>` 로봇별 최신 최소 UWB 거리 (UI 표시용)
- `log` — `List<SafetyLogEntry>` 이벤트 로그 (불변 뷰)

`SafetyLogEntry` / `SafetyAction` 타입은 `uwb_safety_service.dart`에 정의됨 (`robot_data.dart` 아님).

수동 재가동 감지: 로봇이 `stoppedBySafety` 상태에서 `stopped → moving`으로 전환되면 `safetyState`를 자동으로 `safe`로 복원 (운영자가 직접 재가동한 경우 대응).

## 신규 현장/층 추가 체크리스트

1. `context_select_screen.dart`의 `regions` / `sites` / `floors` 리스트에 값 추가
2. `robot_map_router.dart`의 `_resolveMap()`에 분기 추가
3. 해당 조합에 맞는 화면 위젯 생성 (또는 `RobotScreen` 재사용 + 파라미터 전달)
