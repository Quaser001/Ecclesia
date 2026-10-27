# Frontend UI/UX Product Requirements & Technical Specification Document (CalFit Flutter App)

## 1. Executive Overview & Scope

This document serves as the complete, authoritative UI/UX & technical specification for the **CalFit Flutter Mobile Application** located in `apps/mobile/`.

It is specifically designed to provide a 1:1 blueprint of the frontend architecture, design token system, state management, screen components, and API integration contracts. With this document, developers and AI agents can refactor, modify, or enhance the UI/UX without breaking backend alignment, data parsing, or lifecycle contracts.

### Key Tech Stack
- **Framework:** Flutter 3.x / Dart 3.x
- **UI Paradigm:** Material Design 3 (`useMaterial3: true`)
- **Key Packages:** `http` (v1.6.0), `image_picker` (v1.2.3), `intl` (v0.20.3), `http_parser` (v4.1.2)
- **State Strategy:** `StatefulWidget` with optimistic UI updates and async state flags (`_loading`, `_saving`, `_scanning`, `_error`).

---

## 2. Architecture & Directory Tree

```
apps/mobile/
├── pubspec.yaml                 # Dependencies and assets specification
└── lib/
    ├── main.dart                # App entrypoint and global Material 3 theme configuration
    ├── models/
    │   ├── user_profile.dart    # UserProfile model & JSON serialization
    │   └── scan_result.dart     # ScanResult, ScoreResult, ProductObservation, ScanFinding, Alternatives models
    ├── services/
    │   └── api_service.dart     # HTTP client wrapper for FastAPI backend endpoints
    └── screens/
        ├── home_navigation.dart # Main Scaffold with IndexedStack & NavigationBar
        ├── scan_screen.dart     # Food scan landing, camera/gallery picker & submission
        ├── result_screen.dart   # Detailed score breakdown, AI explanation, findings & alternatives
        ├── history_screen.dart  # Historical scan list with score badges and pull-to-refresh
        └── profile_screen.dart  # Health conditions, allergies, dietary preferences & goals editor
```

---

## 3. Design Tokens & Theme Specification

### 3.1 Color Palette

| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| **Primary (Emerald)** | `#059669` | Primary action buttons, active tab indicators, app bar titles |
| **Primary Seed** | `#10B981` | Vibrant accent color, border highlights |
| **Secondary (Sky Blue)** | `#0284C7` | Information badges, criteria/recommendation accents |
| **Scaffold Background** | `#F7FAF8` | Off-white background for clean readability |
| **Surface (Card/Dialog)**| `#FFFFFF` | Card backgrounds, AppBars, Navigation Bars |
| **Text Primary** | `#0F172A` | Primary headings, dark body text |
| **Text Muted** | `#64748B` / `#94A3B8` | Subtitles, hints, timestamps |
| **Border Neutral** | `#E2E8F0` / `#CBD5E1` | Card outlines, text field borders |
| **Success Background** | `#ECFDF5` / `#D1FAE5` | Banner backgrounds, high-score chips |
| **Danger / Alert** | `#DC2626` / `#991B1B` | Critical findings, unsuitability warnings, error alerts |

### 3.2 Suitability & Score Color Mapping

The application maps numeric scores `(0-100)` to explicit colors dynamically across `ResultScreen` and `HistoryScreen`:

| Score Range | Suitability Status | Color |
| :--- | :--- | :--- |
| **80 - 100** | Excellent Fit | `Colors.green.shade600` (`#16A34A`) |
| **60 - 79** | Good Fit | `Colors.lightGreen.shade700` (`#65A30D`) |
| **40 - 59** | Fair Fit | `Colors.amber.shade700` (`#D97706`) |
| **20 - 39** | Poor Fit | `Colors.orange.shade800` (`#EA580C`) |
| **0 - 19** | Not Suitable | `Colors.red.shade700` (`#DC2626`) |

---

## 4. Complete Codebase & Component Reference

To ensure accurate UI modifications without requiring cross-file checks, the exact current implementation of all Dart files is documented below.

### 4.1 Entry Point & Theme (`lib/main.dart`)

```dart
import 'package:flutter/material.dart';
import 'screens/home_navigation.dart';
import 'services/api_service.dart';

void main() {
  runApp(const CalFitApp());
}

class CalFitApp extends StatelessWidget {
  const CalFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    const defaultUserId = 'dev-user-001';

    return MaterialApp(
      title: 'CalFit - AI Nutrition & Health Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Modern vibrant emerald
          primary: const Color(0xFF059669),
          secondary: const Color(0xFF0284C7),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        fontFamily: 'Segoe UI',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          color: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 3,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD1FAE5),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669));
            }
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B));
          }),
        ),
      ),
      home: HomeNavigation(
        apiService: apiService,
        userId: defaultUserId,
      ),
    );
  }
}
```

---

### 4.2 Data Models

#### User Profile Model (`lib/models/user_profile.dart`)

```dart
class UserProfile {
  final String userId;
  final String? name;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> dietaryPreferences;
  final List<String> healthGoals;

  UserProfile({
    required this.userId,
    this.name,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dietaryPreferences = const [],
    this.healthGoals = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? 'dev-user-001',
      name: json['name'],
      healthConditions: (json['health_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      healthGoals: (json['health_goals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'health_conditions': healthConditions,
      'allergies': allergies,
      'dietary_preferences': dietaryPreferences,
      'health_goals': healthGoals,
    };
  }

  UserProfile copyWith({
    String? name,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? dietaryPreferences,
    List<String>? healthGoals,
  }) {
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthGoals: healthGoals ?? this.healthGoals,
    );
  }
}
```

#### Scan Result Model (`lib/models/scan_result.dart`)

```dart
enum SuitabilityStatus {
  excellent,
  good,
  fair,
  poor,
  notSuitable,
  unknown;

  static SuitabilityStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'excellent':
        return SuitabilityStatus.excellent;
      case 'good':
        return SuitabilityStatus.good;
      case 'fair':
        return SuitabilityStatus.fair;
      case 'poor':
        return SuitabilityStatus.poor;
      case 'not_suitable':
        return SuitabilityStatus.notSuitable;
      default:
        return SuitabilityStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case SuitabilityStatus.excellent:
        return 'Excellent Fit';
      case SuitabilityStatus.good:
        return 'Good Fit';
      case SuitabilityStatus.fair:
        return 'Fair Fit';
      case SuitabilityStatus.poor:
        return 'Poor Fit';
      case SuitabilityStatus.notSuitable:
        return 'Not Suitable';
      case SuitabilityStatus.unknown:
        return 'Unknown';
    }
  }
}

enum FindingSeverity {
  info,
  warning,
  alert,
  critical;

  static FindingSeverity fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return FindingSeverity.critical;
      case 'alert':
        return FindingSeverity.alert;
      case 'warning':
        return FindingSeverity.warning;
      default:
        return FindingSeverity.info;
    }
  }
}

class ScanFinding {
  final String ruleId;
  final FindingSeverity severity;
  final String title;
  final String detail;
  final String? nutrientOrIngredient;
  final int scoreImpact;

  ScanFinding({
    required this.ruleId,
    required this.severity,
    required this.title,
    required this.detail,
    this.nutrientOrIngredient,
    required this.scoreImpact,
  });

  factory ScanFinding.fromJson(Map<String, dynamic> json) {
    return ScanFinding(
      ruleId: json['rule_id'] ?? '',
      severity: FindingSeverity.fromString(json['severity']),
      title: json['title'] ?? '',
      detail: json['detail'] ?? '',
      nutrientOrIngredient: json['nutrient_or_ingredient'],
      scoreImpact: json['score_impact'] ?? 0,
    );
  }
}

class NutritionInfo {
  final double? caloriesKcal;
  final double? totalFatG;
  final double? saturatedFatG;
  final double? transFatG;
  final double? sodiumMg;
  final double? totalCarbsG;
  final double? dietaryFiberG;
  final double? sugarsG;
  final double? proteinG;

  NutritionInfo({
    this.caloriesKcal,
    this.totalFatG,
    this.saturatedFatG,
    this.transFatG,
    this.sodiumMg,
    this.totalCarbsG,
    this.dietaryFiberG,
    this.sugarsG,
    this.proteinG,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NutritionInfo();
    return NutritionInfo(
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble(),
      totalFatG: (json['total_fat_g'] as num?)?.toDouble(),
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble(),
      transFatG: (json['trans_fat_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble(),
      dietaryFiberG: (json['dietary_fiber_g'] as num?)?.toDouble(),
      sugarsG: (json['sugars_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
    );
  }
}

class ProductObservation {
  final String? brand;
  final String? productName;
  final String? category;
  final List<String> ingredients;
  final NutritionInfo nutrition;
  final List<String> allergensDeclared;
  final List<String> visibleClaims;
  final double extractionConfidence;
  final bool insufficientData;
  final String? extractionNotes;

  ProductObservation({
    this.brand,
    this.productName,
    this.category,
    required this.ingredients,
    required this.nutrition,
    required this.allergensDeclared,
    required this.visibleClaims,
    required this.extractionConfidence,
    required this.insufficientData,
    this.extractionNotes,
  });

  factory ProductObservation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ProductObservation(
        ingredients: [],
        nutrition: NutritionInfo(),
        allergensDeclared: [],
        visibleClaims: [],
        extractionConfidence: 0.0,
        insufficientData: true,
      );
    }
    return ProductObservation(
      brand: json['brand'],
      productName: json['product_name'],
      category: json['category'],
      ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      nutrition: NutritionInfo.fromJson(json['nutrition']),
      allergensDeclared: (json['allergens_declared'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      visibleClaims: (json['visible_claims'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble() ?? 0.0,
      insufficientData: json['insufficient_data'] ?? false,
      extractionNotes: json['extraction_notes'],
    );
  }
}

class ScoreResult {
  final int score;
  final SuitabilityStatus suitability;
  final String riskLevel;
  final List<ScanFinding> findings;
  final List<String> rulesApplied;

  ScoreResult({
    required this.score,
    required this.suitability,
    required this.riskLevel,
    required this.findings,
    required this.rulesApplied,
  });

  factory ScoreResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ScoreResult(
        score: 0,
        suitability: SuitabilityStatus.unknown,
        riskLevel: 'unknown',
        findings: [],
        rulesApplied: [],
      );
    }
    return ScoreResult(
      score: json['score'] ?? 0,
      suitability: SuitabilityStatus.fromString(json['suitability']),
      riskLevel: json['risk_level'] ?? 'unknown',
      findings: (json['findings'] as List<dynamic>?)?.map((e) => ScanFinding.fromJson(e)).toList() ?? [],
      rulesApplied: (json['rules_applied'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AlternativeItem {
  final String type; // 'product' or 'criteria'
  final String? name;
  final String? brand;
  final String reason;
  final String? criteria;
  final bool verified;

  AlternativeItem({
    required this.type,
    this.name,
    this.brand,
    required this.reason,
    this.criteria,
    required this.verified,
  });

  factory AlternativeItem.fromJson(Map<String, dynamic> json) {
    return AlternativeItem(
      type: json['type'] ?? 'criteria',
      name: json['name'],
      brand: json['brand'],
      reason: json['reason'] ?? '',
      criteria: json['criteria'],
      verified: json['verified'] ?? false,
    );
  }
}

class ScanResult {
  final String scanId;
  final String userId;
  final DateTime scannedAt;
  final ProductObservation product;
  final ScoreResult scoreResult;
  final String explanation;
  final List<AlternativeItem> alternatives;
  final String? imageUrl;
  final bool insufficientData;
  final String? pipelineMessage;

  ScanResult({
    required this.scanId,
    required this.userId,
    required this.scannedAt,
    required this.product,
    required this.scoreResult,
    required this.explanation,
    required this.alternatives,
    this.imageUrl,
    required this.insufficientData,
    this.pipelineMessage,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      scanId: json['scan_id'] ?? '',
      userId: json['user_id'] ?? '',
      scannedAt: json['scanned_at'] != null ? DateTime.parse(json['scanned_at']) : DateTime.now(),
      product: ProductObservation.fromJson(json['product']),
      scoreResult: ScoreResult.fromJson(json['score_result']),
      explanation: json['explanation'] ?? '',
      alternatives: (json['alternatives'] as List<dynamic>?)?.map((e) => AlternativeItem.fromJson(e)).toList() ?? [],
      imageUrl: json['image_url'],
      insufficientData: json['insufficient_data'] ?? false,
      pipelineMessage: json['pipeline_message'],
    );
  }
}

class ScanHistoryItem {
  final String scanId;
  final String userId;
  final DateTime scannedAt;
  final String? productName;
  final String? brand;
  final int score;
  final SuitabilityStatus suitability;
  final String? imageUrl;

  ScanHistoryItem({
    required this.scanId,
    required this.userId,
    required this.scannedAt,
    this.productName,
    this.brand,
    required this.score,
    required this.suitability,
    this.imageUrl,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      scanId: json['scan_id'] ?? '',
      userId: json['user_id'] ?? '',
      scannedAt: json['scanned_at'] != null ? DateTime.parse(json['scanned_at']) : DateTime.now(),
      productName: json['product_name'],
      brand: json['brand'],
      score: json['score'] ?? 0,
      suitability: SuitabilityStatus.fromString(json['suitability']),
      imageUrl: json['image_url'],
    );
  }
}
```

---

### 4.3 API Service (`lib/services/api_service.dart`)

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_profile.dart';
import '../models/scan_result.dart';

class ApiService {
  static String get defaultBaseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://127.0.0.1:8000';
  final String baseUrl;
  final http.Client client;

  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        client = client ?? http.Client();

  Future<bool> checkHealth() async {
    try {
      final res = await client.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile> getProfile(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile').replace(queryParameters: {'user_id': userId});
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load profile: ${res.statusCode} ${res.body}');
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile').replace(queryParameters: {'user_id': profile.userId});
    final res = await client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': profile.name,
        'health_conditions': profile.healthConditions,
        'allergies': profile.allergies,
        'dietary_preferences': profile.dietaryPreferences,
        'health_goals': profile.healthGoals,
      }),
    );
    if (res.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update profile: ${res.statusCode} ${res.body}');
  }

  Future<ScanResult> submitScan({
    required String userId,
    required Uint8List photoBytes,
    String filename = 'product_photo.jpg',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/scans');
    final request = http.MultipartRequest('POST', uri);
    request.fields['user_id'] = userId;

    final multipartFile = http.MultipartFile.fromBytes(
      'photo',
      photoBytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return ScanResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Scan submission failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<List<ScanHistoryItem>> getScanHistory(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/scans/history').replace(queryParameters: {'user_id': userId});
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => ScanHistoryItem.fromJson(e)).toList();
    }
    throw Exception('Failed to load history: ${res.statusCode} ${res.body}');
  }
}
```

---

### 4.4 Screen Implementations

#### 1. Home Navigation Scaffold (`lib/screens/home_navigation.dart`)
Controls tab switching across `ScanScreen`, `HistoryScreen`, and `ProfileScreen` using an `IndexedStack` to preserve scroll positions and state.

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeNavigation extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const HomeNavigation({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ScanScreen(apiService: widget.apiService, userId: widget.userId),
      HistoryScreen(apiService: widget.apiService, userId: widget.userId),
      ProfileScreen(apiService: widget.apiService, userId: widget.userId),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
```

#### 2. Scan Landing Screen (`lib/screens/scan_screen.dart`)
Supports uploading packaging images from camera or gallery, displaying image preview cards, and submitting to the backend with loading states.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const ScanScreen({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _scanning = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _error = null);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _submitScan() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final result = await widget.apiService.submitScan(
        userId: widget.userId,
        photoBytes: _selectedImageBytes!,
        filename: _selectedImageName ?? 'product_photo.jpg',
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            scanResult: result,
            onScanAnother: () {
              Navigator.pop(context);
              setState(() {
                _selectedImageBytes = null;
                _selectedImageName = null;
              });
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, size: 20, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 8),
            const Text('CalFit Food Scan'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Intro Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalized Health Evaluation',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Snap any label or packaging for instant suitability insights matched to your profile.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF047857),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // Image Preview Card Area
            Container(
              height: 310,
              decoration: BoxDecoration(
                color: _selectedImageBytes != null ? Colors.white : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedImageBytes != null ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: _selectedImageBytes != null ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _selectedImageBytes != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Center(
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  _selectedImageBytes = null;
                                  _selectedImageName = null;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedImageName ?? 'Photo selected',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _scanning ? null : () => _pickImage(ImageSource.gallery),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Click to select or upload food photo',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Supports JPG, PNG, WEBP packaged labels',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            // Photo Selection Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF334155),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('Choose File'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF334155),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Analyze Button
            FilledButton(
              onPressed: (_selectedImageBytes == null || _scanning) ? null : _submitScan,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
              ),
              child: _scanning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Evaluating with CalFit AI...',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Analyze Food Product',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Quick Info Cards
            Row(
              children: [
                _buildFeatureBadge(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Medical Rules',
                  subtitle: 'Deterministic fit',
                ),
                const SizedBox(width: 10),
                _buildFeatureBadge(
                  icon: Icons.visibility_outlined,
                  title: 'Visual OCR',
                  subtitle: 'Label extraction',
                ),
                const SizedBox(width: 10),
                _buildFeatureBadge(
                  icon: Icons.recommend_outlined,
                  title: 'Better Alternatives',
                  subtitle: 'Smarter choices',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF059669)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3. Scan Evaluation Result Screen (`lib/screens/result_screen.dart`)
Renders the circular score indicator, suitability tag, health findings list, expandable nutritional breakdown, and verified product alternatives.

```dart
import 'package:flutter/material.dart';
import '../models/scan_result.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult scanResult;
  final VoidCallback? onScanAnother;

  const ResultScreen({
    super.key,
    required this.scanResult,
    this.onScanAnother,
  });

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.lightGreen.shade700;
    if (score >= 40) return Colors.amber.shade700;
    if (score >= 20) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final product = scanResult.product;
    final scoreResult = scanResult.scoreResult;
    final scoreColor = _getScoreColor(scoreResult.score);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Evaluation'),
        actions: [
          if (onScanAnother != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: onScanAnother,
              tooltip: 'Scan Another',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // Score Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        product.productName ?? 'Packaged Food Product',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (product.brand != null)
                        Text(
                          product.brand!,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: scoreColor, width: 4),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${scoreResult.score}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                              const Text(
                                '/ 100',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          scoreResult.suitability.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Grounded Explanation & Unsuitability Reason
              if (scanResult.explanation.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final isUnsuitable = scoreResult.suitability == SuitabilityStatus.notSuitable ||
                        scoreResult.suitability == SuitabilityStatus.poor;
                    final alertColor = isUnsuitable ? Colors.red.shade700 : Theme.of(context).colorScheme.primary;
                    final bgColor = isUnsuitable ? Colors.red.shade50 : Theme.of(context).cardColor;

                    return Card(
                      elevation: isUnsuitable ? 0 : 2,
                      color: bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isUnsuitable ? Colors.red.shade300 : Colors.grey.shade300,
                          width: isUnsuitable ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUnsuitable ? Icons.warning_amber_rounded : Icons.psychology_outlined,
                                  color: alertColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isUnsuitable
                                        ? 'Why this product is ${scoreResult.suitability.displayName}'
                                        : 'Personalized Health Assessment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isUnsuitable ? Colors.red.shade900 : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              scanResult.explanation,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: isUnsuitable ? Colors.red.shade900 : Colors.grey.shade800,
                                fontWeight: isUnsuitable ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Findings / Health Conflicts
              if (scoreResult.findings.isNotEmpty) ...[
                const Text(
                  'Personalized Health Findings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...scoreResult.findings.map((f) => _buildFindingCard(f)),
                const SizedBox(height: 16),
              ],

              // Nutrition & Ingredients
              ExpansionTile(
                title: const Text('Nutritional Details & Ingredients'),
                leading: const Icon(Icons.fact_check_outlined),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNutrientRow('Calories', '${product.nutrition.caloriesKcal ?? '-'} kcal'),
                        _buildNutrientRow('Total Fat', '${product.nutrition.totalFatG ?? '-'} g'),
                        _buildNutrientRow('Saturated Fat', '${product.nutrition.saturatedFatG ?? '-'} g'),
                        _buildNutrientRow('Sodium', '${product.nutrition.sodiumMg ?? '-'} mg'),
                        _buildNutrientRow('Total Carbs', '${product.nutrition.totalCarbsG ?? '-'} g'),
                        _buildNutrientRow('Sugars', '${product.nutrition.sugarsG ?? '-'} g'),
                        _buildNutrientRow('Protein', '${product.nutrition.proteinG ?? '-'} g'),
                        const SizedBox(height: 12),
                        const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          product.ingredients.isNotEmpty ? product.ingredients.join(', ') : 'Not declared on photo',
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Better-fit Alternatives
              if (scanResult.alternatives.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.recommend, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Similar Better-Fit Alternatives',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...scanResult.alternatives.map((alt) => _buildAlternativeCard(alt)),
                const SizedBox(height: 24),
              ],

              if (onScanAnother != null)
                FilledButton.icon(
                  onPressed: onScanAnother,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Another Product'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindingCard(ScanFinding f) {
    Color severityColor;
    switch (f.severity) {
      case FindingSeverity.critical:
        severityColor = Colors.red.shade700;
        break;
      case FindingSeverity.alert:
        severityColor = Colors.orange.shade800;
        break;
      case FindingSeverity.warning:
        severityColor = Colors.amber.shade800;
        break;
      case FindingSeverity.info:
        severityColor = Colors.blue.shade700;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: severityColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: severityColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: severityColor,
                    ),
                  ),
                ),
                Text(
                  '-${f.scoreImpact} pts',
                  style: TextStyle(fontWeight: FontWeight.bold, color: severityColor, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(f.detail, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeCard(AlternativeItem alt) {
    final isProduct = alt.type == 'product';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isProduct ? Colors.green.shade50 : Colors.blue.shade50,
          child: Icon(
            isProduct ? Icons.check_circle_outline : Icons.lightbulb_outline,
            color: isProduct ? Colors.green.shade700 : Colors.blue.shade700,
          ),
        ),
        title: Text(
          alt.name ?? 'Recommended Criteria',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alt.brand != null)
              Text('Brand: ${alt.brand}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(alt.reason, style: const TextStyle(fontSize: 13)),
          ],
        ),
        trailing: alt.verified
            ? const Chip(
                label: Text('Verified', style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.green,
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

#### 4. Scan History Screen (`lib/screens/history_screen.dart`)
Lists previous scan evaluations with score indicators, formatted scan timestamps using `intl.DateFormat`, and pull-to-refresh capabilities.

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const HistoryScreen({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ScanHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getScanHistory(widget.userId);
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.lightGreen.shade700;
    if (score >= 40) return Colors.amber.shade700;
    if (score >= 20) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _fetchHistory, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No previous scans found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final scoreColor = _getScoreColor(item.score);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${item.score}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                item.productName ?? 'Product Scan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.brand != null)
                    Text(item.brand!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(item.scannedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  item.suitability.displayName,
                  style: TextStyle(fontSize: 11, color: scoreColor, fontWeight: FontWeight.bold),
                ),
                backgroundColor: scoreColor.withValues(alpha: 0.1),
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

#### 5. Profile Management Screen (`lib/screens/profile_screen.dart`)
Manages medical conditions (diabetes, hypertension, celiac), allergies (chip tags), dietary preferences (vegan, keto), and health goals.

```dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const ProfileScreen({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _allergyController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  final Set<String> _selectedConditions = {};
  final List<String> _allergies = [];
  final Set<String> _selectedDietary = {};
  final Set<String> _selectedGoals = {};

  final Map<String, String> _conditionOptions = {
    'diabetes_type_2': 'Type 2 Diabetes',
    'diabetes_type_1': 'Type 1 Diabetes',
    'hypertension': 'Hypertension (High BP)',
    'high_cholesterol': 'High Cholesterol',
    'celiac_disease': 'Celiac Disease',
    'lactose_intolerance': 'Lactose Intolerance',
    'ibs': 'IBS',
    'heart_disease': 'Heart Disease',
    'kidney_disease': 'Kidney Disease',
  };

  final Map<String, String> _dietaryOptions = {
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'gluten_free': 'Gluten-Free',
    'dairy_free': 'Dairy-Free',
    'low_carb': 'Low Carb',
    'keto': 'Keto',
    'halal': 'Halal',
  };

  final Map<String, String> _goalOptions = {
    'weight_loss': 'Weight Loss',
    'muscle_gain': 'Muscle Gain',
    'manage_blood_sugar': 'Manage Blood Sugar',
    'heart_health': 'Heart Health',
    'improve_digestion': 'Improve Digestion',
    'improve_energy': 'Improve Energy',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.apiService.getProfile(widget.userId);
      _nameController.text = profile.name ?? '';
      _selectedConditions.clear();
      _selectedConditions.addAll(profile.healthConditions);
      _allergies.clear();
      _allergies.addAll(profile.allergies);
      _selectedDietary.clear();
      _selectedDietary.addAll(profile.dietaryPreferences);
      _selectedGoals.clear();
      _selectedGoals.addAll(profile.healthGoals);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = UserProfile(
        userId: widget.userId,
        name: _nameController.text.trim(),
        healthConditions: _selectedConditions.toList(),
        allergies: _allergies,
        dietaryPreferences: _selectedDietary.toList(),
        healthGoals: _selectedGoals.toList(),
      );
      await widget.apiService.updateProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addAllergy() {
    final text = _allergyController.text.trim().toLowerCase();
    if (text.isNotEmpty && !_allergies.contains(text)) {
      setState(() {
        _allergies.add(text);
        _allergyController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Profile'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _saveProfile,
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                ),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Health Conditions', Icons.medical_services_outlined),
              const Text(
                'CalFit deterministic scoring uses these conditions to flag high sodium, sugars, fats, etc.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _conditionOptions.entries.map((entry) {
                  final selected = _selectedConditions.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedConditions.add(entry.key);
                        } else {
                          _selectedConditions.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Allergies & Intolerances', Icons.warning_amber_rounded),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _allergyController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. peanut, soy, gluten, shellfish',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addAllergy(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _addAllergy,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _allergies.map((allergy) {
                  return Chip(
                    label: Text(allergy),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() => _allergies.remove(allergy));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Dietary Preferences', Icons.restaurant_menu),
              Wrap(
                spacing: 8,
                children: _dietaryOptions.entries.map((entry) {
                  final selected = _selectedDietary.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDietary.add(entry.key);
                        } else {
                          _selectedDietary.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Health Goals', Icons.flag_outlined),
              Wrap(
                spacing: 8,
                children: _goalOptions.entries.map((entry) {
                  final selected = _selectedGoals.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedGoals.add(entry.key);
                        } else {
                          _selectedGoals.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Guidelines & Rules for Future UI/UX Modifications

When updating or redesigning the CalFit UI/UX, adhere strictly to the following engineering and design guidelines:

1. **Preserve API Key Naming Alignment:**
   - JSON keys in `fromJson` / `toJson` must remain 1:1 with Python FastAPI Pydantic schemas (`user_id`, `health_conditions`, `dietary_preferences`, `health_goals`, `score_result`, `scan_id`, `product_name`, `image_url`).
2. **Always Check Widget Lifecycle (`mounted` Checks):**
   - After asynchronous operations (`await apiService.submitScan(...)`, `await apiService.updateProfile(...)`), **always check `if (!mounted) return;`** before triggering `setState` or `Navigator` navigation.
3. **Responsive Container Constraints:**
   - All main screens use `ConstrainedBox(constraints: BoxConstraints(maxWidth: 680))` centered in the Scaffold to guarantee optimal layout across mobile devices, foldables, and web/desktop views. Keep this layout constraint intact when modifying screen layouts.
4. **Color Colorization Functions:**
   - Maintain the threshold function `_getScoreColor(int score)` when styling score indicators to ensure visual consistency across all screens (`ResultScreen` and `HistoryScreen`).
5. **Image Compression & Pick Constraints:**
   - When customizing camera/gallery pickers in `ScanScreen`, preserve `maxWidth: 1600`, `maxHeight: 1600`, and `imageQuality: 85` to ensure fast payload transmission under the backend's 10MB limit.
