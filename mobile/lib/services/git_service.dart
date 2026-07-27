import 'dart:io';

class GitFileStatus {
  final String path;
  final String status;
  final bool staged;

  GitFileStatus({
    required this.path,
    required this.status,
    required this.staged,
  });
}

class GitStatus {
  final bool isGitRepo;
  final List<GitFileStatus> files;
  final String currentBranch;

  GitStatus({
    required this.isGitRepo,
    required this.files,
    required this.currentBranch,
  });
}

class GitCommit {
  final String hash;
  final String message;
  final String author;
  final DateTime date;

  GitCommit({
    required this.hash,
    required this.message,
    required this.author,
    required this.date,
  });
}

class GitService {
  static Future<bool> isGitRepo(String path) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--is-inside-work-tree'],
        workingDirectory: path,
      );
      return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<GitStatus> getStatus(String path) async {
    try {
      final repoCheck = await isGitRepo(path);
      if (!repoCheck) {
        return GitStatus(isGitRepo: false, files: [], currentBranch: '');
      }

      final branchResult = await Process.run(
        'git',
        ['branch', '--show-current'],
        workingDirectory: path,
      );
      final currentBranch =
          branchResult.exitCode == 0 ? branchResult.stdout.toString().trim() : '';

      final statusResult = await Process.run(
        'git',
        ['status', '--porcelain'],
        workingDirectory: path,
      );
      if (statusResult.exitCode != 0) {
        return GitStatus(isGitRepo: true, files: [], currentBranch: currentBranch);
      }

      final lines =
          statusResult.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();
      final files = lines.map((line) {
        final indexStatus = line[0];
        final workStatus = line[1];
        final filePath = line.substring(3).trim();

        final staged = indexStatus != ' ' && indexStatus != '?';
        String status;
        if (indexStatus == '?' && workStatus == '?') {
          status = 'untracked';
        } else if (indexStatus == 'A' || workStatus == 'A') {
          status = 'added';
        } else if (indexStatus == 'D' || workStatus == 'D') {
          status = 'deleted';
        } else if (indexStatus == 'R' || workStatus == 'R') {
          status = 'renamed';
        } else if (indexStatus == 'M' || workStatus == 'M') {
          status = 'modified';
        } else {
          status = 'modified';
        }

        return GitFileStatus(path: filePath, status: status, staged: staged);
      }).toList();

      return GitStatus(isGitRepo: true, files: files, currentBranch: currentBranch);
    } catch (_) {
      return GitStatus(isGitRepo: false, files: [], currentBranch: '');
    }
  }

  static Future<String> getDiff(String path, {String? filePath}) async {
    try {
      final args = <String>['diff'];
      if (filePath != null) {
        args.addAll(['--', filePath]);
      }
      final result = await Process.run('git', args, workingDirectory: path);
      if (result.exitCode != 0) return '';

      final cachedArgs = <String>['diff', '--cached'];
      if (filePath != null) {
        cachedArgs.addAll(['--', filePath]);
      }
      final cachedResult = await Process.run(
        'git',
        cachedArgs,
        workingDirectory: path,
      );
      final cachedDiff = cachedResult.exitCode == 0 ? cachedResult.stdout.toString() : '';

      return '${result.stdout}$cachedDiff';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> commit(String path, String message) async {
    try {
      final result = await Process.run(
        'git',
        ['commit', '-m', message],
        workingDirectory: path,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<GitCommit>> getLog(String path, {int limit = 10}) async {
    try {
      final result = await Process.run(
        'git',
        ['log', '--format=%H|%s|%an|%ai', '-n', limit.toString()],
        workingDirectory: path,
      );
      if (result.exitCode != 0) return [];

      final lines =
          result.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();
      return lines.map((line) {
        final parts = line.split('|');
        if (parts.length < 4) return null;
        return GitCommit(
          hash: parts[0],
          message: parts[1],
          author: parts[2],
          date: DateTime.tryParse(parts[3]) ?? DateTime.now(),
        );
      }).whereType<GitCommit>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> add(String path, {String? filePath}) async {
    try {
      final args = ['add'];
      if (filePath != null) {
        args.addAll(['--', filePath]);
      } else {
        args.add('.');
      }
      final result = await Process.run('git', args, workingDirectory: path);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> getBranches(String path) async {
    try {
      final result = await Process.run(
        'git',
        ['branch', '--list'],
        workingDirectory: path,
      );
      if (result.exitCode != 0) return [];

      return result.stdout
          .toString()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .map((l) => l.replaceFirst('*', '').trim())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String> getCurrentBranch(String path) async {
    try {
      final result = await Process.run(
        'git',
        ['branch', '--show-current'],
        workingDirectory: path,
      );
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }
}