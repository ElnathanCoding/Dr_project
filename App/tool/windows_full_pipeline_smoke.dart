import 'dart:io';

import 'package:dr_package_app/services/windows_full_pipeline.dart';

void main() {
  final String runtimeDirectory = <String>[
    Directory.current.path,
    'windows',
    'retina_runtime',
  ].join(Platform.pathSeparator);

  stdout.writeln('============================================');

  stdout.writeln('RETINA W9 WINDOWS FULL PIPELINE SMOKE');

  stdout.writeln('============================================');

  stdout.writeln();

  final WindowsFullPipeline pipeline = WindowsFullPipeline.open(
    runtimeDirectory: runtimeDirectory,
  );

  try {
    stdout.writeln(
      'OpenCV version: '
      '${pipeline.openCvVersion}',
    );

    final Map<String, dynamic> report = pipeline.selfTest();

    stdout.writeln('Native pipeline create     : PASS');

    stdout.writeln('All five models load       : PASS');

    stdout.writeln(
      'All model zero invokes     : '
      '${report['all_model_zero_invokes'] == true ? 'PASS' : 'FAIL'}',
    );

    stdout.writeln(
      'Synthetic image pipeline   : '
      '${report['synthetic_image_pipeline'] == true ? 'PASS' : 'FAIL'}',
    );

    stdout.writeln(
      'Models loaded              : '
      '${report['models_loaded_n']}',
    );

    stdout.writeln(
      'TensorFlow Lite runtime    : '
      '${report['tensorflow_lite_runtime']}',
    );

    stdout.writeln();

    if (report['status'] != 'PASS') {
      throw StateError('Native W9 self-test did not report PASS.');
    }

    if (report['models_loaded_n'] != 5) {
      throw StateError('Expected exactly five frozen models.');
    }

    if (report['all_model_zero_invokes'] != true) {
      throw StateError('One or more model synthetic invokes failed.');
    }

    if (report['synthetic_image_pipeline'] != true) {
      throw StateError('Synthetic image pipeline failed.');
    }

    if (report['real_image_access'] != false) {
      throw StateError('Unexpected real-image access marker.');
    }

    if (report['locked_test_access'] != false) {
      throw StateError('Unexpected locked-test access marker.');
    }

    stdout.writeln('============================================');

    stdout.writeln('RETINA_W9_FULL_PIPELINE_SMOKE_PASS');

    stdout.writeln('============================================');

    stdout.writeln('REAL IMAGE ACCESS: NO');

    stdout.writeln('LOCKED TEST ACCESS: NO');

    stdout.writeln('WINDOWS SCREENING UNLOCKED: NO');
  } finally {
    pipeline.dispose();
  }
}
