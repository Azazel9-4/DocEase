import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'editor_event.dart';
import 'editor_state.dart';
import 'file_name_service.dart'; // <-- fix 1: add this import

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  Timer? _autoSaveTimer;

  EditorBloc() : super(EditorState(currentFileName: "Untitled Document")) {

    on<LoadInitialText>((event, emit) {
      emit(state.copyWith(
        text: event.text,
        currentFileName: event.fileName ?? "Untitled Document",
      ));
    });

    on<UpdateText>((event, emit) {
      emit(state.copyWith(
        text: event.fullText,
        hasUnsavedChanges: true,
      ));
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 2), () {
        add(MarkSaved());
      });
    });

    // Formatting
    on<ToggleBold>((event, emit) =>
        emit(state.copyWith(isBold: !state.isBold)));

    on<ToggleItalic>((event, emit) =>
        emit(state.copyWith(isItalic: !state.isItalic)));

    on<ToggleUnderline>((event, emit) =>
        emit(state.copyWith(isUnderline: !state.isUnderline)));

    on<ChangeAlignment>((event, emit) =>
        emit(state.copyWith(alignment: event.alignment)));

    on<ChangeFontSize>((event, emit) =>
        emit(state.copyWith(fontSize: event.size)));

    on<ChangeFontFamily>((event, emit) =>
        emit(state.copyWith(fontFamily: event.font)));

    on<ChangePageSize>((event, emit) =>
        emit(state.copyWith(pageSize: event.size)));

    // View
    on<TogglePrintView>((event, emit) =>
        emit(state.copyWith(isPrintView: !state.isPrintView, isHTMLView: false)));

    on<ToggleHTMLView>((event, emit) =>
        emit(state.copyWith(isHTMLView: !state.isHTMLView)));

    on<ToggleToolbar>((event, emit) =>
        emit(state.copyWith(showToolbar: !state.showToolbar)));

    // File
    on<ChangeFileName>((event, emit) =>
        emit(state.copyWith(currentFileName: event.newName)));

    on<MarkSaved>((event, emit) =>
        emit(state.copyWith(hasUnsavedChanges: false)));

    // Save format selection
    on<SelectSaveFormat>((event, emit) =>
        emit(state.copyWith(selectedSaveFormat: event.format)));

    // Perform the actual save
    on<RequestSave>((event, emit) async {
      emit(state.copyWith(saveStatus: SaveStatus.saving));

      try {
        final dir = await getApplicationDocumentsDirectory();
        final ext = state.selectedSaveFormat.name;
        final folder = Directory('${dir.path}/DocEase/${ext.toUpperCase()}');
        if (!await folder.exists()) await folder.create(recursive: true);

        final fileName = state.currentFileName.isEmpty
            ? 'Untitled Document 1'
            : state.currentFileName;

        final suggested = await FileNameService.checkConflict(fileName, ext);

        if (suggested != null) {
          emit(state.copyWith(
            saveStatus: SaveStatus.conflict, // fix 2: added to enum in editor_state.dart
            conflictFileName: fileName,
            suggestedFileName: suggested,
          ));
          return;
        }

        await File('${folder.path}/$fileName.$ext').writeAsString(state.text);
        add(SaveCompleted());
      } catch (e) {
        add(SaveFailed(e.toString()));
      }
    });

    on<ResolveConflict>((event, emit) async {
      emit(state.copyWith(saveStatus: SaveStatus.saving));

      try {
        final dir = await getApplicationDocumentsDirectory();
        final ext = state.selectedSaveFormat.name;
        final folder = Directory('${dir.path}/DocEase/${ext.toUpperCase()}');

        final finalName = event.replace
            ? state.conflictFileName!
            : state.suggestedFileName!;

        await File('${folder.path}/$finalName.$ext').writeAsString(state.text);

        emit(state.copyWith(currentFileName: finalName));
        add(SaveCompleted());
      } catch (e) {
        add(SaveFailed(e.toString()));
      }
    });

    on<SaveCompleted>((event, emit) =>
        emit(state.copyWith(
          saveStatus: SaveStatus.success,
          hasUnsavedChanges: false,
        )));

    on<SaveFailed>((event, emit) =>
        emit(state.copyWith(
          saveStatus: SaveStatus.error,
          saveError: event.error,
        )));
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }
}