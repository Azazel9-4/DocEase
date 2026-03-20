import 'package:flutter_bloc/flutter_bloc.dart';
import 'document_event.dart';
import 'document_state.dart';

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  DocumentBloc() : super(const DocumentState(text: '')) {
    
    on<TextChanged>((event, emit) {
      emit(state.copyWith(text: event.text));
    });

    on<ToggleBold>((event, emit) {
      emit(state.copyWith(isBold: !state.isBold));
    });

    on<ChangeFontSize>((event, emit) {
      emit(state.copyWith(fontSize: event.size));
    });
    
    // Add more handlers for Italic, Underline, etc.
  }
}