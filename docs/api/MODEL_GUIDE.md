# Neulpick - Model 작성 가이드

API 요청/응답 데이터 모델 작성 시 프로젝트 컨벤션을 따르는 지침서입니다.

---

## 1. 파일 구조

### 1.1 파일 위치

```
lib/app/data/models/
├── featureResponse.dart       # API 응답 모델
├── featureParameter.dart      # API 요청 파라미터
├── createFeatureParameter.dart # 생성 요청 파라미터
└── updateFeatureParameter.dart # 수정 요청 파라미터
```

### 1.2 네이밍 규칙

| 용도 | 파일명 | 클래스명 |
|------|--------|----------|
| API 응답 | `featureResponse.dart` | `FeatureResponse` |
| 조회 파라미터 | `featureParameter.dart` | `FeatureParameter` |
| 생성 파라미터 | `createFeatureParameter.dart` | `CreateFeatureParameter` |
| 수정 파라미터 | `updateFeatureParameter.dart` | `UpdateFeatureParameter` |

---

## 2. Response 모델 (API 응답)

### 2.1 기본 템플릿

```dart
class FeatureResponse {
  /// 고유 ID
  String? _id;

  /// 사용자 ID
  String? _userId;

  /// 이름
  String? _name;

  /// 생성일시
  String? _createdAt;

  /// 수정일시
  String? _updatedAt;

  // 생성자
  FeatureResponse({
    String? id,
    String? userId,
    String? name,
    String? createdAt,
    String? updatedAt,
  }) {
    _id = id;
    _userId = userId;
    _name = name;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
  }

  // Getter/Setter
  String? get id => _id;
  set id(String? id) => _id = id;

  String? get userId => _userId;
  set userId(String? userId) => _userId = userId;

  String? get name => _name;
  set name(String? name) => _name = name;

  String? get createdAt => _createdAt;
  set createdAt(String? createdAt) => _createdAt = createdAt;

  String? get updatedAt => _updatedAt;
  set updatedAt(String? updatedAt) => _updatedAt = updatedAt;

  // JSON 역직렬화
  FeatureResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _userId = json['userId'];
    _name = json['name'];
    _createdAt = json['createdAt'];
    _updatedAt = json['updatedAt'];
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['userId'] = _userId;
    data['name'] = _name;
    data['createdAt'] = _createdAt;
    data['updatedAt'] = _updatedAt;
    return data;
  }
}
```

### 2.2 복합 타입 처리

#### 리스트 타입

```dart
class ScheduleResponse {
  List<String>? _recurrenceWeekdays;

  List<String>? get recurrenceWeekdays => _recurrenceWeekdays;
  set recurrenceWeekdays(List<String>? value) => _recurrenceWeekdays = value;

  ScheduleResponse.fromJson(Map<String, dynamic> json) {
    // 리스트 역직렬화
    _recurrenceWeekdays = json['recurrenceWeekdays'] != null
        ? List<String>.from(json['recurrenceWeekdays'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['recurrenceWeekdays'] = _recurrenceWeekdays;
    return data;
  }
}
```

#### 중첩 객체

```dart
class CustomerWithPlansResponse {
  CustomerResponse? _customer;
  List<CustomerPlanResponse>? _plans;

  CustomerResponse? get customer => _customer;
  List<CustomerPlanResponse>? get plans => _plans;

  CustomerWithPlansResponse.fromJson(Map<String, dynamic> json) {
    // 중첩 객체 역직렬화
    _customer = json['customer'] != null
        ? CustomerResponse.fromJson(json['customer'])
        : null;

    // 중첩 리스트 역직렬화
    _plans = json['plans'] != null
        ? (json['plans'] as List)
            .map((item) => CustomerPlanResponse.fromJson(item))
            .toList()
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['customer'] = _customer?.toJson();
    data['plans'] = _plans?.map((item) => item.toJson()).toList();
    return data;
  }
}
```

### 2.3 타입별 필드 선언

```dart
class ExampleResponse {
  // String
  String? _name;

  // int
  int? _count;

  // double
  double? _price;

  // bool
  bool? _isActive;

  // DateTime (String으로 저장)
  String? _createdAt;

  // List<String>
  List<String>? _tags;

  // List<Object>
  List<ItemResponse>? _items;

  // 중첩 Object
  UserResponse? _user;
}
```

---

## 3. Parameter 모델 (API 요청)

### 3.1 기본 템플릿 (간단한 형태)

```dart
class CreateFeatureParameter {
  String? name;
  String? description;
  int? count;

  CreateFeatureParameter({
    this.name,
    this.description,
    this.count,
  });

  CreateFeatureParameter.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    description = json['description'];
    count = json['count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['description'] = description;
    data['count'] = count;
    return data;
  }
}
```

### 3.2 리스트 포함 파라미터

```dart
class CreateScheduleParameter {
  String? scheduleType;
  String? customerId;
  String? scheduleDate;
  String? startTime;
  String? endTime;
  bool? isRecurring;
  int? recurrenceCount;
  List<String>? recurrenceWeekdays;

  CreateScheduleParameter({
    this.scheduleType,
    this.customerId,
    this.scheduleDate,
    this.startTime,
    this.endTime,
    this.isRecurring,
    this.recurrenceCount,
    this.recurrenceWeekdays,
  });

  CreateScheduleParameter.fromJson(Map<String, dynamic> json) {
    scheduleType = json['scheduleType'];
    customerId = json['customerId'];
    scheduleDate = json['scheduleDate'];
    startTime = json['startTime'];
    endTime = json['endTime'];
    isRecurring = json['isRecurring'];
    recurrenceCount = json['recurrenceCount'];
    recurrenceWeekdays = json['recurrenceWeekdays'] != null
        ? List<String>.from(json['recurrenceWeekdays'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['scheduleType'] = scheduleType;
    data['customerId'] = customerId;
    data['scheduleDate'] = scheduleDate;
    data['startTime'] = startTime;
    data['endTime'] = endTime;
    data['isRecurring'] = isRecurring;
    data['recurrenceCount'] = recurrenceCount;
    data['recurrenceWeekdays'] = recurrenceWeekdays;
    return data;
  }
}
```

---

## 4. Response vs Parameter 비교

| 구분 | Response | Parameter |
|------|----------|-----------|
| 용도 | API 응답 데이터 | API 요청 데이터 |
| 필드 선언 | Private (`_필드명`) | Public (`필드명`) |
| Getter/Setter | 필수 | 불필요 |
| 주석 | 각 필드에 문서화 주석 | 선택사항 |
| 공통 필드 | id, createdAt, updatedAt | - |

### 4.1 Response 스타일

```dart
class CustomerResponse {
  String? _id;           // Private 필드
  String? _name;

  String? get id => _id;  // Getter
  set id(String? id) => _id = id;  // Setter
}
```

### 4.2 Parameter 스타일

```dart
class CreateCustomerParameter {
  String? name;          // Public 필드
  String? contact;
  // Getter/Setter 불필요
}
```

---

## 5. 필드 타입 가이드

### 5.1 API 응답 필드 매핑

| JSON 타입 | Dart 타입 | 예시 |
|-----------|-----------|------|
| string | `String?` | `"홍길동"` |
| number (정수) | `int?` | `10` |
| number (실수) | `double?` | `99.99` |
| boolean | `bool?` | `true` |
| array | `List<T>?` | `["MON", "TUE"]` |
| object | `ClassName?` | `{...}` |
| null | Nullable (`?`) | `null` |

### 5.2 날짜/시간 처리

```dart
// 날짜는 String으로 저장 (YYYY-MM-DD)
String? _scheduleDate;

// 시간은 String으로 저장 (HH:mm)
String? _startTime;
String? _endTime;

// ISO 8601 형식 (createdAt, updatedAt)
String? _createdAt;  // "2025-01-01T12:00:00.000Z"
```

---

## 6. 체크리스트

### Response 모델 작성 시

- [ ] 파일명: `featureResponse.dart`
- [ ] 클래스명: `FeatureResponse`
- [ ] Private 필드 선언 (`_필드명`)
- [ ] 각 필드에 문서화 주석 (`///`)
- [ ] 생성자 구현
- [ ] Getter/Setter 구현
- [ ] `fromJson` 생성자 구현
- [ ] `toJson` 메서드 구현
- [ ] 리스트/중첩 객체 처리

### Parameter 모델 작성 시

- [ ] 파일명: `createFeatureParameter.dart`
- [ ] 클래스명: `CreateFeatureParameter`
- [ ] Public 필드 선언 (`필드명`)
- [ ] 생성자 구현
- [ ] `fromJson` 생성자 구현 (선택)
- [ ] `toJson` 메서드 구현 (필수)

---

## 7. 예시: 전체 모델 세트

### customerResponse.dart

```dart
class CustomerResponse {
  String? _id;
  String? _userId;
  String? _name;
  String? _contact;
  String? _address;
  String? _createdAt;
  String? _updatedAt;

  CustomerResponse({
    String? id,
    String? userId,
    String? name,
    String? contact,
    String? address,
    String? createdAt,
    String? updatedAt,
  }) {
    _id = id;
    _userId = userId;
    _name = name;
    _contact = contact;
    _address = address;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
  }

  // Getters & Setters...

  CustomerResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _userId = json['userId'];
    _name = json['name'];
    _contact = json['contact'];
    _address = json['address'];
    _createdAt = json['createdAt'];
    _updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['userId'] = _userId;
    data['name'] = _name;
    data['contact'] = _contact;
    data['address'] = _address;
    data['createdAt'] = _createdAt;
    data['updatedAt'] = _updatedAt;
    return data;
  }
}
```

### createCustomerParameter.dart

```dart
class CreateCustomerParameter {
  String? name;
  String? contact;
  String? address;

  CreateCustomerParameter({
    this.name,
    this.contact,
    this.address,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['contact'] = contact;
    data['address'] = address;
    return data;
  }
}
```

### updateCustomerParameter.dart

```dart
class UpdateCustomerParameter {
  String? name;
  String? contact;
  String? address;

  UpdateCustomerParameter({
    this.name,
    this.contact,
    this.address,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (contact != null) data['contact'] = contact;
    if (address != null) data['address'] = address;
    return data;
  }
}
```

---

## 8. 참고

- [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md) - 프로젝트 구조
