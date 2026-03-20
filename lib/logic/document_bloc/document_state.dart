import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class DocumentState extends Equatable {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final double fontSize;
  final TextAlign alignment;

  const DocumentState({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize = 12.0,
    this.alignment = TextAlign.left,
  });

  DocumentState copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    double? fontSize,
    TextAlign? alignment,
  }) {
    return DocumentState(
      text: text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      fontSize: fontSize ?? this.fontSize,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  List<Object> get props => [text, isBold, isItalic, isUnderline, fontSize, alignment];
}