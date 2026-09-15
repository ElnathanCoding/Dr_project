import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _AbiNative = Uint32 Function();
typedef _AbiDart = int Function();

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _CreateNative = Pointer<Void> Function(Pointer<Utf16>);
typedef _CreateDart = Pointer<Void> Function(Pointer<Utf16>);

typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _DestroyDart = void Function(Pointer<Void>);

typedef _SelfTestNative = Int32 Function(Pointer<Void>, Pointer<Pointer<Utf8>>);
typedef _SelfTestDart = int Function(Pointer<Void>, Pointer<Pointer<Utf8>>);

typedef _AnalyzeNative = Int32 Function(
  Pointer<Void>,
  Pointer<Uint8>,
  UintPtr,
  Pointer<Pointer<Utf8>>,
);
typedef _AnalyzeDart = int Function(
  Pointer<Void>,
  Pointer<Uint8>,
  int,
  Pointer<Pointer<Utf8>>,
);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

class WindowsFullPipeline {
  WindowsFullPipeline._({
    required this.runtimeDirectory,
    required this.openCvVersion,
    required this._library,
    required this._handle,
    required this._destroy,
    required this._selfTest,
    required this._analyze,
    required this._freeString,
  });

  final String runtimeDirectory;
  final String openCvVersion;

  final DynamicLibrary _library;
  Pointer<Void> _handle;

  // Retain the native library object for the lifetime of the
  // pipeline and expose it only for runtime diagnostics.
  DynamicLibrary get nativeLibraryForDiagnostics => _library;

  final _DestroyDart _destroy;
  final _SelfTestDart _selfTest;
  final _AnalyzeDart _analyze;
  final _FreeStringDart _freeString;

  bool get isDisposed => _handle == nullptr;

  static String _join(String directory, String name) {
    if (directory.endsWith(Platform.pathSeparator)) {
      return '$directory$name';
    }

    return '$directory${Platform.pathSeparator}$name';
  }

  static WindowsFullPipeline open({required String runtimeDirectory}) {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsFullPipeline requires Windows.');
    }

    final String dllPath = _join(
      runtimeDirectory,
      'retina_windows_pipeline.dll',
    );

    if (!File(dllPath).existsSync()) {
      throw StateError('Windows pipeline DLL missing: $dllPath');
    }

    final DynamicLibrary library = DynamicLibrary.open(dllPath);

    final _AbiDart abi = library.lookupFunction<_AbiNative, _AbiDart>(
      'RetinaPipelineAbiVersion',
    );

    if (abi() != 1) {
      throw StateError('Unexpected Windows pipeline ABI.');
    }

    final _VersionDart version = library
        .lookupFunction<_VersionNative, _VersionDart>(
          'RetinaPipelineOpenCvVersion',
        );

    final _CreateDart create = library
        .lookupFunction<_CreateNative, _CreateDart>('RetinaPipelineCreate');

    final _DestroyDart destroy = library
        .lookupFunction<_DestroyNative, _DestroyDart>('RetinaPipelineDestroy');

    final _SelfTestDart selfTest = library
        .lookupFunction<_SelfTestNative, _SelfTestDart>(
          'RetinaPipelineSelfTest',
        );

    final _AnalyzeDart analyze = library
        .lookupFunction<_AnalyzeNative, _AnalyzeDart>(
          'RetinaPipelineAnalyzeEncoded',
        );

    final _FreeStringDart freeString = library
        .lookupFunction<_FreeStringNative, _FreeStringDart>(
          'RetinaPipelineFreeString',
        );

    final Pointer<Utf16> runtimeUtf16 = runtimeDirectory.toNativeUtf16();

    Pointer<Void> handle = nullptr;

    try {
      handle = create(runtimeUtf16);
    } finally {
      calloc.free(runtimeUtf16);
    }

    if (handle == nullptr) {
      throw StateError('RetinaPipelineCreate returned nullptr.');
    }

    return WindowsFullPipeline._(
      runtimeDirectory: runtimeDirectory,
      library: library,
      handle: handle,
      destroy: destroy,
      selfTest: selfTest,
      analyze: analyze,
      freeString: freeString,
      openCvVersion: version().toDartString(),
    );
  }

  Map<String, dynamic> selfTest() {
    _requireOpen();

    final Pointer<Pointer<Utf8>> output = calloc<Pointer<Utf8>>();

    try {
      final int status = _selfTest(_handle, output);

      return _consumeJsonResult(
        status: status,
        output: output,
        operation: 'RetinaPipelineSelfTest',
      );
    } finally {
      calloc.free(output);
    }
  }

  Map<String, dynamic> analyzeEncoded(Uint8List encodedBytes) {
    _requireOpen();

    if (encodedBytes.isEmpty) {
      throw ArgumentError('Encoded image bytes are empty.');
    }

    final Pointer<Uint8> input = calloc<Uint8>(encodedBytes.length);

    final Pointer<Pointer<Utf8>> output = calloc<Pointer<Utf8>>();

    try {
      input.asTypedList(encodedBytes.length).setAll(0, encodedBytes);

      final int status = _analyze(_handle, input, encodedBytes.length, output);

      return _consumeJsonResult(
        status: status,
        output: output,
        operation: 'RetinaPipelineAnalyzeEncoded',
      );
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  Map<String, dynamic> _consumeJsonResult({
    required int status,
    required Pointer<Pointer<Utf8>> output,
    required String operation,
  }) {
    final Pointer<Utf8> jsonPointer = output.value;

    String? raw;

    if (jsonPointer != nullptr) {
      try {
        raw = jsonPointer.toDartString();
      } finally {
        _freeString(jsonPointer);
      }
    }

    if (raw == null || raw.isEmpty) {
      throw StateError(
        '$operation returned no JSON. '
        'Native status=$status.',
      );
    }

    final Object? decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('$operation returned unexpected JSON.');
    }

    if (status != 0) {
      throw StateError(
        '$operation failed with native status '
        '$status: ${decoded['error'] ?? raw}',
      );
    }

    return decoded;
  }

  void _requireOpen() {
    if (_handle == nullptr) {
      throw StateError('WindowsFullPipeline is disposed.');
    }
  }

  void dispose() {
    if (_handle == nullptr) {
      return;
    }

    _destroy(_handle);
    _handle = nullptr;
  }
}
