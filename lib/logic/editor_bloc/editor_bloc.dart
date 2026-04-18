// editor_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:media_scanner/media_scanner.dart'; 

import 'editor_event.dart';
import 'editor_state.dart';
import 'file_name_service.dart';

import '../../utils/pdf_generator.dart';
import '../../utils/docx_generator.dart';
import '../../services/export_storage_service.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  //Timer? _autoSaveTimer;
  late quill.QuillController controller;
  final ExportStorageService _exportService = ExportStorageService();

  EditorBloc() : super(EditorState(currentFileName: 'Untitled Document')) {
    controller = quill.QuillController.basic();

    on<LoadInitialText>(_onLoadInitialText);
    on<LoadJsonProject>(_onLoadJsonProject);
    on<UpdateDocument>(_onUpdateDocument);
    on<ChangePageSize>((e, emit) => emit(state.copyWith(pageSize: e.size)));
    on<TogglePrintView>((e, emit) => emit(state.copyWith(isPrintView: !state.isPrintView, isHTMLView: false)));
    on<ToggleHTMLView>((e, emit) => emit(state.copyWith(isHTMLView: !state.isHTMLView)));
    on<ToggleToolbar>((e, emit) => emit(state.copyWith(showToolbar: !state.showToolbar)));
    on<ChangeFileName>((e, emit) => emit(state.copyWith(currentFileName: e.newName)));
    on<MarkSaved>((e, emit) => emit(state.copyWith(hasUnsavedChanges: false)));
    on<SelectSaveFormat>((e, emit) => emit(state.copyWith(selectedSaveFormat: e.format)));
    on<RequestSave>(_onRequestSave);
    on<ResolveConflict>(_onResolveConflict);
    on<SaveCompleted>((e, emit) => emit(state.copyWith(saveStatus: SaveStatus.success, hasUnsavedChanges: false)));
    on<SaveFailed>((e, emit) => emit(state.copyWith(saveStatus: SaveStatus.error, saveError: e.error)));
    on<SetHeaderFooter>(_onSetHeaderFooter);

    on<ChangeAlignment>((e, emit) => emit(state.copyWith(alignment: e.alignment)));
    on<ChangeFontSize>((e, emit) => emit(state.copyWith(fontSize: e.fontSize)));
    on<ChangeFontFamily>((e, emit) => emit(state.copyWith(fontFamily: e.fontFamily)));
    on<ToggleBold>((e, emit) => emit(state.copyWith(isBold: !state.isBold)));
    on<ToggleItalic>((e, emit) => emit(state.copyWith(isItalic: !state.isItalic)));
    on<ToggleUnderline>((e, emit) => emit(state.copyWith(isUnderline: !state.isUnderline)));
    on<ChangeMargin>((e, emit) => emit(state.copyWith(marginCm: e.marginCm)));
  }

  // ─────────────────────────────────────────────────────────────
  // LOAD (Unchanged)
  // ─────────────────────────────────────────────────────────────
  void _onLoadInitialText(LoadInitialText event, Emitter<EditorState> emit) {
    final doc = quill.Document()
      ..insert(0, event.text.isEmpty ? '\n' : event.text);
    controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    emit(state.copyWith(
      currentFileName: event.fileName ?? state.currentFileName,
      hasUnsavedChanges: false,
      isJsonProject: false,
      projectFilePath: null,
    ));
  }

  void _onLoadJsonProject(LoadJsonProject event, Emitter<EditorState> emit) {
    try {
      final jsonMap = jsonDecode(event.jsonString) as Map<String, dynamic>;
      final (restoredState, restoredController) =
          EditorState.fromJson(jsonMap, event.sourceFilePath);
      controller = restoredController;
      emit(restoredState);
    } catch (e) {
      emit(state.copyWith(
        saveStatus: SaveStatus.error,
        saveError: 'Failed to open project: $e',
      ));
    }
  }

  void _onUpdateDocument(UpdateDocument event, Emitter<EditorState> emit) {
    emit(state.copyWith(hasUnsavedChanges: true));
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE
  // ─────────────────────────────────────────────────────────────

  Future<void> _onRequestSave(RequestSave event, Emitter<EditorState> emit) async {
    emit(state.copyWith(saveStatus: SaveStatus.saving));
    try {
      // 1. PRE-CREATE ALL PUBLIC FOLDERS (Fixes synchronization bug)
      if (state.selectedSaveFormat != SaveFormat.json) {
        await _exportService.initializePublicFolders();
      }

      final dir = await getApplicationDocumentsDirectory();
      final ext = state.selectedSaveFormat.name;
      
      // 2. Private App Folder Logic
      final folder = Directory('${dir.path}/DocEase/${ext.toUpperCase()}');
      if (!await folder.exists()) await folder.create(recursive: true);

      final fileName = state.currentFileName.isEmpty ? 'Untitled Document' : state.currentFileName;
      final privatePath = '${folder.path}/$fileName.$ext';

      // 1. JSON Specific Logic
      if (state.selectedSaveFormat == SaveFormat.json && state.projectFilePath != null) {
        if (state.projectFilePath != privatePath) {
          final oldFile = File(state.projectFilePath!);
          if (await oldFile.exists()) {
            await oldFile.delete(); 
          }
        }
        await _performFileSave(privatePath, emit);
        add(const SaveCompleted());
        return;
      }

      // 2. Check conflicts in the app's directory
      final suggested = await FileNameService.checkConflict(fileName, ext);
      if (suggested != null) {
        emit(state.copyWith(
          saveStatus: SaveStatus.conflict,
          conflictFileName: fileName,
          suggestedFileName: suggested,
        ));
        return;
      }
      
      // 3. Save primary copy
      await _performFileSave(privatePath, emit);

      // Give the OS a moment to finish writing
      await Future.delayed(const Duration(milliseconds: 300));

      // 4. Backup to Public Storage
      if (state.selectedSaveFormat != SaveFormat.json) {
        await _backupToPublicStorage(privatePath, fileName, ext);
      }

      add(const SaveCompleted());
    } catch (e) {
      add(SaveFailed(e.toString()));
    }
  }

  Future<void> _onResolveConflict(
    ResolveConflict event,
    Emitter<EditorState> emit,
  ) async {
    emit(state.copyWith(saveStatus: SaveStatus.saving));
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = state.selectedSaveFormat.name;
      final folder = Directory('${dir.path}/DocEase/${ext.toUpperCase()}');
      final finalName =
          event.replace ? state.conflictFileName! : state.suggestedFileName!;
      
      final privatePath = '${folder.path}/$finalName.$ext';
      
      // Save primary copy
      await _performFileSave(privatePath, emit);
      emit(state.copyWith(currentFileName: finalName));

      // Backup copy to Public Android Storage
      if (state.selectedSaveFormat != SaveFormat.json) {
        await _backupToPublicStorage(privatePath, finalName, ext);
      }

      add(const SaveCompleted());
    } catch (e) {
      add(SaveFailed(e.toString()));
    }
  }

Future<void> _backupToPublicStorage(String originalPath, String fileName, String ext) async {
    try {
      final formatEnum = SaveFormat.values.firstWhere(
        (f) => f.name == ext, 
        orElse: () => SaveFormat.txt,
      );

      final publicDir = await _exportService.getExportDirectory(formatEnum);
      final publicPath = '${publicDir.path}/$fileName.$ext';
      final File originalFile = File(originalPath);
      
      // Retry loop to ensure file is non-zero
      bool isReady = false;
      for (int i = 0; i < 5; i++) {
        if (await originalFile.exists() && await originalFile.length() > 0) {
          isReady = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (isReady) {
        final bytes = await originalFile.readAsBytes();
        final publicFile = File(publicPath);
        await publicFile.writeAsBytes(bytes, flush: true);
        
        if (Platform.isAndroid) {
          // Scan the specific subfolder and the file
          await MediaScanner.loadMedia(path: publicDir.path); 
          await Future.delayed(const Duration(milliseconds: 100));
          await MediaScanner.loadMedia(path: publicPath);
        }
        debugPrint("Backup successful: $publicPath");
      }
    } catch (e) {
      debugPrint("Backup failed: $e");
    }
  }

  Future<void> _performFileSave(
    String path,
    Emitter<EditorState> emit,
  ) async {
    switch (state.selectedSaveFormat) {
      case SaveFormat.json:
        final jsonMap = state.toJson(controller);
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
        await File(path).writeAsString(jsonString, flush: true);
        
        // Update the project file path so future saves overwrite this new file
        emit(state.copyWith(projectFilePath: path, isJsonProject: true));
        break;

      case SaveFormat.txt:
        await File(path).writeAsString(
          controller.document.toPlainText(),
          flush: true,
        );
        break;

      case SaveFormat.pdf:
        await generatePDF(
          document: controller.document,
          pageSize: state.pageSize.name,
          fontSize: state.fontSize,
          fontFamily: state.fontFamily,
          savePath: path,
          headerText: state.headerText,
          footerText: state.footerText,
          bodyTopMargin: state.bodyTopMargin,
          backgroundImagePath: state.backgroundImagePath,
          backgroundOpacity: state.backgroundOpacity,
          isBold: state.isBold,
          isItalic: state.isItalic,
          isUnderline: state.isUnderline,
          marginCm: state.marginCm,
        );
        break;

      case SaveFormat.docx:
        await generateDocx(
          document: controller.document,
          pageSize: state.pageSize.name,
          fontSize: (state.fontSize * 2).toInt(),
          fontFamily: state.fontFamily,
          savePath: path,
          isBold: state.isBold,
          isItalic: state.isItalic,
          isUnderline: state.isUnderline,
          headerText: state.headerText,
          footerText: state.footerText,
          backgroundImagePath: state.backgroundImagePath,
          marginCm: state.marginCm,
        );
        break;
    }
  }

  void _onSetHeaderFooter(SetHeaderFooter event, Emitter<EditorState> emit) {
    emit(state.copyWith(
      headerText: event.header,
      footerText: event.footer,
      isHeaderFooterLocked: event.locked,
      headerImagePath: event.headerImagePath,
      footerImagePath: event.footerImagePath,
      backgroundImagePath: event.backgroundImagePath,
      backgroundOpacity: event.backgroundOpacity,
      bodyTopMargin: event.bodyTopMargin,
      bgScale: event.bgScale,
      bgOffsetX: event.bgOffsetX,
      bgOffsetY: event.bgOffsetY,
      marginCm: event.marginCm, 
      showHeaderFooter: event.showHeaderFooter,
      pageSize: event.paperSize,
    ));
  }

  @override
  Future<void> close() {
    controller.dispose();
    return super.close();
  }
}