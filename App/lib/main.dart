import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/windows_full_pipeline.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrScreeningApp());
}

class DrScreeningApp extends StatelessWidget {
  const DrScreeningApp({super.key});

  // RETINA frontend color system shared with the website.
  static const Color background = Color(0xFF1E293B);
  static const Color surface = Color(0xFF0F172A);
  static const Color border = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accent = Color(0xFF2DD4BF);

  // Legacy semantic aliases retained to minimize risk to frozen UI logic.
  static const Color navy = textPrimary;
  static const Color teal = accent;
  static const Color cyan = accent;
  static const Color pale = background;
  static const Color ink = textPrimary;
  static const Color muted = textSecondary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: accent,
      surface: surface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DR Screening',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        dividerColor: border,
        iconTheme: const IconThemeData(color: textSecondary),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: border,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: accent,
            foregroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: accent,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          iconColor: accent,
          collapsedIconColor: textSecondary,
          textColor: textPrimary,
          collapsedTextColor: textPrimary,
        ),
      ),
      home: const DrScreeningHome(),
    );
  }
}

class DrScreeningHome extends StatefulWidget {
  const DrScreeningHome({super.key});

  @override
  State<DrScreeningHome> createState() => _DrScreeningHomeState();
}

class _DrScreeningHomeState extends State<DrScreeningHome> {
  // Internal channel name is deliberately unchanged to preserve the
  // already-validated native Android integration.
  static const MethodChannel _channel = MethodChannel(
    'iris.app/native_pipeline',
  );

  static const String _historyKey = 'retina_session_history_v1';
  static const int _maxHistory = 50;

  static const Map<String, String> _modelAssets = <String, String>{
    'GATE1': 'assets/models/IRIS_GATE_MNV2_FLOAT32.tflite',
    'MASTER11': 'assets/models/IRIS_MODALITY_FLOAT32.tflite',
    'GATE2': 'assets/models/IRIS_GATE2_V2_FLOAT32.tflite',
    'MASTER12': 'assets/models/RETINA_MASTER12_V2B_FLOAT32.tflite',
    'E03': 'assets/models/FINAL_E03_SELECT_TF_OPS_FLOAT32.tflite',
  };

  static const List<String> _classLabels = <String>[
    'No apparent DR',
    'Mild NPDR',
    'Moderate NPDR',
    'Severe NPDR',
    'Proliferative DR',
  ];

  final ImagePicker _picker = ImagePicker();
  WindowsFullPipeline? _windowsFullPipeline;

  int _tabIndex = 0;
  File? _selectedImage;
  ImageSource? _selectedSource;
  bool _pipelineReady = false;
  bool _windowsRuntimeVerified = false;
  bool _isAnalyzing = false;
  String _status = 'Starting DR Screening...';

  String _resultTitle = '';
  String _resultDescription = '';
  String _resultAction = '';
  String _resultStage = '';
  List<double> _outputs = <double>[];
  Map<String, dynamic> _rawResult = <String, dynamic>{};
  Map<String, dynamic> _runtimeInfo = <String, dynamic>{};

  List<SessionRecord> _history = <SessionRecord>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializePipeline());
  }

  @override
  void dispose() {
    _windowsFullPipeline?.dispose();
    _windowsFullPipeline = null;
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> items = prefs.getStringList(_historyKey) ?? <String>[];

      final List<SessionRecord> loaded = <SessionRecord>[];
      for (final String raw in items) {
        try {
          final Map<String, dynamic> map = Map<String, dynamic>.from(
            jsonDecode(raw) as Map,
          );
          loaded.add(SessionRecord.fromJson(map));
        } catch (_) {
          // Ignore a malformed local history entry rather than blocking app use.
        }
      }

      if (!mounted) return;
      setState(() => _history = loaded);
    } catch (_) {
      // History is a convenience feature, not part of the medical AI pipeline.
    }
  }

  Future<void> _persistHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> encoded = _history
        .take(_maxHistory)
        .map((SessionRecord record) => jsonEncode(record.toJson()))
        .toList();
    await prefs.setStringList(_historyKey, encoded);
  }

  Future<void> _saveSession(SessionRecord record) async {
    if (!mounted) return;
    setState(() {
      _history = <SessionRecord>[
        record,
        ..._history,
      ].take(_maxHistory).toList();
    });
    await _persistHistory();
  }

  Future<void> _deleteSession(int index) async {
    if (index < 0 || index >= _history.length) return;
    setState(() => _history.removeAt(index));
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear session history?'),
          content: const Text(
            'This removes the locally stored result summaries from this device. '
            'RETINA does not store the retinal images in session history.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (!mounted) return;
    setState(() => _history = <SessionRecord>[]);
  }

  Future<void> _initializePipeline() async {
    if (Platform.isWindows) {
      await _initializeWindowsRuntimeCheckpoint();
      return;
    }

    try {
      setState(() {
        _pipelineReady = false;
        _status = 'Loading screening models...';
      });

      for (final MapEntry<String, String> entry in _modelAssets.entries) {
        final ByteData data = await rootBundle.load(entry.value);
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await _channel.invokeMethod<dynamic>('initModel', <String, dynamic>{
          'name': entry.key,
          'bytes': bytes,
        });
      }

      final dynamic raw = await _channel.invokeMethod<dynamic>('runtimeInfo');
      final Map<String, dynamic> runtime = Map<String, dynamic>.from(
        raw as Map<dynamic, dynamic>,
      );

      final int modelsLoaded =
          (runtime['models_loaded_n'] as num?)?.toInt() ?? 0;

      if (runtime['opencv_ready'] != true) {
        throw StateError('OpenCV failed to initialize.');
      }
      if (runtime['opencv_version'] != '5.0.0') {
        throw StateError(
          'Unexpected OpenCV runtime: ${runtime['opencv_version']}',
        );
      }
      if (modelsLoaded != 5) {
        throw StateError('Expected 5 models, loaded $modelsLoaded.');
      }

      if (!mounted) return;

      setState(() {
        _runtimeInfo = runtime;
        _pipelineReady = true;
        _status = 'Ready';
      });

      // Keep this exact marker for the already-established phone startup check.
      debugPrint('IRIS_APP_DART_READY $runtime');
    } catch (error, stack) {
      debugPrint('IRIS_APP_DART_FATAL $error\n$stack');

      if (!mounted) return;

      setState(() {
        _pipelineReady = false;
        _status = 'Startup failed';
      });

      _showMessage(
        'DR Screening could not initialize its on-device models.\n\n$error',
      );
    }
  }

  Future<void> _initializeWindowsRuntimeCheckpoint() async {
    WindowsFullPipeline? candidate;

    try {
      if (!mounted) return;

      setState(() {
        _pipelineReady = false;
        _windowsRuntimeVerified = false;
        _status = 'Verifying Windows screening pipeline...';
      });

      final String runtimeDirectory =
          File(Platform.resolvedExecutable).parent.path;

      candidate = WindowsFullPipeline.open(
        runtimeDirectory: runtimeDirectory,
      );

      final Map<String, dynamic> report = candidate.selfTest();

      if (report['status'] != 'PASS') {
        throw StateError(
          'Windows full pipeline self-test did not pass: '
          '${report['status']}',
        );
      }

      final String runtimeVersion =
          report['tensorflow_lite_runtime']?.toString() ?? '';
      if (!runtimeVersion.startsWith('2.20.0')) {
        throw StateError(
          'Unexpected Windows TensorFlow Lite runtime: $runtimeVersion',
        );
      }

      if (report['opencv_version'] != '5.0.0') {
        throw StateError(
          'Unexpected Windows OpenCV runtime: '
          '${report['opencv_version']}',
        );
      }

      final int modelsLoaded =
          (report['models_loaded_n'] as num?)?.toInt() ?? 0;
      if (modelsLoaded != 5) {
        throw StateError(
          'Expected 5 Windows screening models, loaded $modelsLoaded.',
        );
      }

      if (report['all_model_zero_invokes'] != true) {
        throw StateError(
          'Windows model invocation self-test did not pass.',
        );
      }

      if (!mounted) {
        candidate.dispose();
        return;
      }

      _windowsFullPipeline?.dispose();
      _windowsFullPipeline = candidate;
      candidate = null;

      setState(() {
        _runtimeInfo = <String, dynamic>{
          ...report,
          'platform': 'Windows',
          'select_tf_ops_ready': true,
          'windows_full_pipeline_ready': true,
          'models_loaded_n': modelsLoaded,
        };
        _windowsRuntimeVerified = true;
        _pipelineReady = true;
        _status = 'Ready';
      });

      debugPrint(
        'RETINA_WINDOWS_FULL_PIPELINE_READY '
        'tflite=$runtimeVersion '
        'opencv=${report['opencv_version']} '
        'models=$modelsLoaded',
      );
    } catch (error, stack) {
      candidate?.dispose();
      _windowsFullPipeline?.dispose();
      _windowsFullPipeline = null;

      debugPrint(
        'RETINA_WINDOWS_RUNTIME_FATAL $error\n$stack',
      );

      if (!mounted) return;

      setState(() {
        _windowsRuntimeVerified = false;
        _pipelineReady = false;
        _status = 'Windows screening pipeline failed';
      });

      _showMessage(
        'The Windows screening pipeline could not be verified.\n\n'
        '$error',
      );
    }
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedImage = File(picked.path);
      _selectedSource = source;
      _clearResult();
      _status = 'Image ready';
    });
  }

  void _clearResult() {
    _resultTitle = '';
    _resultDescription = '';
    _resultAction = '';
    _resultStage = '';
    _outputs = <double>[];
    _rawResult = <String, dynamic>{};
  }

  void _resetAnalysis() {
    setState(() {
      _selectedImage = null;
      _selectedSource = null;
      _clearResult();
      _status = _pipelineReady ? 'Ready' : _status;
    });
  }

  Future<void> _analyze() async {
    if (_selectedImage == null || !_pipelineReady || _isAnalyzing) return;

    try {
      final Stopwatch clientTimer = Stopwatch()..start();

      setState(() {
        _isAnalyzing = true;
        _clearResult();
        _status = 'Checking image...';
      });

      final Stopwatch fileReadTimer = Stopwatch()..start();
      final Uint8List bytes = await _selectedImage!.readAsBytes();
      fileReadTimer.stop();

      final Map<String, dynamic> result;

      if (Platform.isWindows) {
        final WindowsFullPipeline? pipeline = _windowsFullPipeline;
        if (pipeline == null || pipeline.isDisposed) {
          throw StateError('Windows screening pipeline is not ready.');
        }

        result = pipeline.analyzeEncoded(bytes);
      } else {
        final dynamic raw = await _channel.invokeMethod<dynamic>(
          'analyze',
          bytes,
        );

        result = Map<String, dynamic>.from(
          raw as Map<dynamic, dynamic>,
        );
      }
      clientTimer.stop();
      result['file_read_ms'] = fileReadTimer.elapsedMicroseconds / 1000.0;
      result['client_total_ms'] = clientTimer.elapsedMicroseconds / 1000.0;

      final String action = result['final_action']?.toString() ?? 'UNKNOWN';
      final String stage = result['final_stage']?.toString() ?? 'UNKNOWN';

      String title;
      String description;
      List<double> outputs = <double>[];

      if (action == 'E03_RESULT') {
        final int index = (result['e03_index'] as num).toInt();

        outputs = List<dynamic>.from(
          result['e03_probabilities'] as List<dynamic>,
        ).map((dynamic value) => (value as num).toDouble()).toList();

        title = _classLabels[index];
        description =
            'This image passed the automated input checks and reached the five-stage DR classifier.';
      } else {
        title = _stopTitle(action);
        description = _stopDescription(action);
      }

      final SessionRecord session = SessionRecord(
        createdAtIso: DateTime.now().toIso8601String(),
        outcomeTitle: title,
        action: action,
        finalStage: stage,
        source: _selectedSource == ImageSource.camera ? 'Camera' : 'Gallery',
        topOutput: action == 'E03_RESULT' && outputs.isNotEmpty
            ? outputs.reduce((double a, double b) => a > b ? a : b)
            : null,
        runnerUpLabel: action == 'E03_RESULT'
            ? _runnerUpLabelFor(outputs)
            : null,
        runnerUpOutput: action == 'E03_RESULT'
            ? _runnerUpValueFor(outputs)
            : null,
      );

      if (!mounted) return;

      setState(() {
        _rawResult = result;
        _resultAction = action;
        _resultStage = stage;
        _resultTitle = title;
        _resultDescription = description;
        _outputs = outputs;
        _status = action == 'E03_RESULT' ? 'Complete' : 'No DR stage issued';
        _isAnalyzing = false;
      });

      await _saveSession(session);
    } catch (error, stack) {
      debugPrint('IRIS_APP_ANALYZE_FATAL $error\n$stack');

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _status = 'Analysis failed';
      });

      _showMessage('The image could not be analyzed.\n\n$error');
    }
  }

  String? _runnerUpLabelFor(List<double> outputs) {
    final int? index = _runnerUpIndexFor(outputs);
    if (index == null) return null;
    return _classLabels[index];
  }

  double? _runnerUpValueFor(List<double> outputs) {
    final int? index = _runnerUpIndexFor(outputs);
    if (index == null) return null;
    return outputs[index];
  }

  int? _runnerUpIndexFor(List<double> outputs) {
    if (outputs.length < 2) return null;
    final List<int> order = List<int>.generate(
      outputs.length,
      (int index) => index,
    )..sort((int a, int b) => outputs[b].compareTo(outputs[a]));
    return order[1];
  }

  int? get _topIndex {
    if (_outputs.isEmpty) return null;

    int best = 0;
    for (int index = 1; index < _outputs.length; index++) {
      if (_outputs[index] > _outputs[best]) best = index;
    }
    return best;
  }

  int? get _runnerUpIndex => _runnerUpIndexFor(_outputs);

  double? get _topTwoMargin {
    final int? top = _topIndex;
    final int? runnerUp = _runnerUpIndex;
    if (top == null || runnerUp == null) return null;
    return _outputs[top] - _outputs[runnerUp];
  }

  String _stopTitle(String action) {
    switch (action) {
      case 'STOP_NON_FUNDUS':
        return 'Image not supported';
      case 'STOP_MODALITY_BORDERLINE':
      case 'STOP_UNSUPPORTED_MODALITY':
        return 'Unsupported retinal photo type';
      case 'STOP_QUALITY_BORDERLINE':
      case 'STOP_UNGRADABLE':
        return 'Image quality insufficient';
      case 'STOP_SCOPE_BORDERLINE':
      case 'STOP_OUT_OF_SCOPE':
        return 'Outside supported DR scope';
      default:
        return 'No DR stage issued';
    }
  }

  String _stopDescription(String action) {
    switch (action) {
      case 'STOP_NON_FUNDUS':
        return 'The app could not confirm a supported retinal fundus photograph. No DR stage was issued.';
      case 'STOP_MODALITY_BORDERLINE':
      case 'STOP_UNSUPPORTED_MODALITY':
        return 'The image did not match the supported color fundus photography used by this prototype. No DR stage was issued.';
      case 'STOP_QUALITY_BORDERLINE':
      case 'STOP_UNGRADABLE':
        return 'The image did not meet the quality requirement for reliable automated DR staging. No DR stage was issued.';
      case 'STOP_SCOPE_BORDERLINE':
      case 'STOP_OUT_OF_SCOPE':
        return 'The image did not meet the app\'s DR-scope compatibility requirement. No DR stage was issued, and this stop does not diagnose another eye disease.';
      default:
        return 'The automated input pipeline stopped before the DR classifier. No DR stage was issued.';
    }
  }

  String _stopNextStep(String action) {
    switch (action) {
      case 'STOP_NON_FUNDUS':
        return 'Choose a single retinal color fundus photograph and analyze again.';
      case 'STOP_MODALITY_BORDERLINE':
      case 'STOP_UNSUPPORTED_MODALITY':
        return 'Use a supported color fundus photograph rather than OCT, angiography, ultra-widefield, external-eye, or screenshot images.';
      case 'STOP_QUALITY_BORDERLINE':
      case 'STOP_UNGRADABLE':
        return 'Retake the fundus photograph with the retina centered, adequate illumination, good focus, and minimal glare or obstruction. If repeated images remain inadequate, use clinical examination or the appropriate referral pathway.';
      case 'STOP_SCOPE_BORDERLINE':
      case 'STOP_OUT_OF_SCOPE':
        return 'Do not force a DR stage from this image. Review the patient clinically and use the appropriate eye-care assessment. This stop does not identify which other condition may be present.';
      default:
        return 'Review the image and repeat capture or use clinical assessment as appropriate.';
    }
  }

  String _friendlyPipelineStage(String rawStage) {
    switch (rawStage) {
      case 'GATE1':
        return 'Fundus photo check';
      case 'MASTER11':
        return 'Supported photo type check';
      case 'GATE2':
        return 'Image quality check';
      case 'MASTER12':
        return 'DR-scope compatibility check';
      case 'E03':
        return 'DR classifier';
      default:
        return rawStage.isEmpty ? 'Automated input check' : rawStage;
    }
  }

  String _rawScore(String key) {
    final dynamic raw = _rawResult[key];
    if (raw == null) return 'Not reached';
    if (raw is num) return raw.toDouble().toStringAsFixed(8);
    return raw.toString();
  }

  String _rawMs(String key) {
    final dynamic raw = _rawResult[key];
    if (raw == null) return 'Not reached';
    if (raw is num) return '${raw.toDouble().toStringAsFixed(1)} ms';
    return raw.toString();
  }

  List<double> _secondaryAnalysisValues() {
    final dynamic raw = _rawResult['shadow_e03_probabilities'];
    if (raw is! List) return <double>[];

    try {
      return raw
          .map((dynamic value) => (value as num).toDouble())
          .toList();
    } catch (_) {
      return <double>[];
    }
  }

  int? _topIndexFor(List<double> values) {
    if (values.isEmpty) return null;
    int best = 0;
    for (int index = 1; index < values.length; index++) {
      if (values[index] > values[best]) best = index;
    }
    return best;
  }

  String _secondaryHighestOutput() {
    final List<double> values = _secondaryAnalysisValues();
    final int? top = _topIndexFor(values);
    if (top == null || top >= _classLabels.length) {
      return _rawResult['shadow_e03_label']?.toString() ?? 'Not available';
    }
    return '${_classLabels[top]} ${(values[top] * 100).toStringAsFixed(2)}%';
  }

  String _secondaryNextHighestOutput() {
    final List<double> values = _secondaryAnalysisValues();
    final int? runnerUp = _runnerUpIndexFor(values);
    if (runnerUp == null || runnerUp >= _classLabels.length) {
      return 'Not available';
    }
    return '${_classLabels[runnerUp]} ${(values[runnerUp] * 100).toStringAsFixed(2)}%';
  }

  String _shadowOutputs() {
    final List<double> values = _secondaryAnalysisValues();
    if (values.isEmpty) return 'Not run';

    if (values.length != _classLabels.length) {
      return values.map((double v) => v.toStringAsFixed(6)).join(' | ');
    }

    return List<String>.generate(
      values.length,
      (int i) => '${_classLabels[i]} ${(values[i] * 100).toStringAsFixed(1)}%',
    ).join(' | ');
  }

  String _plainGateState(int gatePosition) {
    if (_resultTitle.isEmpty) return 'Not run';

    final int stopPosition = _stopPosition();
    if (_resultAction == 'E03_RESULT') return 'Passed';
    if (gatePosition < stopPosition) return 'Passed';
    if (gatePosition == stopPosition) return 'Stopped here';
    return 'Not reached';
  }

  int _stopPosition() {
    switch (_resultStage) {
      case 'GATE1':
        return 1;
      case 'MASTER11':
        return 2;
      case 'GATE2':
        return 3;
      case 'MASTER12':
        return 4;
      case 'E03':
        return 5;
      default:
        if (_resultAction == 'E03_RESULT') return 5;
        return 1;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('DR Screening'),
          content: Text(message),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/retina_logo_final.png',
                width: 46,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.remove_red_eye_outlined,
                  color: DrScreeningApp.teal,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'DR Screening',
                    style: TextStyle(
                      color: DrScreeningApp.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'RETINA research prototype',
                    style: TextStyle(
                      color: DrScreeningApp.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: <Widget>[
          _buildAnalyzeTab(),
          _buildSessionsTab(),
          _buildLearnTab(),
          _buildAboutTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (int index) {
          setState(() => _tabIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Analyze',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _quickStartCard(),
          const SizedBox(height: 12),
          _systemStatus(),
          const SizedBox(height: 12),
          _imagePanel(),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing || Platform.isWindows
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          if (Platform.isWindows &&
              _windowsRuntimeVerified &&
              !_pipelineReady) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF334155),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.verified_user_outlined,
                    color: DrScreeningApp.navy,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Windows E03 + SELECT_TF_OPS runtime is verified. '
                      'Real-image DR staging remains intentionally locked '
                      'until the fundus, modality, image-quality, '
                      'DR-scope, and frozen preprocessing pipeline has '
                      'been ported and verified for Windows.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: !_pipelineReady || _selectedImage == null || _isAnalyzing
                ? null
                : _analyze,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Image'),
          ),
          if (_isAnalyzing) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_resultTitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _resultCard(),
          ],
        ],
      ),
    );
  }

  Widget _quickStartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.medical_information_outlined,
                  color: DrScreeningApp.teal,
                ),
                SizedBox(width: 8),
                Text(
                  'Quick start',
                  style: TextStyle(
                    color: DrScreeningApp.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _SimpleStep(
              number: '1',
              text: 'Choose one clear color fundus photograph.',
            ),
            const _SimpleStep(number: '2', text: 'Tap Analyze Image.'),
            const _SimpleStep(
              number: '3',
              text: 'Review the DR stage if issued, or follow the retake/review guidance if no result is issued.',
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _showInputGuide,
              icon: const Icon(Icons.help_outline),
              label: const Text('Which images are supported?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _systemStatus() {
    final bool windowsRuntimeOnly =
        Platform.isWindows &&
        _windowsRuntimeVerified &&
        !_pipelineReady;

    final Color color = _pipelineReady
        ? const Color(0xFF2DD4BF)
        : windowsRuntimeOnly
        ? DrScreeningApp.navy
        : const Color(0xFFFBBF24);

    final Color background = _pipelineReady
        ? const Color(0xFF0F172A)
        : windowsRuntimeOnly
        ? const Color(0xFF0F172A)
        : const Color(0xFF0F172A);

    final IconData icon = _pipelineReady
        ? Icons.check_circle_outline
        : windowsRuntimeOnly
        ? Icons.memory_outlined
        : Icons.hourglass_top;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pipelineReady
                  ? 'On-device screening ready'
                  : _status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePanel() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: _selectedImage == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select a fundus image',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.file(_selectedImage!, fit: BoxFit.contain),
            ),
    );
  }

  Widget _resultCard() {
    final bool hasStage = _resultAction == 'E03_RESULT';
    final bool hasSecondary = _rawResult['shadow_e03_research_only'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasStage
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hasStage ? 'DR STAGE OUTPUT' : 'NO DR STAGE ISSUED',
                  style: TextStyle(
                    color: hasStage
                        ? const Color(0xFF2DD4BF)
                        : const Color(0xFFF59E0B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Icon(
              hasStage ? Icons.fact_check_outlined : Icons.shield_outlined,
              size: 34,
              color: hasStage ? DrScreeningApp.teal : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 8),
            Text(
              _resultTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DrScreeningApp.navy,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _resultDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), height: 1.45),
            ),
            if (hasStage) ...<Widget>[
              const SizedBox(height: 14),
              _drOnlyLimitationCard(),
              const SizedBox(height: 12),
              _simpleOutputSummary(),
              const SizedBox(height: 10),
              _simpleInfoExpansion(
                icon: Icons.help_outline,
                title: 'Why this result?',
                children: <Widget>[Text(_whyResultText())],
              ),
              _simpleInfoExpansion(
                icon: Icons.visibility_outlined,
                title: 'What does this stage mean?',
                children: <Widget>[
                  Text(_stageEducation(_resultTitle)),
                  const SizedBox(height: 8),
                  const Text(
                    'This is general ICDR education. It does not mean every listed retinal finding was individually detected by the app.',
                    style: TextStyle(
                      color: DrScreeningApp.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: 14),
              _stopGuidanceCard(),
              if (hasSecondary) ...<Widget>[
                const SizedBox(height: 6),
                _secondaryAnalysisExpansion(),
              ],
            ],
            const SizedBox(height: 8),
            _simpleSafetyChecks(),
            const SizedBox(height: 4),
            _technicalDetailsExpansion(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetAnalysis,
              icon: const Icon(Icons.refresh),
              label: Text(hasStage ? 'Analyze another image' : 'Choose another image'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drOnlyLimitationCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            color: DrScreeningApp.navy,
            size: 20,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'DR-only result: RETINA stages diabetic retinopathy only. This result does not rule out diabetic macular edema or other ocular disease.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.next_plan_outlined,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Recommended next step',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _stopNextStep(_resultAction),
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'An abstention is a no-result decision. It is not a diagnosis of another eye disease.',
            style: TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryAnalysisExpansion() {
    final String rejectedAt = _friendlyPipelineStage(
      _rawResult['shadow_e03_rejected_at']?.toString() ?? _resultStage,
    );

    return _simpleInfoExpansion(
      icon: Icons.science_outlined,
      title: 'Research-only secondary analysis',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Text(
            'The automated input pipeline stopped before a DR stage was issued. For research evaluation only, the DR classifier was also run in the background to study possible false abstentions. This secondary output does not override the stop and must not be used as the issued DR stage.',
            style: TextStyle(
              color: Color(0xFFFBBF24),
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _factRow('Automated stop', rejectedAt),
        _factRow('Highest model output', _secondaryHighestOutput()),
        _factRow('Next highest', _secondaryNextHighestOutput()),
        const SizedBox(height: 6),
        const Text(
          'The values above are model output scores, not guaranteed diagnostic probabilities.',
          style: TextStyle(
            color: DrScreeningApp.muted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _simpleOutputSummary() {
    final int? top = _topIndex;
    final int? runnerUp = _runnerUpIndex;
    final double? margin = _topTwoMargin;

    if (top == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Model output',
            style: TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_classLabels[top]}: ${(_outputs[top] * 100).toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (runnerUp != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Next highest: ${_classLabels[runnerUp]} '
              '${(_outputs[runnerUp] * 100).toStringAsFixed(2)}%',
            ),
          ],
          if (margin != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Top-two difference: ${(margin * 100).toStringAsFixed(2)} percentage points',
              style: const TextStyle(color: DrScreeningApp.muted),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'These are model output scores, not guaranteed diagnostic probabilities. '
            'There is no validated rule such as "below 30% Mild means another stage."',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: DrScreeningApp.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _whyResultText() {
    final int? top = _topIndex;
    if (top == null) {
      return 'The image did not reach the DR classifier.';
    }

    return 'After the image passed the automated input checks, the five-stage '
        'classifier compared its learned retinal image patterns across the '
        'ICDR classes. ${_classLabels[top]} had the highest model output, so '
        'it became the displayed DR stage. Passing the input checks does not '
        'rule out other ocular disease. RETINA does not currently include a '
        'separately validated lesion detector, so it does not claim that a '
        'specific hemorrhage, microaneurysm, or exudate caused this result.';
  }

  Widget _simpleSafetyChecks() {
    return _simpleInfoExpansion(
      icon: Icons.verified_user_outlined,
      title: 'Automated input checks',
      initiallyExpanded: true,
      children: <Widget>[
        _gateRow(
          'Fundus photo',
          'Checks that the input looks like a retinal fundus photograph.',
          _plainGateState(1),
        ),
        _gateRow(
          'Supported photo type',
          'Checks that the retinal image matches the supported color fundus format.',
          _plainGateState(2),
        ),
        _gateRow(
          'Image quality',
          'Checks whether the image is clear enough to continue.',
          _plainGateState(3),
        ),
        _gateRow(
          'DR-scope compatibility',
          'Checks whether the image is sufficiently consistent with the DR-only staging scope. Passing this check does not rule out other ocular disease.',
          _plainGateState(4),
        ),
        _gateRow(
          'DR stage',
          'Runs the five-stage ICDR classifier only after the automated input checks are passed.',
          _resultAction == 'E03_RESULT' ? 'Completed' : 'Not issued',
        ),
      ],
    );
  }

  Widget _gateRow(String title, String explanation, String state) {
    final bool passed = state == 'Passed' || state == 'Completed';
    final bool stopped = state == 'Stopped here';

    final Color color = passed
        ? const Color(0xFF2DD4BF)
        : stopped
        ? const Color(0xFFF59E0B)
        : const Color(0xFF64748B);

    final IconData icon = passed
        ? Icons.check_circle
        : stopped
        ? Icons.stop_circle_outlined
        : Icons.remove_circle_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      state,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  style: const TextStyle(
                    color: DrScreeningApp.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _technicalDetailsExpansion() {
    return _simpleInfoExpansion(
      icon: Icons.code_outlined,
      title: 'Advanced technical details',
      children: <Widget>[
        const Text(
          'These raw scores are provided for research transparency. '
          'Most clinical users do not need them for normal app use.',
          style: TextStyle(color: DrScreeningApp.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        _factRow('Gate 1 score', _rawScore('gate1_score')),
        _factRow('Master 11 score', _rawScore('master11_score')),
        _factRow('Gate 2 score', _rawScore('gate2_score')),
        _factRow('Master 12 score', _rawScore('master12_score')),
        if (_rawResult['shadow_e03_research_only'] == true) ...<Widget>[
          const Divider(height: 24),
          const Text(
            'RESEARCH-ONLY SECONDARY ANALYSIS - this background run does not '
            'override the automated stop and is not the issued DR stage.',
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _factRow(
            'Automated stop',
            _friendlyPipelineStage(
              _rawResult['shadow_e03_rejected_at']?.toString() ?? _resultStage,
            ),
          ),
          _factRow('Highest model output', _secondaryHighestOutput()),
          _factRow('Secondary model index', _rawScore('shadow_e03_index')),
          _factRow('Secondary P0 time', _rawMs('shadow_p0_ms')),
          _factRow('Secondary E03 time', _rawMs('shadow_e03_ms')),
          _factRow('Secondary model outputs', _shadowOutputs()),
        ],
        const Divider(height: 24),
        _factRow('File read time', _rawMs('file_read_ms')),
        _factRow('Decode time', _rawMs('decode_ms')),
        _factRow('224 resize time', _rawMs('resize224_ms')),
        _factRow('Gate 1 time', _rawMs('gate1_ms')),
        _factRow('Master 11 time', _rawMs('master11_ms')),
        _factRow('Gate 2 time', _rawMs('gate2_ms')),
        _factRow('Master 12 time', _rawMs('master12_ms')),
        _factRow('P0 time', _rawMs('p0_ms')),
        _factRow('E03 time', _rawMs('e03_ms')),
        _factRow('Native pipeline total', _rawMs('total_ms')),
        _factRow('Button-to-result total', _rawMs('client_total_ms')),
        _factRow('Final stage', _resultStage),
        _factRow('Action', _resultAction),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: _PageTitle(
                  title: 'Session History',
                  subtitle: 'Recent screening result summaries stored only on this device.',
                ),
              ),
              if (_history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 20,
                  color: DrScreeningApp.teal,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'History stores only result metadata such as date, outcome, '
                    'and top model output. Retinal images and patient identifiers '
                    'are not stored in this history.',
                    style: TextStyle(height: 1.4, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_history.isEmpty)
            _emptyHistory()
          else
            ...List<Widget>.generate(
              _history.length,
              (int index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _historyCard(index, _history[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.history_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 10),
            const Text(
              'No sessions yet',
              style: TextStyle(
                color: DrScreeningApp.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Completed analyses will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DrScreeningApp.muted),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => setState(() => _tabIndex = 0),
              child: const Text('Analyze an image'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(int index, SessionRecord record) {
    final bool isStage = record.action == 'E03_RESULT';
    final Color accent = isStage
        ? DrScreeningApp.teal
        : const Color(0xFFF59E0B);

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          child: Icon(isStage ? Icons.visibility : Icons.shield_outlined),
        ),
        title: Text(
          record.outcomeTitle,
          style: const TextStyle(
            color: DrScreeningApp.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${_formatDate(record.createdAtIso)} - ${record.source}',
        ),
        trailing: IconButton(
          tooltip: 'Delete session',
          onPressed: () => _deleteSession(index),
          icon: const Icon(Icons.delete_outline),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          if (record.topOutput != null)
            _factRow(
              'Top model output',
              '${(record.topOutput! * 100).toStringAsFixed(2)}%',
            ),
          if (record.runnerUpLabel != null && record.runnerUpOutput != null)
            _factRow(
              'Next highest',
              '${record.runnerUpLabel} '
                  '${(record.runnerUpOutput! * 100).toStringAsFixed(2)}%',
            ),
          _factRow('Final action', _friendlyHistoryAction(record.action)),
          const SizedBox(height: 8),
          const Text(
            'No retinal image is stored with this session record.',
            style: TextStyle(color: DrScreeningApp.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  String _friendlyHistoryAction(String action) {
    if (action == 'E03_RESULT') return 'DR stage issued';
    return 'No DR stage issued - automated input stop';
  }

  String _formatDate(String iso) {
    try {
      final DateTime date = DateTime.parse(iso).toLocal();
      final String month = date.month.toString().padLeft(2, '0');
      final String day = date.day.toString().padLeft(2, '0');
      final String hour = date.hour.toString().padLeft(2, '0');
      final String minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}-$month-$day $hour:$minute';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildLearnTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          const _PageTitle(
            title: 'Learn about Diabetic Retinopathy',
            subtitle: 'Short explanations with visual guides. Tap only the topic you need.',
          ),
          const SizedBox(height: 12),
          _visualImageCard(
            'assets/images/what_is_diabetic_retinopathy.png',
            caption: 'Diabetic retinopathy affects the retinal blood vessels and may progress before symptoms are noticed.',
          ),
          const SizedBox(height: 14),
          _sectionLabel('Understanding DR'),
          _learnTile(
            title: 'What is diabetic retinopathy?',
            icon: Icons.visibility_outlined,
            child: const Text(
              'Diabetic retinopathy (DR) is damage to the blood vessels of the retina caused by diabetes. '
              'Over time, damaged retinal vessels may leak, close, bleed, or trigger abnormal new blood-vessel growth. '
              'Early disease may cause no noticeable symptoms.',
              style: TextStyle(height: 1.5),
            ),
          ),
          _learnTile(
            title: 'Risk factors',
            icon: Icons.monitor_heart_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _visualImageCard('assets/images/dr_risk_factors.png'),
                const SizedBox(height: 10),
                const Text(
                  'Risk varies by person. Longer diabetes duration, higher blood glucose, high blood pressure, '
                  'high cholesterol, smoking, and pregnancy with diabetes can increase risk. Regular eye care remains important.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          _learnTile(
            title: 'Symptoms',
            icon: Icons.remove_red_eye_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _visualImageCard('assets/images/dr_symptoms.png'),
                const SizedBox(height: 10),
                const Text(
                  'Early DR may have no symptoms. Later symptoms can include blurred vision, floaters or dark spots, '
                  'dark or empty areas, color-vision changes, or vision loss. No symptoms does not mean no disease.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          _learnTile(
            title: 'Reducing risk and protecting vision',
            icon: Icons.health_and_safety_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _visualImageCard('assets/images/protect_your_vision.png'),
                const SizedBox(height: 10),
                const Text(
                  'Good diabetes management, blood-pressure and cholesterol control, regular dilated eye examinations, '
                  'physical activity, and avoiding smoking can reduce risk or delay progression, but cannot guarantee prevention.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          _learnTile(
            title: 'When should someone seek eye care?',
            icon: Icons.emergency_outlined,
            child: const Text(
              'People with diabetes should follow their eye-care professional\'s recommended examination schedule even when vision feels normal. '
              'Prompt eye care is important for sudden or major visual changes such as new floaters, flashes, blind spots, distortion, or sudden vision loss.',
              style: TextStyle(height: 1.5),
            ),
          ),
          _learnTile(
            title: 'Treatment overview',
            icon: Icons.medication_outlined,
            child: const Text(
              'Treatment depends on severity and clinical findings. Eye-care professionals may use close monitoring, intravitreal medicines such as anti-VEGF therapy, '
              'laser treatment, or surgery. Treatment decisions require a complete clinical eye examination and are not made by this app.',
              style: TextStyle(height: 1.5),
            ),
          ),
          _learnTile(
            title: 'Diabetic macular edema (DME)',
            icon: Icons.center_focus_strong_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _visualImageCard('assets/images/dme_education.png'),
                const SizedBox(height: 10),
                const Text(
                  'DME is swelling of the macula caused by retinal vascular leakage. It can occur at different DR severities and is classified separately from the five-stage ICDR DR severity scale. '
                  'DR Screening / RETINA does not diagnose DME.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel('ICDR severity scale'),
          _visualImageCard(
            'assets/images/icdr_severity_scale.png',
            caption: 'Educational summary of the five ICDR diabetic-retinopathy severity categories.',
          ),
          const SizedBox(height: 10),
          _icdrStageTile(
            stage: 0,
            title: 'No apparent DR',
            description: 'No apparent diabetic-retinopathy abnormalities are seen in the ICDR category. This does not rule out DME or another eye disease.',
            accent: const Color(0xFF4BA6C6),
          ),
          _icdrStageTile(
            stage: 1,
            title: 'Mild NPDR',
            description: 'Microaneurysms only.',
            accent: const Color(0xFF3EB7B0),
          ),
          _icdrStageTile(
            stage: 2,
            title: 'Moderate NPDR',
            description: 'More than microaneurysms alone, but less than the criteria for Severe NPDR.',
            accent: const Color(0xFFE6A523),
          ),
          _icdrStageTile(
            stage: 3,
            title: 'Severe NPDR',
            description: 'No signs of PDR, plus at least one severe 4-2-1 feature: more than 20 intraretinal hemorrhages in each of 4 quadrants, definite venous beading in 2 or more quadrants, or prominent IRMA in 1 or more quadrants.',
            accent: const Color(0xFFF07C2E),
          ),
          _icdrStageTile(
            stage: 4,
            title: 'Proliferative DR',
            description:
                'Neovascularization and/or vitreous or preretinal hemorrhage.',
            accent: const Color(0xFFE84B50),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Retinal findings visual guide'),
          const Text(
            'These are educational illustrations. RETINA does not currently perform lesion-by-lesion detection.',
            style: TextStyle(color: DrScreeningApp.muted, height: 1.4),
          ),
          const SizedBox(height: 9),
          _visualImageCard('assets/images/retinal_findings_visual_guide.png'),
          const SizedBox(height: 9),
          _lesionVisualTile(
            title: 'Microaneurysms',
            summary: 'Tiny focal capillary dilations that can appear as small red dots; they are the defining finding of Mild NPDR in the ICDR scale.',
            asset: 'assets/images/retinal_microaneurysms_screening_guide.png',
          ),
          _lesionVisualTile(
            title: 'Retinal hemorrhages',
            summary: 'Bleeding within retinal tissue; hemorrhages may appear dot-blot or flame-shaped depending on retinal location.',
            asset: 'assets/images/retinal_hemorrhages_screening_card.png',
          ),
          _lesionVisualTile(
            title: 'Hard exudates',
            summary: 'Yellow, relatively well-defined lipid-rich deposits associated with retinal vascular leakage.',
            asset: 'assets/images/hard_exudates_retina_screening_guide.png',
          ),
          _lesionVisualTile(
            title: 'Cotton-wool spots',
            summary: 'Pale, fluffy superficial retinal lesions associated with focal nerve-fiber-layer ischemia.',
            asset: 'assets/images/cotton_wool_spots_retina_guide.png',
          ),
          _lesionVisualTile(
            title: 'Venous beading',
            summary: 'Irregular changes in retinal vein caliber. Definite venous beading in two or more quadrants is one criterion in the Severe NPDR 4-2-1 rule.',
            asset:
                'assets/images/venous_beading_retina_screening_infographic.png',
          ),
          _lesionVisualTile(
            title: 'IRMA',
            summary: 'Intraretinal microvascular abnormalities are abnormal intraretinal vessels near areas of capillary closure. Prominent IRMA in one or more quadrants is one Severe NPDR criterion.',
            asset: 'assets/images/irma_retinal_screening_guide.png',
          ),
          _lesionVisualTile(
            title: 'Neovascularization',
            summary: 'Fragile abnormal new vessels caused by retinal ischemia. Neovascularization is a defining feature of proliferative DR.',
            asset: 'assets/images/neovascularization_retina_screening_card.png',
          ),
          const SizedBox(height: 14),
          _sectionLabel('What this app can and cannot classify'),
          _visualImageCard('assets/images/retina_scope_guide.png'),
          const SizedBox(height: 10),
          _scopeCard(),
        ],
      ),
    );
  }

  Widget _visualImageCard(String asset, {String? caption}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Image.asset(
                asset,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 160,
                  alignment: Alignment.center,
                  color: const Color(0xFF1E293B),
                  child: const Text('Educational visual unavailable'),
                ),
              ),
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.all(11),
              child: Text(
                caption,
                style: const TextStyle(
                  color: DrScreeningApp.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lesionVisualTile({
    required String title,
    required String summary,
    required String asset,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(
            Icons.remove_red_eye_outlined,
            color: DrScreeningApp.teal,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            _visualImageCard(asset),
            const SizedBox(height: 10),
            Text(summary, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            const Text(
              'Educational illustration only. This app does not currently report a case-specific detection of this lesion.',
              style: TextStyle(
                color: DrScreeningApp.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icdrStageTile({
    required int stage,
    required String title,
    required String description,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ExpansionTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(painter: RetinaStagePainter(stage: stage)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 5),
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            SizedBox(
              height: 175,
              child: CustomPaint(
                painter: RetinaStagePainter(stage: stage),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            const Text(
              'Simplified educational illustration - not a diagnostic fundus image.',
              style: TextStyle(color: DrScreeningApp.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'DR Screening is designed for',
              style: TextStyle(
                color: DrScreeningApp.navy,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 9),
            const _CheckLine('No apparent DR'),
            const _CheckLine('Mild NPDR'),
            const _CheckLine('Moderate NPDR'),
            const _CheckLine('Severe NPDR'),
            const _CheckLine('Proliferative DR'),
            const Divider(height: 26),
            const Text(
              'It does not diagnose',
              style: TextStyle(
                color: DrScreeningApp.navy,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 9),
            const _CrossLine('Diabetic macular edema (DME)'),
            const _CrossLine('Glaucoma'),
            const _CrossLine('Age-related macular degeneration'),
            const _CrossLine('Retinal detachment'),
            const _CrossLine('Retinal artery or vein occlusion'),
            const _CrossLine('Hypertensive retinopathy'),
            const _CrossLine('Cataract or other non-DR eye disease'),
            const SizedBox(height: 8),
            const Text(
              'RETINA is not a general retinal-disease detector. Passing the DR-scope '
              'compatibility check does not rule out another ocular condition. If the '
              'scope check stops an image, it also does not identify which other condition may be present.',
              style: TextStyle(
                color: DrScreeningApp.muted,
                height: 1.4,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _aboutHeader(),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'How to use DR Screening',
            icon: Icons.help_outline,
            children: const <Widget>[
              _SimpleStep(number: '1', text: 'Choose Gallery or Camera.'),
              _SimpleStep(
                number: '2',
                text: 'Use one clear supported color fundus photograph.',
              ),
              _SimpleStep(number: '3', text: 'Tap Analyze Image.'),
              _SimpleStep(
                number: '4',
                text: 'Review the DR stage if issued, or follow the no-result guidance.',
              ),
              _SimpleStep(
                number: '5',
                text: 'Use the result as research decision support only - not as a stand-alone diagnosis.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Research Group',
            icon: Icons.groups_outlined,
            children: const <Widget>[
              _ContactLine('Elnathan Rosero Perez', 'perezelnathan5@gmail.com'),
              _ContactLine(
                'Lorenzo Eugene Lumacon Sapong',
                'enzorenzyrenzgene2@gmail.com',
              ),
              _ContactLine('Cheleen Lumbo Chu', 'cheleenchu@gmail.com'),
              _ContactLine(
                'Tristan Drew Sandiego Tiongson',
                'tristantiongson2@gmail.com',
              ),
              _ContactLine(
                'Luzia Anne Villa-Abrille Rasonabe',
                'luziaannerasonabe@gmail.com',
              ),
              _ContactLine('Richard Jayme Chu Jr', 'richardjrchu@gmail.com'),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Research Teacher',
            icon: Icons.school_outlined,
            children: const <Widget>[
              _ContactLine(
                'Sherwin S. Fortugaliza',
                'sherwinfortugaliza00@gmail.com',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'School',
            icon: Icons.account_balance_outlined,
            children: const <Widget>[
              _FactLine('Section', '12-Dalton STEM'),
              _FactLine('School', 'Davao City National High School (DCNHS)'),
              _FactLine('Location', 'Davao City, Philippines'),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Privacy',
            icon: Icons.privacy_tip_outlined,
            children: const <Widget>[
              _CheckLine('AI inference runs locally on the device.'),
              _CheckLine('No cloud inference server is required.'),
              _CheckLine('Session history does not store retinal images.'),
              _CheckLine('Do not enter patient names or other identifiers.'),
              SizedBox(height: 6),
              Text(
                'Session history stores non-identifying result metadata locally '
                'for convenience and can be cleared from the Sessions tab.',
                style: TextStyle(color: DrScreeningApp.muted, height: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _modelResearchExpansion(),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Research-use disclaimer',
            icon: Icons.gavel_outlined,
            children: const <Widget>[
              Text(
                'DR Screening / RETINA is a student research prototype. It has '
                'not been approved as a medical device and must not be used as '
                'the sole basis for diagnosis, treatment, referral, or other '
                'patient-care decisions. Clinical responsibility remains with '
                'qualified eye-care professionals.',
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aboutHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/retina_logo_final.png',
                width: 112,
                height: 76,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 70,
                  color: DrScreeningApp.teal,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'DR Screening',
                    style: TextStyle(
                      color: DrScreeningApp.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'RETINA',
                    style: TextStyle(
                      color: DrScreeningApp.teal,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Offline diabetic retinopathy staging research prototype with automated input checks.',
                    style: TextStyle(color: DrScreeningApp.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelResearchExpansion() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.biotech_outlined, color: DrScreeningApp.teal),
        title: const Text(
          'Model & research information',
          style: TextStyle(
            color: DrScreeningApp.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Optional technical information for researchers and reviewers.',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _visualImageCard('assets/images/how_retina_works.png'),
          const SizedBox(height: 12),
          _learnTileBody(
            title: 'Automated input pipeline in plain language',
            body:
                '1. Fundus check: rejects non-retinal images.\n'
                '2. Supported photo type: confirms the supported color-fundus modality.\n'
                '3. Image quality: stops images that are not sufficiently gradable.\n'
                '4. DR-scope compatibility: reduces forced DR staging of some images outside the intended scope, but is not a general detector for other eye diseases.\n'
                '5. E03: assigns one of the five ICDR DR stages only after the automated input checks are passed.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'E03 classifier',
            body: 'E03 uses an ImageNet-pretrained EfficientNetB2 classifier with 512 x 512 RGB input and five output classes: No apparent DR, Mild NPDR, Moderate NPDR, Severe NPDR, and Proliferative DR. No additional E03 confidence-abstention threshold is deployed.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'Official held-out E03 evaluation',
            body:
                'Locked held-out test: 702 images.\n'
                'Accuracy: 89.03%\n'
                'Balanced accuracy: 81.64%\n'
                'Macro F1: 0.806\n'
                'Weighted F1: 0.894\n'
                'Quadratic weighted kappa: 0.956\n'
                'Macro AUROC: 0.979\n'
                'Macro AUPRC: 0.850\n\n'
                'Per-class recall: No apparent DR 94.20%, Mild NPDR 74.51%, Moderate NPDR 92.66%, Severe NPDR 62.86%, Proliferative DR 83.96%.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'Input-check evaluation notes',
            body: 'Gate 1 is a MobileNetV2 fundus/non-fundus guard. Master 11 is a MobileNetV2 supported-modality guard. Gate 2 is intentionally conservative: in its locked evaluation, specificity for rejecting ungradable images was 95.91%, false-acceptance rate 4.09%, and gradable sensitivity 30.0%. Master 12 V2B is a MobileNetV3Small DR-scope compatibility guard. At its frozen development-selected threshold of 0.475, E03-development image acceptance was 100.00%, RFMiD supported acceptance 90.28%, PASS_NORMAL acceptance 92.54%, PASS_DR_ONLY acceptance 86.42%, true-pathology rejection 61.18%, and DR-plus-confounder rejection 39.39%. These Master 12 V2B figures are development metrics used for operating-point selection, not an independent final validation. A scope stop does not diagnose another disease, and passing the scope check does not rule other diseases out.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'Known limitations',
            body: 'Performance differs by class. Severe NPDR had lower held-out recall than several other classes. Mild NPDR is also challenging. Errors can occur between neighboring ICDR stages. Raw softmax values are not guaranteed diagnostic probabilities. RETINA does not currently provide validated lesion localization, DME diagnosis, or diagnosis of other retinal diseases.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'Research-only secondary analysis',
            body: 'When an automated input check stops an image, RETINA may run E03 in the background for research evaluation of false abstentions. This secondary output is never the issued DR stage, does not override the stop, and should not be used for patient-care decisions. Internal diagnostic field names are retained only for research continuity.',
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'On-device runtime',
            body:
                'TensorFlow Lite: ${_runtimeInfo['tensorflow_lite_runtime'] ?? '2.16.1 target'}\n'
                'OpenCV: ${_runtimeInfo['opencv_version'] ?? '5.0.0'}\n'
                'SELECT_TF_OPS: required for E03\n'
                "Interpreter threads: ${_runtimeInfo['interpreter_threads'] ?? 4}",
          ),
          const SizedBox(height: 10),
          _learnTileBody(
            title: 'Frozen operating thresholds',
            body:
                'Gate 1 accept: 0.5001319401850001\n'
                'Master 11 effective accept: 0.00010095704353952897\n'
                'Gate 2 accept: 0.7849430871963501\n'
                'Master 12 V2B accept: 0.475\n\n'
                'These are frozen research operating points and are not changed by the app UI.',
          ),
        ],
      ),
    );
  }

  Widget _learnTileBody({required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }

  void _showInputGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (BuildContext context, ScrollController controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
              children: <Widget>[
                const Text(
                  'Supported image guide',
                  style: TextStyle(
                    color: DrScreeningApp.navy,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use one clear color fundus photograph. The retinal field should be reasonably centered, visible, focused, and adequately illuminated.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 14),
                _visualImageCard('assets/images/accepted_image_guide.png'),
                const SizedBox(height: 12),
                _visualImageCard('assets/images/rejected_image_guide.png'),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Good input',
                  icon: Icons.check_circle_outline,
                  children: const <Widget>[
                    _CheckLine('Single color fundus photograph'),
                    _CheckLine('Standard or supported portable CFP'),
                    _CheckLine('Retinal field visible'),
                    _CheckLine('Reasonable focus and illumination'),
                    _CheckLine('Minimal glare or obstruction'),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Do not use',
                  icon: Icons.block_outlined,
                  children: const <Widget>[
                    _CrossLine('OCT scans'),
                    _CrossLine('Ultra-widefield retinal images'),
                    _CrossLine('Fluorescein angiography'),
                    _CrossLine('External-eye or slit-lamp photos'),
                    _CrossLine('Screenshots, collages, or ordinary photos'),
                    _CrossLine('Severely blurred or obstructed images'),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _learnTile({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: ExpansionTile(
          leading: Icon(icon, color: DrScreeningApp.teal),
          title: Text(
            title,
            style: const TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            Align(alignment: Alignment.centerLeft, child: child),
          ],
        ),
      ),
    );
  }

  Widget _simpleInfoExpansion({
    required IconData icon,
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon, color: DrScreeningApp.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: DrScreeningApp.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: DrScreeningApp.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.05,
        ),
      ),
    );
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: DrScreeningApp.muted),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _stageEducation(String title) {
    switch (title) {
      case 'No apparent DR':
        return 'No apparent diabetic-retinopathy abnormalities are seen in the ICDR category. '
            'This does not rule out DME or another eye disease.';
      case 'Mild NPDR':
        return 'Microaneurysms only.';
      case 'Moderate NPDR':
        return 'More than microaneurysms alone, but less than Severe NPDR.';
      case 'Severe NPDR':
        return 'No PDR signs and at least one severe 4-2-1 feature: more than '
            '20 intraretinal hemorrhages in each of 4 quadrants, definite venous '
            'beading in 2 or more quadrants, or prominent IRMA in 1 or more quadrants.';
      case 'Proliferative DR':
        return 'Neovascularization and/or vitreous or preretinal hemorrhage.';
      default:
        return 'DR Screening uses the five-stage ICDR diabetic-retinopathy severity framework.';
    }
  }
}

class SessionRecord {
  const SessionRecord({
    required this.createdAtIso,
    required this.outcomeTitle,
    required this.action,
    required this.finalStage,
    required this.source,
    this.topOutput,
    this.runnerUpLabel,
    this.runnerUpOutput,
  });

  final String createdAtIso;
  final String outcomeTitle;
  final String action;
  final String finalStage;
  final String source;
  final double? topOutput;
  final String? runnerUpLabel;
  final double? runnerUpOutput;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'createdAtIso': createdAtIso,
      'outcomeTitle': outcomeTitle,
      'action': action,
      'finalStage': finalStage,
      'source': source,
      'topOutput': topOutput,
      'runnerUpLabel': runnerUpLabel,
      'runnerUpOutput': runnerUpOutput,
    };
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      outcomeTitle: json['outcomeTitle']?.toString() ?? 'Session',
      action: json['action']?.toString() ?? 'UNKNOWN',
      finalStage: json['finalStage']?.toString() ?? 'UNKNOWN',
      source: json['source']?.toString() ?? 'Unknown',
      topOutput: (json['topOutput'] as num?)?.toDouble(),
      runnerUpLabel: json['runnerUpLabel']?.toString(),
      runnerUpOutput: (json['runnerUpOutput'] as num?)?.toDouble(),
    );
  }
}

class RetinaStagePainter extends CustomPainter {
  const RetinaStagePainter({required this.stage});

  final int stage;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.shortestSide * 0.43;

    final Paint retinaPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFA52B),
          Color(0xFFE96E1B),
          Color(0xFFB53A16),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, retinaPaint);

    final Offset disc = Offset(
      center.dx - radius * 0.5,
      center.dy - radius * 0.02,
    );

    canvas.drawCircle(
      disc,
      radius * 0.16,
      Paint()..color = const Color(0xFFFFD96A),
    );

    final Paint vessel = Paint()
      ..color = const Color(0xFF8A261D)
      ..strokeWidth = size.shortestSide * 0.012
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = -3; i <= 3; i++) {
      final double spread = i * radius * 0.17;
      final Path path = Path()
        ..moveTo(disc.dx + radius * 0.08, disc.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy + spread * 0.35,
          center.dx + radius * 0.8,
          center.dy + spread,
        );
      canvas.drawPath(path, vessel);
    }

    canvas.drawCircle(
      Offset(center.dx + radius * 0.28, center.dy),
      radius * 0.07,
      Paint()..color = const Color(0xFF9C2F20).withValues(alpha: 0.55),
    );

    final Paint redDot = Paint()..color = const Color(0xFF8B0000);
    final Paint yellow = Paint()..color = const Color(0xFFFFD83D);
    final Paint darkRed = Paint()..color = const Color(0xFF6D0C0C);

    void dot(double x, double y, double r, Paint paint) {
      canvas.drawCircle(
        Offset(center.dx + radius * x, center.dy + radius * y),
        radius * r,
        paint,
      );
    }

    if (stage >= 1) {
      dot(0.20, -0.20, 0.025, redDot);
      dot(0.43, 0.18, 0.022, redDot);
    }

    if (stage >= 2) {
      dot(0.50, -0.30, 0.045, darkRed);
      dot(0.15, 0.40, 0.040, darkRed);
      dot(-0.05, -0.45, 0.030, redDot);
      dot(0.35, -0.04, 0.030, yellow);
      dot(0.46, 0.02, 0.026, yellow);
      dot(0.28, 0.08, 0.022, yellow);
    }

    if (stage >= 3) {
      dot(-0.05, 0.58, 0.055, darkRed);
      dot(0.68, 0.10, 0.050, darkRed);
      dot(0.10, -0.63, 0.050, darkRed);
      dot(0.58, -0.52, 0.045, darkRed);
      dot(-0.35, -0.48, 0.035, redDot);
    }

    if (stage >= 4) {
      final Paint neo = Paint()
        ..color = const Color(0xFFD4145A)
        ..strokeWidth = size.shortestSide * 0.008
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 8; i++) {
        final Path path = Path()
          ..moveTo(disc.dx, disc.dy)
          ..quadraticBezierTo(
            disc.dx + radius * 0.18 * (i.isEven ? 1 : -1),
            disc.dy + radius * 0.18 * (i % 3 - 1),
            disc.dx + radius * 0.35 * (i.isEven ? 1 : -1),
            disc.dy + radius * 0.28 * (i % 2 == 0 ? 1 : -1),
          );
        canvas.drawPath(path, neo);
      }
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.012
        ..color = const Color(0xFF8F331E),
    );
  }

  @override
  bool shouldRepaint(covariant RetinaStagePainter oldDelegate) {
    return oldDelegate.stage != stage;
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: DrScreeningApp.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: DrScreeningApp.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _SimpleStep extends StatelessWidget {
  const _SimpleStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DrScreeningApp.teal,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF2DD4BF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _CrossLine extends StatelessWidget {
  const _CrossLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.close, color: Color(0xFFB85045), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine(this.name, this.email);

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            style: const TextStyle(
              color: DrScreeningApp.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            email,
            style: const TextStyle(color: DrScreeningApp.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                color: DrScreeningApp.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: DrScreeningApp.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

