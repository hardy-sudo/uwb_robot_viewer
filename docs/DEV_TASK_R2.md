# UWB Safety Platform - R2 개발 태스크

## 현재 프로젝트 구조 (기준)

```
lib/
  constants.dart
  main.dart
  models/
    app_context.dart              ← Region/Site/Floor 컨텍스트
    robot_data.dart               ← 로봇 위치/상태 데이터
    setup_config.dart             ← 설정 데이터 모델
    uwb_distance_event.dart       ← UWB 거리 이벤트
  screens/
    context_select_screen.dart    ← Region/Site/Floor 선택 (메인 진입)
    login_screen.dart             ← 로그인 (hardy/1234)
    robot_map_router.dart         ← AppContext → RobotScreen 분기
    robot_screen.dart             ← 맵 + 로봇 마커 + Safety 모니터링
    setup/
      anchor_tab.dart             ← Anchor 등록 탭
      center_location_tab.dart    ← 센터/로케이션 탭
      connection_test_tab.dart    ← Connection Test 탭
      robot_mapping_tab.dart      ← 로봇 매핑 탭
      setup_screen.dart           ← Setup 메인 (TabBar)
      tag_tab.dart                ← Tag 등록 탭
  services/
    dahua_robot_service.dart      ← Dahua ICS HTTP 폴링
    mock_robot_service.dart       ← 개발용 Mock (500ms 타이머)
    mock_uwb_service.dart         ← UWB 거리 시뮬레이터 (200ms 코사인)
    robot_service.dart            ← abstract RobotService
    setup_service.dart            ← Setup 관련 서비스
    uwb_safety_service.dart       ← Safety 상태 머신
  widgets/
    grid_overlay.dart             ← 맵 그리드
    robot_dot.dart                ← 로봇 마커 위젯
```

### 핵심 인터페이스 (변경 시 주의)
```dart
// RobotService (abstract)
Stream<List<RobotData>> get stream  // 주기적 로봇 목록 방출
void sendStop(String robotId)       // controlWay=0, stopType=1
void sendResume(String robotId)     // controlWay=1
void dispose()                      // 타이머/스트림 정리

// UwbSafetyService
// - RobotService를 참조 (소유X)
// - RobotScreen이 UwbSafetyService.stream 구독
// - safety state 반영된 List<RobotData> 방출
```

### 화면 흐름 (현재)
```
LoginScreen → ContextSelectScreen ─── (⚙) → SetupScreen (TabBar)
                  └─ (Region/Site/Floor) → RobotMapRouterScreen
                                               └─ _resolveMap() → RobotScreen
```

---

## TASK 0: 센터 등록 UI 리팩토링

### 변경 요구사항
- **ContextSelectScreen**: 하단에 `[신규 센터 등록]` 버튼 추가
- **SetupScreen (⚙ 아이콘)**: 계정 설정 + 기존 센터 파라미터 수정 전용으로 유지
- 신규 센터 등록은 ContextSelectScreen에서 진입

### 변경 대상 파일

#### 1. `lib/screens/context_select_screen.dart` [수정]
```dart
// 기존 Region/Site/Floor 선택 UI 하단에 추가:
// 
// Scaffold body 구조:
//   Column(
//     children: [
//       Expanded(child: _buildSelectionUI()),  // 기존 선택 UI
//       Padding(
//         padding: EdgeInsets.all(16),
//         child: SizedBox(
//           width: double.infinity,
//           child: ElevatedButton.icon(
//             icon: Icon(Icons.add_business),
//             label: Text('신규 센터 등록'),
//             onPressed: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SetupScreen(initialTab: 0),  // center_location_tab으로 진입
//               ),
//             ),
//           ),
//         ),
//       ),
//     ],
//   )
```

#### 2. `lib/screens/setup/setup_screen.dart` [수정]
```dart
// initialTab 파라미터 추가하여 특정 탭으로 바로 진입 가능하게
class SetupScreen extends StatefulWidget {
  final int initialTab;  // 추가
  const SetupScreen({super.key, this.initialTab = 0});
  // ...
}

// initState에서:
// _tabController = TabController(
//   length: _tabs.length,
//   vsync: this,
//   initialIndex: widget.initialTab,
// );
```

---

## TASK 1: Distance Threshold 가변 설정

### 현재 상태
- `uwb_safety_service.dart`에 threshold 3.0m/3.1m 하드코딩
- `setup_config.dart` 존재하지만 threshold 연동 미확인

### 변경 대상 파일

#### 1. `lib/models/setup_config.dart` [수정]
```dart
// 기존 SetupConfig에 safety distance 필드 추가 (없다면)
class SetupConfig {
  // ... 기존 필드 ...
  
  double thresholdStopM;       // 정지 거리 (기본 3.0)
  double thresholdResumeM;     // 재개 거리 (기본 3.1)
  int cooldownMs;              // Pause 난사 방지 (기본 1000)
  
  // 유효성: thresholdStopM < thresholdResumeM 항상 유지
}
```

#### 2. `lib/screens/setup/setup_screen.dart` [수정]
```dart
// 새 탭 추가: "Safety" 또는 "Distance"
// 기존 탭: [Center/Location, Anchor, Tag, Robot Mapping, Connection Test]
// 변경 후: [Center/Location, Anchor, Tag, Robot Mapping, Connection Test, Safety]
```

#### 3. `lib/screens/setup/safety_settings_tab.dart` [신규]
```dart
// Safety Distance 설정 탭
// 
// UI 구성:
//   - "정지 거리 (Threshold Stop)" 라벨
//   - Slider: 1.0m ~ 10.0m, 0.5m 단위
//   - 현재 값 표시: "3.0m"
//   - "재개 거리" 자동 계산 표시: "3.1m (정지 + 0.1m)"
//   - Cooldown 설정: Slider 500ms ~ 3000ms
//   - [적용] 버튼
//
// 적용 시:
//   setupService.updateSafetyConfig(config);
//   → UwbSafetyService에 실시간 반영
```

#### 4. `lib/services/uwb_safety_service.dart` [수정]
```dart
// 기존 하드코딩 threshold → SetupConfig 참조로 변경
//
// 변경 전 (추정):
//   static const double _thresholdStop = 3.0;
//   static const double _thresholdResume = 3.1;
//
// 변경 후:
//   double get _thresholdStop => _config.thresholdStopM;
//   double get _thresholdResume => _config.thresholdResumeM;
//
//   void updateConfig(SetupConfig config) {
//     assert(config.thresholdStopM < config.thresholdResumeM);
//     _config = config;
//     // 다음 판단 사이클부터 새 값 적용 (별도 재시작 불필요)
//   }
```

---

## TASK 2: UWB 그룹 & Relation 설정

### 구현 범위
1. Tag 그룹 관리 (CRUD)
2. 그룹 간 Relation 설정 (회피 관계 + 개별 Threshold)
3. Safety 판단 로직을 Relation 기반으로 확장

### 신규 모델 파일

#### 1. `lib/models/tag_group.dart` [신규]
```dart
enum TagGroupType { robot, human, forklift }

class TagGroup {
  final String id;
  String name;                 // "피킹 작업자 그룹", "Dahua AMR 그룹"
  TagGroupType type;
  List<String> tagIds;         // 소속 Tag ID 리스트
  
  // 로봇 그룹 전용
  String? fmsIp;
  String? robotBrand;
  String? robotModel;
  String? baseUrl;             // API Base URL
  String? robotListApiUrl;
}
```

#### 2. `lib/models/tag_group_relation.dart` [신규]
```dart
class TagGroupRelation {
  final String id;
  String groupAId;              // 사람 그룹
  String groupBId;              // 로봇 그룹
  double thresholdStopM;        // 이 관계의 정지 거리
  double thresholdResumeM;      // 이 관계의 재개 거리
  bool isActive;                // 활성/비활성 토글
}
```

### Setup 탭 확장

#### 3. `lib/screens/setup/tag_tab.dart` [수정]
```dart
// 기존 Tag 탭에 그룹 관리 기능 추가
//
// 현재: Tag 등록/리스트만 표시 (추정)
// 변경: Tag 등록 + 그룹 관리 + 그룹 할당
//
// UI 추가:
//   - 그룹 리스트 섹션
//     - 아이콘: 로봇/사람/지게차 구분
//     - 그룹명, 소속 Tag 수
//     - [+ 그룹 추가] FAB
//   - 그룹 편집 BottomSheet 또는 Dialog
//     - 그룹명 입력
//     - 타입 선택 (SegmentedButton)
//     - 로봇 타입 시 추가: FMS IP, Brand, Base URL, Robot List API URL
//     - 소속 Tag 선택 (Chip 형태)
```

#### 4. `lib/screens/setup/relation_tab.dart` [신규]
```dart
// Relation 설정 탭 (SetupScreen에 탭 추가)
//
// UI:
//   - Relation 리스트 (ListView)
//     - "피킹 작업자 ↔ Dahua AMR" / 3.0m / 활성
//     - 탭 → 편집, 슬라이드 → 삭제
//   - [+ Relation 추가] FAB
//   - Relation 편집 Dialog/Sheet:
//     - 그룹 A 선택 (Dropdown, 사람/지게차 그룹만)
//     - 그룹 B 선택 (Dropdown, 로봇 그룹만)
//     - 정지 거리 입력 (기본 3.0m)
//     - 재개 거리 자동 (stop + 0.1m)
//     - 활성/비활성 Switch
//     - [Safety Test] 버튼 → Pause 3초 후 Resume 1회
```

### 서비스 확장

#### 5. `lib/services/tag_group_service.dart` [신규]
```dart
// Tag 그룹 및 Relation CRUD 서비스
//
// class TagGroupService {
//   List<TagGroup> _groups = [];
//   List<TagGroupRelation> _relations = [];
//   
//   // 그룹 CRUD
//   void addGroup(TagGroup group);
//   void updateGroup(TagGroup group);
//   void removeGroup(String groupId);
//   TagGroup? getGroupByTagId(String tagId);
//   
//   // Relation CRUD
//   void addRelation(TagGroupRelation relation);
//   void removeRelation(String relationId);
//   TagGroupRelation? getActiveRelation(String tagIdA, String tagIdB);
//   
//   // 핵심: 두 Tag 간 활성 Relation과 Threshold 조회
//   // UwbSafetyService가 호출
// }
```

#### 6. `lib/services/uwb_safety_service.dart` [수정]
```dart
// 기존 단일 threshold → Relation 기반 threshold로 확장
//
// TagGroupService를 생성자에서 받거나, 선택적 의존성으로 주입
// TagGroupService가 null이면 기존 글로벌 threshold 사용 (하위 호환)
//
// class UwbSafetyService {
//   final RobotService _robotService;
//   final TagGroupService? _tagGroupService;  // 추가 (optional)
//   
//   bool _shouldPause(String robotTagId, String humanTagId, double distance) {
//     if (_tagGroupService != null) {
//       final relation = _tagGroupService!.getActiveRelation(robotTagId, humanTagId);
//       if (relation == null || !relation.isActive) return false;
//       return distance < relation.thresholdStopM;
//     }
//     return distance < _config.thresholdStopM;  // fallback
//   }
// }
```

---

## TASK 3: Map & Safety Zone Annotation

### 구현 범위
1. DWF/PNG 맵 이미지 업로드 (1 Pixel = 5cm)
2. Safety Zone 다각형 어노테이션
3. Zone별 Safety ON/OFF 토글
4. Zone 기반 Safety 로직 (UWB 좌표 확인 후 완성)

### 신규 모델

#### 1. `lib/models/map_config.dart` [신규]
```dart
class MapConfig {
  final String id;
  String locationId;
  String imagePath;
  double pixelResolutionCm;      // 기본 5.0
  Offset origin;                 // (0,0) = 좌측 하단
  Size mapSizePixels;
}
```

#### 2. `lib/models/safety_zone.dart` [신규]
```dart
class SafetyZone {
  final String id;
  String name;
  List<Offset> polygon;          // 꼭짓점 (픽셀 좌표)
  bool safetyEnabled;            // ON/OFF
  double? customThresholdStopM;  // null이면 Relation 기본값
  double? customThresholdResumeM;
  Color zoneColor;
}
```

### Setup 탭

#### 3. `lib/screens/setup/map_zone_tab.dart` [신규]
```dart
// SetupScreen에 "Map & Zone" 탭 추가
//
// UI:
//   - 맵 이미지 업로드/표시 (InteractiveViewer)
//   - Zone 오버레이 (CustomPaint + ZonePainter)
//   - Zone 리스트 패널 (이름, ON/OFF 토글)
//   - [+ Zone 추가] → 드로잉 모드
//     - 맵 탭 → 꼭짓점 추가 (최소 3개)
//     - [완료] → 이름/Safety ON|OFF 입력 → 저장
```

### 위젯

#### 4. `lib/widgets/zone_painter.dart` [신규]
```dart
// CustomPainter: Safety Zone 다각형 렌더링
// ON = 반투명 녹색 (#3300FF00), OFF = 반투명 빨강 (#33FF0000)
// 테두리: ON = green, OFF = red, strokeWidth = 2.0
// 기존 grid_overlay.dart, robot_dot.dart 패턴 참고
```

#### 5. `lib/utils/coordinate_converter.dart` [신규]
```dart
// 픽셀 ↔ 실좌표 변환 + Ray casting Point-in-Polygon
// 맵 해상도: 1px = 5cm, 좌측 하단 (0,0) 기준
// Y축 반전: 이미지=좌상단 기준, 맵=좌하단 기준
```

### Safety 서비스 Zone 연동

#### 6. `lib/services/uwb_safety_service.dart` [수정 - TASK 2에 이어서]
```dart
// Zone 체크 추가 (좌표 수신 가능 시)
// 판단 순서:
//   1. Relation 확인 → 없으면 무시
//   2. Zone 체크 (좌표 있을 때만):
//      - 로봇이 Safety OFF Zone → 무시
//      - Zone에 커스텀 Threshold → 해당 값 사용
//   3. Relation threshold로 최종 판단
//
// ※ UWB 좌표 수신 확인 전까지 Zone 로직 비활성
//   → 좌표 없으면 Zone 무시, Relation threshold만 사용
```

---

## 최종 파일 변경 요약

```
[수정] lib/models/setup_config.dart              ← TASK 1: threshold 필드
[수정] lib/screens/context_select_screen.dart     ← TASK 0: 신규 센터 등록 버튼
[수정] lib/screens/setup/setup_screen.dart        ← TASK 0,1,2,3: 탭 추가/initialTab
[수정] lib/screens/setup/tag_tab.dart             ← TASK 2: 그룹 관리 UI
[수정] lib/services/uwb_safety_service.dart       ← TASK 1,2,3: config/relation/zone

[신규] lib/models/tag_group.dart                  ← TASK 2
[신규] lib/models/tag_group_relation.dart         ← TASK 2
[신규] lib/models/map_config.dart                 ← TASK 3
[신규] lib/models/safety_zone.dart                ← TASK 3
[신규] lib/screens/setup/safety_settings_tab.dart ← TASK 1
[신규] lib/screens/setup/relation_tab.dart        ← TASK 2
[신규] lib/screens/setup/map_zone_tab.dart        ← TASK 3
[신규] lib/services/tag_group_service.dart        ← TASK 2
[신규] lib/widgets/zone_painter.dart              ← TASK 3
[신규] lib/utils/coordinate_converter.dart        ← TASK 3
```

---

## 구현 순서 (권장)

```
TASK 0 → context_select_screen + setup_screen 수정 (30분)
TASK 1 → setup_config + safety_settings_tab + uwb_safety_service (1시간)
TASK 2 → tag_group 모델 + tag_group_service + relation_tab + safety 확장 (2-3시간)
TASK 3 → map/zone 모델 + map_zone_tab + zone_painter + converter (3-4시간)
         └─ Zone Safety 로직은 UWB 좌표 확인 후 완성
```

## Claude Code 실행 프롬프트

```
docs/DEV_TASK_R2.md 참고해서 TASK 0부터 순서대로 구현해줘.
기존 RobotService 인터페이스와 UwbSafetyService 상태 머신은 하위호환 유지.
SetupScreen의 기존 TabBar 패턴(anchor_tab, tag_tab 등)에 맞춰서 새 탭 추가.
각 TASK 완료 후 flutter analyze 실행해서 에러 없는지 확인.
```

## 주의사항

- `RobotScreen` 해제 순서 준수: `_sub.cancel()` → `_safetyService.dispose()` → `_uwbService.dispose()` → `_service.dispose()`
- `controlDevice` API에서 `all = 1` (전체 제어)은 Safety에서 절대 금지
- threshold_stop < threshold_resume 항상 유지
- STOPPED_BY_SAFETY 상태에서 거리 데이터 끊기면 Resume 하지 않음
- Zone OFF 구역이라도 로그 기록 유지
- 맵 해상도: 1 Pixel = 5cm 고정, 좌측 하단 (0,0) 기준
- 기존 withOpacity deprecation info 2개는 무시, 신규 코드에서 추가 이슈 없어야 함
- 백업 파일 3개 (Back up-2025-12-15, main.dart.backup, Smulation.dart_12_04) 정리 권장
