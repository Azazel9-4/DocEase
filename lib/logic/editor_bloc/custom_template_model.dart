import 'dart:io';

enum TemplateImageMode { zones, background }

class CustomTemplate {
  final int? id;
  final String name;
  final String headerText;
  final String footerText;
  final String? headerImagePath;
  final String? footerImagePath;
  final String? backgroundImagePath;
  final TemplateImageMode imageMode;
  final double backgroundOpacity; // 0.0 - 1.0
  final double bodyTopMargin;     // px from top of page
  final DateTime createdAt;

  const CustomTemplate({
    this.id,
    required this.name,
    required this.headerText,
    required this.footerText,
    this.headerImagePath,
    this.footerImagePath,
    this.backgroundImagePath,
    this.imageMode = TemplateImageMode.zones,
    this.backgroundOpacity = 0.9,
    this.bodyTopMargin = 160,
    required this.createdAt,
  });

  bool get headerIsImage =>
      headerImagePath != null && headerImagePath!.isNotEmpty;
  bool get footerIsImage =>
      footerImagePath != null && footerImagePath!.isNotEmpty;
  bool get hasBackground =>
      backgroundImagePath != null &&
      backgroundImagePath!.isNotEmpty;

  File? get headerImageFile =>
      headerIsImage ? File(headerImagePath!) : null;
  File? get footerImageFile =>
      footerIsImage ? File(footerImagePath!) : null;
  File? get backgroundImageFile =>
      hasBackground ? File(backgroundImagePath!) : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'headerText': headerText,
        'footerText': footerText,
        'headerImagePath': headerImagePath ?? '',
        'footerImagePath': footerImagePath ?? '',
        'backgroundImagePath': backgroundImagePath ?? '',
        'imageMode': imageMode.name,
        'backgroundOpacity': backgroundOpacity,
        'bodyTopMargin': bodyTopMargin,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomTemplate.fromMap(Map<String, dynamic> map) =>
      CustomTemplate(
        id: map['id'] as int?,
        name: map['name'] as String,
        headerText: map['headerText'] as String,
        footerText: map['footerText'] as String,
        headerImagePath:
            (map['headerImagePath'] as String).isEmpty
                ? null
                : map['headerImagePath'] as String,
        footerImagePath:
            (map['footerImagePath'] as String).isEmpty
                ? null
                : map['footerImagePath'] as String,
        backgroundImagePath:
            (map['backgroundImagePath'] as String).isEmpty
                ? null
                : map['backgroundImagePath'] as String,
        imageMode: TemplateImageMode.values.firstWhere(
          (e) => e.name == map['imageMode'],
          orElse: () => TemplateImageMode.zones,
        ),
        backgroundOpacity:
            (map['backgroundOpacity'] as num).toDouble(),
        bodyTopMargin:
            (map['bodyTopMargin'] as num).toDouble(),
        createdAt:
            DateTime.parse(map['createdAt'] as String),
      );

  CustomTemplate copyWith({
    int? id,
    String? name,
    String? headerText,
    String? footerText,
    String? headerImagePath,
    String? footerImagePath,
    String? backgroundImagePath,
    TemplateImageMode? imageMode,
    double? backgroundOpacity,
    double? bodyTopMargin,
    DateTime? createdAt,
  }) =>
      CustomTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        headerText: headerText ?? this.headerText,
        footerText: footerText ?? this.footerText,
        headerImagePath:
            headerImagePath ?? this.headerImagePath,
        footerImagePath:
            footerImagePath ?? this.footerImagePath,
        backgroundImagePath:
            backgroundImagePath ?? this.backgroundImagePath,
        imageMode: imageMode ?? this.imageMode,
        backgroundOpacity:
            backgroundOpacity ?? this.backgroundOpacity,
        bodyTopMargin: bodyTopMargin ?? this.bodyTopMargin,
        createdAt: createdAt ?? this.createdAt,
      );
}