# Controller 작성 가이드

GetxController 작성 시 프로젝트 컨벤션을 따르는 지침서입니다.

---

## 1. 기본 구조

### 1.1 파일 템플릿

```dart

class FeatureController extends GetxController {
  // 1. 싱글톤 접근자
  static FeatureController get to => Get.find();

  // 2. Repository 인스턴스
  final FeatureRepository _featureRepository = FeatureRepository();

  // 3. 상태 변수 (Rx)
  final _isLoading = false.obs;
  final _items = <FeatureResponse>[].obs;

  // 4. Getter/Setter
  bool get isLoading => _isLoading.value;
  set isLoading(bool value) => _isLoading.value = value;

  List<FeatureResponse> get items => _items;
  set items(List<FeatureResponse> value) => _items.assignAll(value);

  // 5. UI 컨트롤러
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // 6. 라이프사이클 메서드
  @override
  void onInit() {
    super.onInit();
    _loadData();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // 7. 비즈니스 로직 메서드
  Future<void> _loadData() async {
    try {
      isLoading = true;
      final result = await _featureRepository.getItems();
      if (result != null) {
        items = result;
      }
    } catch (e) {
      log('Failed to load data: $e');
      EasyloadingService.to.showInfo('데이터를 불러오는데 실패했습니다.');
    } finally {
      
    }
  }
}
```
## 2. Repository 연동

### 2.1 Repository 인스턴스 생성

```dart
class FeatureController extends GetxController {
  // Repository는 Controller에서 직접 인스턴스 생성
  final FeatureRepository _featureRepository = FeatureRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
}
```

### 2.2 데이터 조회 패턴

```dart
/// 목록 조회
Future<void> loadItems() async {
  try {
    isLoading = true;
    final result = await _featureRepository.getItems();
    if (result != null) {
      items = result;
    }
  } catch (e) {
    log('Failed to load items: $e');
    EasyloadingService.to.showInfo('목록을 불러오는데 실패했습니다.');
  } finally {
    
  }
}

/// 단일 항목 조회 (성공 여부 반환)
Future<bool> fetchItemDetail(String id) async {
  try {
    isDetailLoading = true;
    final result = await _featureRepository.getItem(id);
    if (result != null) {
      itemDetail = result;
      return true;
    }
    return false;
  } catch (e) {
    log('Failed to fetch item detail: $e');
    return false;
  } finally {
    isDetailLoading = false;
  }
}
```

### 3.3 데이터 생성/수정/삭제 패턴

```dart
/// 생성
Future<void> createItem() async {
  // 유효성 검사
  if (name == null || name!.isEmpty) {
    EasyloadingService.to.showInfo('이름을 입력해주세요.');
    return;
  }

  try {
    final parameter = CreateItemParameter(name: name);
    final result = await _featureRepository.createItem(parameter);

    if (result != null) {
      Get.back();  // 화면 닫기
      EasyloadingService.to.showInfo('등록되었습니다.');
      // 목록 갱신
      await FeatureController.to.loadItems();
    } else {
      EasyloadingService.to.showInfo('등록에 실패했습니다.');
    }
  } catch (e) {
    log('Failed to create item: $e');
    EasyloadingService.to.showInfo('등록에 실패했습니다.');
  } finally {
  }
}

/// 삭제
Future<bool> deleteItem(String id) async {
  try {
    isLoading = true;
    final success = await _featureRepository.deleteItem(id);

    if (success) {
      EasyloadingService.to.showInfo('삭제되었습니다.');
      loadItems();  // 목록 갱신
      return true;
    } else {
      EasyloadingService.to.showInfo('삭제에 실패했습니다.');
      return false;
    }
  } catch (e) {
    log('Failed to delete item: $e');
    EasyloadingService.to.showInfo('삭제에 실패했습니다.');
    return false;
  } finally {
    
  }
}
```

---

## 4. UI 컨트롤러 관리

### 4.1 TextEditingController

```dart
class FeatureController extends GetxController {
  // 선언
  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // 리스너 등록 (필요한 경우)
    searchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    // 반드시 dispose
    nameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    // 검색어 변경 처리
    searchItems();
  }
}
```

### 4.2 ScrollController

```dart
class FeatureController extends GetxController {
  final ScrollController scrollController = ScrollController();

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
```

### 4.3 FormKey

```dart
class FeatureController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  void submit() {
    if (formKey.currentState?.validate() ?? false) {
      // 폼 유효성 검사 통과
      createItem();
    }
  }
}
```

---

## 5. 검색 기능 구현

### 5.1 로컬 검색 (클라이언트 사이드)

```dart
class CustomerController extends GetxController {
  final _allCustomers = <CustomerResponse>[].obs;  // 전체 목록
  final _customers = <CustomerResponse>[].obs;      // 필터링된 목록

  final TextEditingController searchController = TextEditingController();

  /// 고객 목록 조회
  Future<void> loadCustomers() async {
    try {
      isLoading = true;
      final result = await _customerRepository.getCustomers();
      if (result != null) {
        _allCustomers.value = result;
        _customers.value = result;
      }
    } catch (e) {
      EasyloadingService.to.showInfo('고객 목록을 불러오는데 실패했습니다.');
    } finally {
      
    }
  }

  /// 고객 검색 (로컬 필터링)
  void searchCustomers() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _customers.value = _allCustomers;
    } else {
      _customers.value = _allCustomers.where((customer) {
        final name = customer.name?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    }
  }

  /// 검색 초기화
  void clearSearch() {
    searchController.clear();
    _customers.value = _allCustomers;
  }
}
```

### 5.2 서버 검색 (API 호출)

```dart
/// 고객 검색 (서버 API)
Future<void> searchCustomers(String query) async {
  try {
    final result = await _customerRepository.getCustomers(search: query);
    if (result != null) {
      customers = result;
    }
  } catch (e) {
    log('Failed to search customers: $e');
  }
}
```

---

## 6. 라이프사이클 메서드

### 6.1 onInit

```dart
@override
void onInit() {
  super.onInit();  // 반드시 호출

  // 초기 데이터 로드
  _loadData();

  // 리스너 등록
  searchController.addListener(_onSearchChanged);

  // arguments 처리
  final args = Get.arguments;
  if (args != null && args['id'] != null) {
    fetchDetail(args['id']);
  }
}
```

### 6.2 onReady

```dart
@override
void onReady() {
  super.onReady();  // 반드시 호출

  // 화면 렌더링 완료 후 실행할 작업
  // (onInit보다 늦게 실행됨)
}
```

### 6.3 onClose

```dart
@override
void onClose() {
  // 리소스 정리 (dispose)
  searchController.dispose();
  scrollController.dispose();
  memoController.dispose();

  super.onClose();  // 반드시 마지막에 호출
}
```

---

## 7. 다른 Controller 접근

### 7.1 싱글톤 패턴 (권장)

```dart
// 다른 Controller에서 접근
class ScheduleRegisterController extends GetxController {
  Future<void> registerSchedule() async {
    // ...
    // 다른 Controller의 메서드 호출
    await ScheduleController.to.fetchSchedules();
  }
}
```
---

## 8. 에러 처리 및 로딩

### 8.1 로딩 상태 관리

```dart
// 전역 로딩 (EasyLoading)
await EasyloadingService.to.showLoading('처리 중...');
// ... 작업 수행
await EasyloadingService.to.hideLoading();

// 로컬 로딩 (Rx 변수)
isLoading = true;
// ... 작업 수행

```

### 8.2 메시지 표시

```dart
// 정보 메시지
EasyloadingService.to.showInfo('등록되었습니다.');

// 토스트 메시지
EasyloadingService.to.showToast('목록을 불러오는데 실패했습니다.', issuccess: false);
```

### 8.3 try-catch-finally 패턴

```dart
Future<void> someAsyncMethod() async {
  try {
    isLoading = true;
    // 비동기 작업
    final result = await _repository.fetchData();
    if (result != null) {
      data = result;
    }
  } catch (e) {
    log('Failed to fetch data: $e');
    EasyloadingService.to.showInfo('데이터를 불러오는데 실패했습니다.');
  } finally {
    
  }
}
```

---

## 9. 화면 전환 후 처리

### 9.1 등록/수정 후 목록 갱신

```dart
Future<void> createItem() async {
  try {
    isLoading = true;
    final result = await _repository.createItem(parameter);

    if (result != null) {
      // 1. 화면 먼저 닫기
      Get.back();

      // 2. 목록 갱신
      await FeatureController.to.loadItems();

      // 3. 성공 메시지 표시
      EasyloadingService.to.showInfo('등록되었습니다.');
    }
  } finally {
    
  }
}
```

### 9.2 arguments 전달

```dart
// 화면 이동 시 데이터 전달
Get.toNamed(Routes.FEATURE_DETAIL, arguments: {'item': item});

// Controller에서 arguments 받기
@override
void onInit() {
  super.onInit();
  final args = Get.arguments;
  if (args != null && args['item'] != null) {
    selectedItem = args['item'];
  }
}
```

---

## 10. 네이밍 컨벤션

### 10.1 파일명

```
lib/app/modules/feature/controllers/
├── feature_controller.dart         # 기본 Controller
├── feature_register_controller.dart # 등록 Controller
├── feature_edit_controller.dart     # 수정 Controller
└── feature_detail_controller.dart   # 상세 Controller
```

### 10.2 클래스명

```dart
class FeatureController extends GetxController { }
class FeatureRegisterController extends GetxController { }
class FeatureEditController extends GetxController { }
class FeatureDetailController extends GetxController { }
```

### 10.3 변수명

| 종류 | 패턴 | 예시 |
|------|------|------|
| Private Rx | `_변수명` | `_isLoading`, `_items` |
| Public Getter | `변수명` | `isLoading`, `items` |
| Repository | `_도메인Repository` | `_customerRepository` |
| UI Controller | `용도Controller` | `searchController`, `memoController` |

---

## 11. 체크리스트

Controller 작성 시 확인 사항:

- [ ] `GetxController` 상속
- [ ] 싱글톤 접근자 `static get to => Get.find()` (필요시)
- [ ] Repository 인스턴스 생성
- [ ] 상태 변수 `.obs` 선언 및 Getter/Setter
- [ ] `onInit()`에서 `super.onInit()` 호출
- [ ] `onClose()`에서 모든 Controller `dispose()`
- [ ] `onClose()`에서 `super.onClose()` 마지막에 호출
- [ ] `try-catch-finally` 패턴으로 에러 처리
- [ ] 로딩 상태 관리 (`isLoading`)
- [ ] 사용자 피드백 메시지 (`EasyloadingService`)
- [ ] 로그 출력 (`log()`)

---

## 12. 참고

- [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md) - 프로젝트 구조
- [GetX 공식 문서](https://pub.dev/packages/get)
