import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/sample_timeline_service.dart';

void main() {
  test('generate and export sample growth timeline 90 days json', () async {
    final data = SampleTimelineService.generate90DaySampleJourneyData();
    expect(data['workouts_count'], greaterThan(40));
    expect(data['sets_count'], greaterThan(150));
    expect(data['prs_count'], greaterThan(0));

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final tempDir = await Directory.systemTemp.createTemp('ironlog_test');
    final file = File('${tempDir.path}/sample_growth_timeline_90days.json');
    await file.writeAsString(jsonStr);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(100));
    await tempDir.delete(recursive: true);
  });
}
