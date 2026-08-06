import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Production offline-first storage used by IELTS AI Master.
///
/// Text content is stored as JSON-safe maps in Hive. Audio/recordings are kept
/// as normal files and Hive stores only their local paths. Pending writes are
/// retried automatically after connectivity returns.
class OfflineContentService {
  OfflineContentService._();

  static final OfflineContentService instance = OfflineContentService._();

  static const _contentBoxName = 'ielts_content_v2';
  static const _progressBoxName = 'ielts_progress_v2';
  static const _pendingBoxName = 'ielts_pending_v2';
  static const _metaBoxName = 'ielts_meta_v2';

  late Box<dynamic> _contentBox;
  late Box<dynamic> _progressBox;
  late Box<dynamic> _pendingBox;
  late Box<dynamic> _metaBox;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;
  bool _online = true;
  bool _syncing = false;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  Stream<bool> get connectionStream => _onlineController.stream.distinct();
  Stream<bool> get syncStream => _onlineController.stream.distinct();

  Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _contentBox = await Hive.openBox<dynamic>(_contentBoxName);
    _progressBox = await Hive.openBox<dynamic>(_progressBoxName);
    _pendingBox = await Hive.openBox<dynamic>(_pendingBoxName);
    _metaBox = await Hive.openBox<dynamic>(_metaBoxName);
    _initialized = true;

    final initial = await _connectivity.checkConnectivity();
    _setOnline(_hasNetwork(initial));
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasNetwork(results);
      final reconnected = !_online && online;
      _setOnline(online);
      if (reconnected) unawaited(syncPending());
    });

    if (_online) unawaited(syncPending());
  }

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  void _setOnline(bool value) {
    _online = value;
    if (!_onlineController.isClosed) _onlineController.add(value);
  }

  String _contentKey(String module, String id) => '$module::$id';
  String _progressKey(String module, String id) => '$module::$id';

  Future<void> cacheContent({
    required String module,
    required String id,
    required Map<String, dynamic> data,
    String? category,
  }) async {
    await _contentBox.put(_contentKey(module, id), {
      'id': id,
      'module': module,
      'category': category ?? '',
      'data': _jsonSafe(data),
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> cacheMany({
    required String module,
    required Iterable<MapEntry<String, Map<String, dynamic>>> items,
    String? Function(Map<String, dynamic>)? categoryOf,
  }) async {
    final values = <String, dynamic>{};
    for (final item in items) {
      values[_contentKey(module, item.key)] = {
        'id': item.key,
        'module': module,
        'category': categoryOf?.call(item.value) ?? '',
        'data': _jsonSafe(item.value),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
    }
    if (values.isNotEmpty) await _contentBox.putAll(values);
  }

  List<Map<String, dynamic>> cachedContent(
    String module, {
    bool Function(Map<String, dynamic>)? where,
  }) {
    final output = <Map<String, dynamic>>[];
    for (final value in _contentBox.values) {
      if (value is! Map) continue;
      final record = Map<String, dynamic>.from(value);
      if (record['module'] != module) continue;
      final raw = record['data'];
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      data['_offlineId'] = record['id']?.toString() ?? '';
      data['_cachedAt'] = record['cachedAt'];
      if (where == null || where(data)) output.add(data);
    }
    output.sort((a, b) {
      final ao = _toInt(a['order'] ?? a['sequence'], 999999);
      final bo = _toInt(b['order'] ?? b['sequence'], 999999);
      if (ao != bo) return ao.compareTo(bo);
      return _toInt(a['_cachedAt'], 0).compareTo(_toInt(b['_cachedAt'], 0));
    });
    return output;
  }

  Map<String, dynamic>? cachedById(String module, String id) {
    final value = _contentBox.get(_contentKey(module, id));
    if (value is! Map || value['data'] is! Map) return null;
    final data = Map<String, dynamic>.from(value['data'] as Map);
    data['_offlineId'] = id;
    return data;
  }

  Future<void> markCompleted({
    required String module,
    required String contentId,
    Map<String, dynamic> result = const {},
    bool synced = false,
  }) async {
    await _progressBox.put(_progressKey(module, contentId), {
      'module': module,
      'contentId': contentId,
      'completed': true,
      'result': _jsonSafe(result),
      'synced': synced,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Set<String> completedIds(String module) {
    final ids = <String>{};
    for (final value in _progressBox.values) {
      if (value is! Map) continue;
      if (value['module'] == module && value['completed'] == true) {
        final id = value['contentId']?.toString() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  Future<String> queueFirestoreWrite({
    required String operation,
    required String path,
    required Map<String, dynamic> data,
    String? localId,
  }) async {
    final id =
        localId ??
        '${DateTime.now().microsecondsSinceEpoch}_${operation.hashCode.abs()}';
    await _pendingBox.put(id, {
      'id': id,
      'operation': operation,
      'path': path,
      'data': _jsonSafe(data),
      'attempts': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<String> queueWritingEvaluation({
    required String uid,
    required String taskId,
    required Map<String, dynamic> data,
  }) => queueFirestoreWrite(
    operation: 'set',
    path: 'writing_submissions/auto',
    data: {...data, 'userId': uid, 'taskId': taskId},
  );

  Future<String> queueSpeakingEvaluation({
    required String uid,
    required String testId,
    required String recordingPath,
    required Map<String, dynamic> data,
  }) => queueFirestoreWrite(
    operation: 'speaking_upload',
    path: 'speaking_submissions/auto',
    data: {
      ...data,
      'userId': uid,
      'testId': testId,
      'localRecordingPath': recordingPath,
    },
  );

  int get pendingCount => _pendingBox.length;

  Future<void> syncPending() async {
    if (!_initialized || !_online || _syncing || _pendingBox.isEmpty) return;
    _syncing = true;
    try {
      final keys = _pendingBox.keys.toList();
      for (final key in keys) {
        if (!_online) break;
        final raw = _pendingBox.get(key);
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        try {
          await _syncItem(item);
          await _pendingBox.delete(key);
        } catch (_) {
          item['attempts'] = _toInt(item['attempts'], 0) + 1;
          item['lastAttemptAt'] = DateTime.now().millisecondsSinceEpoch;
          await _pendingBox.put(key, item);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    final operation = item['operation']?.toString() ?? 'set';
    final data = Map<String, dynamic>.from(item['data'] as Map? ?? {});
    final hydrated = _firestoreData(data);

    if (operation == 'speaking_upload') {
      final uid = data['userId']?.toString() ?? '';
      final localPath = data['localRecordingPath']?.toString() ?? '';
      final file = File(localPath);
      if (uid.isEmpty || !file.existsSync()) {
        throw StateError('Offline speaking recording is missing.');
      }
      final ref = FirebaseFirestore.instance
          .collection('speaking_submissions')
          .doc();
      final storagePath = 'speaking_recordings/$uid/${ref.id}.m4a';
      final storageRef = FirebaseStorage.instance.ref(storagePath);
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/mp4'),
      );
      final url = await storageRef.getDownloadURL();
      hydrated.remove('localRecordingPath');
      await ref.set({
        ...hydrated,
        'submissionId': ref.id,
        'audioUrl': url,
        'audioStoragePath': storagePath,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final path = item['path']?.toString() ?? '';
    final segments = path.split('/').where((e) => e.isNotEmpty).toList();
    if (segments.length == 2 && segments.last == 'auto') {
      final ref = FirebaseFirestore.instance.collection(segments.first).doc();
      await ref.set({
        ...hydrated,
        if (segments.first == 'writing_submissions') 'submissionId': ref.id,
        'status': hydrated['status'] ?? 'queued',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    if (segments.length.isOdd || segments.isEmpty) {
      throw StateError('Invalid queued Firestore path: $path');
    }
    DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection(segments[0])
        .doc(segments[1]);
    for (var i = 2; i < segments.length; i += 2) {
      ref = ref.collection(segments[i]).doc(segments[i + 1]);
    }
    await ref.set(hydrated, SetOptions(merge: true));
  }

  Future<String?> cacheRemoteAudio({
    required String testId,
    required String url,
  }) async {
    if (url.trim().isEmpty) return null;
    final existing = _metaBox.get('audio::$testId')?.toString();
    if (existing != null && File(existing).existsSync()) return existing;
    if (!_online) return null;

    final directory = await getApplicationSupportDirectory();
    final audioDir = Directory('${directory.path}/offline_audio');
    await audioDir.create(recursive: true);
    final target = File('${audioDir.path}/$testId.mp3');
    final partial = File('${target.path}.part');
    if (partial.existsSync()) await partial.delete();

    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Audio download failed: ${response.statusCode}');
    }
    final sink = partial.openWrite();
    await response.pipe(sink);
    await sink.close();
    if (target.existsSync()) await target.delete();
    await partial.rename(target.path);
    await _metaBox.put('audio::$testId', target.path);
    return target.path;
  }

  String? localAudioPath(String testId) {
    final path = _metaBox.get('audio::$testId')?.toString();
    return path != null && File(path).existsSync() ? path : null;
  }

  Future<void> clearCompletedAudio({int keepLatest = 20}) async {
    final records = <MapEntry<String, String>>[];
    for (final key in _metaBox.keys) {
      final text = key.toString();
      if (!text.startsWith('audio::')) continue;
      final path = _metaBox.get(key)?.toString();
      if (path != null) records.add(MapEntry(text, path));
    }
    if (records.length <= keepLatest) return;
    records.sort((a, b) {
      final af = File(a.value);
      final bf = File(b.value);
      final am = af.existsSync() ? af.lastModifiedSync() : DateTime(1970);
      final bm = bf.existsSync() ? bf.lastModifiedSync() : DateTime(1970);
      return bm.compareTo(am);
    });
    for (final entry in records.skip(keepLatest)) {
      final file = File(entry.value);
      if (file.existsSync()) await file.delete();
      await _metaBox.delete(entry.key);
    }
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is Timestamp)
      return {'__timestamp': value.millisecondsSinceEpoch};
    if (value is DateTime) return {'__timestamp': value.millisecondsSinceEpoch};
    if (value is FieldValue) return null;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    if (value is num || value is bool || value is String || value == null) {
      return value;
    }
    return value.toString();
  }

  dynamic _firestoreData(dynamic value) {
    if (value is Map) {
      if (value.length == 1 && value.containsKey('__timestamp')) {
        return Timestamp.fromMillisecondsSinceEpoch(
          _toInt(value['__timestamp'], DateTime.now().millisecondsSinceEpoch),
        );
      }
      return value.map(
        (key, item) => MapEntry(key.toString(), _firestoreData(item)),
      );
    }
    if (value is Iterable) return value.map(_firestoreData).toList();
    return value;
  }

  int _toInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _onlineController.close();
  }
}
