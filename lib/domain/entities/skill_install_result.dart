/// Result of a skill dependency installation attempt via skills.install gateway API.
class SkillInstallResult {
  final bool ok;
  final String message;
  final String stdout;
  final String stderr;
  final int? code;
  final List<String> warnings;

  SkillInstallResult({
    required this.ok,
    required this.message,
    required this.stdout,
    required this.stderr,
    this.code,
    this.warnings = const [],
  });

  factory SkillInstallResult.fromJson(Map<String, dynamic> json) {
    return SkillInstallResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      stdout: json['stdout'] as String? ?? '',
      stderr: json['stderr'] as String? ?? '',
      code: json['code'] as int?,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Combined output for display
  String get displayOutput {
    final parts = <String>[];
    if (message.isNotEmpty) parts.add(message);
    if (stdout.isNotEmpty) parts.add(stdout);
    if (stderr.isNotEmpty) parts.add(stderr);
    if (warnings.isNotEmpty) parts.add('Warnings: ${warnings.join(', ')}');
    return parts.join('\n');
  }
}
