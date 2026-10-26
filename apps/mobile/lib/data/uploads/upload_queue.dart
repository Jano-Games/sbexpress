import 'package:flutter/foundation.dart';

import 'upload_flow.dart';

enum UploadState { waiting, uploading, done, failed }

/// One file to send. [run] reserves, uploads and completes it, reporting
/// progress from 0 to 1; it may be called again to retry.
class UploadJob {
  UploadJob({required this.label, required this.run, this.group});

  /// File name shown in lists.
  final String label;

  /// What the file belongs to, e.g. a document kind or a device category.
  final String? group;
  final Future<void> Function(void Function(double progress) onProgress) run;

  UploadState state = UploadState.waiting;
  double progress = 0;
  String? error;
}

/// Sends files one after another. It is not tied to a screen: the uploads
/// keep going when the screen that started them closes, and a later screen
/// can listen to the same queue.
class UploadQueue extends ChangeNotifier {
  UploadQueue(List<UploadJob> jobs) : jobs = List.unmodifiable(jobs);

  final List<UploadJob> jobs;
  Future<void>? _running;

  int get total => jobs.length;
  int get doneCount =>
      jobs.where((job) => job.state == UploadState.done).length;
  int get failedCount =>
      jobs.where((job) => job.state == UploadState.failed).length;
  bool get finished => jobs.every((job) =>
      job.state == UploadState.done || job.state == UploadState.failed);
  bool get allDone => jobs.every((job) => job.state == UploadState.done);

  /// Share of the work done, counting the file being sent by its progress.
  double get progress {
    if (jobs.isEmpty) return 1;
    var sum = 0.0;
    for (final job in jobs) {
      sum += switch (job.state) {
        UploadState.done => 1,
        UploadState.uploading => job.progress.clamp(0.0, 1.0),
        _ => 0,
      };
    }
    return sum / jobs.length;
  }

  /// Sends every waiting file. Calling it while it runs returns the same run.
  Future<void> start() => _running ??= _drain().whenComplete(() {
        _running = null;
      });

  /// Marks the failed files as waiting again and sends them.
  Future<void> retryFailed() => _retry([
        for (final job in jobs)
          if (job.state == UploadState.failed) job
      ]);

  /// Sends one failed file again.
  Future<void> retry(UploadJob job) =>
      _retry(job.state == UploadState.failed ? [job] : const []);

  Future<void> _retry(List<UploadJob> again) async {
    for (final job in again) {
      job
        ..state = UploadState.waiting
        ..error = null
        ..progress = 0;
    }
    notifyListeners();
    await (_running ?? start());
    // A run that was just ending may have missed the files marked above.
    if (jobs.any((job) => job.state == UploadState.waiting)) await start();
  }

  Future<void> _drain() async {
    while (true) {
      UploadJob? next;
      for (final job in jobs) {
        if (job.state == UploadState.waiting) {
          next = job;
          break;
        }
      }
      if (next == null) return;
      await _send(next);
    }
  }

  Future<void> _send(UploadJob job) async {
    job
      ..state = UploadState.uploading
      ..progress = 0
      ..error = null;
    notifyListeners();
    try {
      await job.run((value) {
        job.progress = value;
        notifyListeners();
      });
      job
        ..state = UploadState.done
        ..progress = 1;
    } catch (error) {
      job
        ..state = UploadState.failed
        ..error = describeUploadError(error);
    }
    notifyListeners();
  }
}
