import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads an attached timetable, then asks the secure Cloud Function to
/// perform OCR/Vision AI analysis. Keep AI credentials in the Cloud Function.
class AITimetableAnalysisService {
  AITimetableAnalysisService({
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  Future<AITimetableAnalysisResult> analyze({
    required Uint8List fileBytes,
    required String fileName,
    required String? fileExtension,
    required String prompt,
    required String fallbackRouteNumber,
    required String fallbackRouteType,
    required String fallbackRoadType,
    required String fallbackBusType,
    required String fallbackDayType,
  }) async {
    final fileId = DateTime.now().microsecondsSinceEpoch;
    final storagePath = 'ai_timetable_uploads/$fileId-$fileName';
    final fileReference = _storage.ref().child(storagePath);

    await fileReference.putData(
      fileBytes,
      SettableMetadata(contentType: _contentType(fileExtension)),
    );
    final fileUrl = await fileReference.getDownloadURL();

    final callable = _functions.httpsCallable('analyzeTimetable');
    final result = await callable.call<Map<String, dynamic>>({
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'prompt': prompt,
      'fallback': {
        'routeNo': fallbackRouteNumber,
        'routeType': fallbackRouteType,
        'roadType': fallbackRoadType,
        'busType': fallbackBusType,
        'dayType': fallbackDayType,
      },
    });

    return AITimetableAnalysisResult.fromMap(result.data);
  }

  String _contentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'csv':
        return 'text/csv';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}

class AITimetableAnalysisResult {
  const AITimetableAnalysisResult({
    required this.routeNo,
    required this.from,
    required this.to,
    required this.routeType,
    required this.roadType,
    required this.busType,
    required this.dayType,
    required this.departureTimes,
  });

  final String routeNo;
  final String from;
  final String to;
  final String routeType;
  final String roadType;
  final String busType;
  final String dayType;
  final List<String> departureTimes;

  factory AITimetableAnalysisResult.fromMap(Map<String, dynamic> map) {
    String value(String key) => (map[key] ?? '').toString().trim();
    final rawTimes = map['departureTimes'];
    final departureTimes = rawTimes is List
        ? rawTimes.map((item) => item.toString()).toList()
        : <String>[];

    return AITimetableAnalysisResult(
      routeNo: value('routeNo'),
      from: value('from'),
      to: value('to'),
      routeType: value('routeType'),
      roadType: value('roadType'),
      busType: value('busType'),
      dayType: value('dayType'),
      departureTimes: departureTimes,
    );
  }
}
