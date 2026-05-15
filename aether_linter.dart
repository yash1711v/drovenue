import 'dart:io';

Future<void> main() async {
  stdout.writeln('===================================================');
  stdout.writeln('Aether Architecture Linter');
  stdout.writeln('===================================================');

  final File pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('CRITICAL ERROR: Not running in a Flutter project root.');
    exitCode = 1;
    return;
  }

  final StringBuffer report = StringBuffer('# Aether Diagnostic Report\n\n');
  final bool analyzePassed = await _runAnalyze(report);
  final bool concurrencyPassed = await _runConcurrencyTest(report);

  final File reportFile = File('ARCHITECTURE_REPORT.md');
  await reportFile.writeAsString(report.toString());
  stdout.writeln('Report saved to ARCHITECTURE_REPORT.md');

  if (!analyzePassed || !concurrencyPassed) {
    exitCode = 1;
  }
}

Future<bool> _runAnalyze(StringBuffer report) async {
  stdout.writeln('Running flutter analyze...');
  final ProcessResult result = await Process.run('flutter', <String>[
    'analyze',
  ]);

  report.writeln('## 1. Code Quality');
  if (result.exitCode == 0) {
    stdout.writeln('Analyzer: PASS');
    report.writeln('PASS: Zero static analysis warnings.');
    report.writeln();
    return true;
  }

  stdout.writeln('Analyzer: FAIL');
  report.writeln('FAIL: Static analysis found issues.');
  report.writeln();
  report.writeln('```text');
  report.writeln(result.stdout.toString().trim());
  report.writeln(result.stderr.toString().trim());
  report.writeln('```');
  report.writeln();
  return false;
}

Future<bool> _runConcurrencyTest(StringBuffer report) async {
  stdout.writeln('Running raid concurrency test...');
  final File testFile = File('test/raid_concurrency_test.dart');
  report.writeln('## 2. Concurrency Outcome');

  if (!testFile.existsSync()) {
    stdout.writeln('Concurrency test: FAIL');
    report.writeln('FAIL: Missing test/raid_concurrency_test.dart.');
    report.writeln();
    return false;
  }

  final ProcessResult result = await Process.run('flutter', <String>[
    'test',
    'test/raid_concurrency_test.dart',
  ]);

  if (result.exitCode == 0) {
    stdout.writeln('Concurrency test: PASS');
    report.writeln('PASS: The 50-request thundering herd capped at 15 slots.');
    report.writeln();
    return true;
  }

  stdout.writeln('Concurrency test: FAIL');
  report.writeln('FAIL: The concurrency proof failed.');
  report.writeln();
  report.writeln('```text');
  report.writeln(result.stdout.toString().trim());
  report.writeln(result.stderr.toString().trim());
  report.writeln('```');
  report.writeln();
  return false;
}
