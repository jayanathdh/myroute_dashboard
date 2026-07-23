import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'ai_timetable_analysis_service.dart';
import 'ai_upload_section.dart';

/// Main entry page for the AI timetable workflow.
///
/// File selection works now. OCR, Firebase Storage, and Vision AI remain the
/// next integration step and are intentionally not called from this UI.
class AITimetableEnterPage extends StatefulWidget {
  const AITimetableEnterPage({super.key});

  @override
  State<AITimetableEnterPage> createState() => _AITimetableEnterPageState();
}

class _AITimetableEnterPageState extends State<AITimetableEnterPage> {
  String _routeType = 'Normal Route';
  String _roadType = 'Normal Road';
  String _busType = 'Normal';
  String _dayType = 'Every Day';
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _selectedFileExtension;
  bool _isAnalyzing = false;

  final _promptController = TextEditingController();
  final _routeNumberController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    _routeNumberController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTimetableFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      _showMessage('The selected file could not be read. Please try again.');
      return;
    }

    setState(() {
      _selectedFileBytes = file.bytes;
      _selectedFileName = file.name;
      _selectedFileExtension = file.extension?.toLowerCase();
    });
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileExtension = null;
    });
  }

  Future<void> _analyze() async {
    if (_selectedFileBytes == null) {
      _showMessage(
        'Please attach a timetable image, PDF, or Excel file first.',
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await AITimetableAnalysisService().analyze(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName ?? 'timetable',
        fileExtension: _selectedFileExtension,
        prompt: _promptController.text.trim(),
        fallbackRouteNumber: _routeNumberController.text.trim(),
        fallbackRouteType: _routeType,
        fallbackRoadType: _roadType,
        fallbackBusType: _busType,
        fallbackDayType: _dayType,
      );

      if (!mounted) return;
      setState(() {
        if (analysis.routeNo.isNotEmpty)
          _routeNumberController.text = analysis.routeNo;
        if (analysis.routeType.isNotEmpty) _routeType = analysis.routeType;
        if (analysis.roadType.isNotEmpty) _roadType = analysis.roadType;
        if (analysis.busType.isNotEmpty) _busType = analysis.busType;
        if (analysis.dayType.isNotEmpty) _dayType = analysis.dayType;
      });
      _showMessage('Analysis completed. Please review the detected details.');
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'AI analysis could not be completed.');
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'File upload failed.');
    } catch (_) {
      _showMessage('Unable to analyze this timetable. Please try again.');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B6CFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF17171A),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'AI Timetable Enter',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF0F0F0F),
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Timetable Builder',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Attach a timetable and provide any details that are missing from the file.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    AIUploadSection(
                      promptController: _promptController,
                      routeNumberController: _routeNumberController,
                      selectedFileBytes: _selectedFileBytes,
                      selectedFileName: _selectedFileName,
                      selectedFileExtension: _selectedFileExtension,
                      routeType: _routeType,
                      roadType: _roadType,
                      busType: _busType,
                      dayType: _dayType,
                      isAnalyzing: _isAnalyzing,
                      onImagePressed: () =>
                          _pickTimetableFile(['jpg', 'jpeg', 'png', 'webp']),
                      onPdfPressed: () => _pickTimetableFile(['pdf']),
                      onExcelPressed: () =>
                          _pickTimetableFile(['xlsx', 'xls', 'csv']),
                      onRemoveFile: _removeSelectedFile,
                      onRouteTypeChanged: (value) =>
                          setState(() => _routeType = value),
                      onRoadTypeChanged: (value) =>
                          setState(() => _roadType = value),
                      onBusTypeChanged: (value) =>
                          setState(() => _busType = value),
                      onDayTypeChanged: (value) =>
                          setState(() => _dayType = value),
                      onAnalyze: _analyze,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Selected files remain in memory only until Firebase Storage is connected.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
