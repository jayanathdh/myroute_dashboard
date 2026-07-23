import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A reusable chat-style timetable composer with local selected-file preview.
class AIUploadSection extends StatelessWidget {
  const AIUploadSection({
    super.key,
    required this.promptController,
    required this.routeNumberController,
    required this.selectedFileBytes,
    required this.selectedFileName,
    required this.selectedFileExtension,
    required this.routeType,
    required this.roadType,
    required this.busType,
    required this.dayType,
    required this.isAnalyzing,
    required this.onImagePressed,
    required this.onPdfPressed,
    required this.onExcelPressed,
    required this.onRemoveFile,
    required this.onRouteTypeChanged,
    required this.onRoadTypeChanged,
    required this.onBusTypeChanged,
    required this.onDayTypeChanged,
    required this.onAnalyze,
  });

  final TextEditingController promptController;
  final TextEditingController routeNumberController;
  final Uint8List? selectedFileBytes;
  final String? selectedFileName;
  final String? selectedFileExtension;
  final String routeType;
  final String roadType;
  final String busType;
  final String dayType;
  final bool isAnalyzing;
  final VoidCallback onImagePressed;
  final VoidCallback onPdfPressed;
  final VoidCallback onExcelPressed;
  final VoidCallback onRemoveFile;
  final ValueChanged<String> onRouteTypeChanged;
  final ValueChanged<String> onRoadTypeChanged;
  final ValueChanged<String> onBusTypeChanged;
  final ValueChanged<String> onDayTypeChanged;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 620;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.auto_awesome_rounded,
            title: 'Upload timetable',
            subtitle:
                'Attach a file, add an optional instruction, then review missing details.',
          ),
          const SizedBox(height: 20),
          _composer(context, isCompact),
          const SizedBox(height: 24),
          const _SectionHeading(
            icon: Icons.tune_rounded,
            title: 'Missing details',
            subtitle:
                'AI will detect these when possible. Select them manually when it cannot.',
          ),
          const SizedBox(height: 16),
          _fallbackFields(),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, bool isCompact) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF222228),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      children: [
        TextField(
          controller: promptController,
          minLines: 4,
          maxLines: 7,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText:
                'Upload a timetable image or describe what AI should look for...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        ),
        if (selectedFileBytes != null) ...[
          const SizedBox(height: 10),
          _SelectedFilePreview(
            bytes: selectedFileBytes!,
            fileName: selectedFileName ?? 'Selected timetable',
            extension: selectedFileExtension,
            onRemove: onRemoveFile,
          ),
        ],
        const SizedBox(height: 10),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 10),
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: _attachmentButtons()),
              const SizedBox(height: 12),
              _AnalyzeButton(isAnalyzing: isAnalyzing, onPressed: onAnalyze),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachmentButtons(),
                ),
              ),
              const SizedBox(width: 12),
              _AnalyzeButton(isAnalyzing: isAnalyzing, onPressed: onAnalyze),
            ],
          ),
      ],
    ),
  );

  Widget _fallbackFields() => LayoutBuilder(
    builder: (context, constraints) {
      final fieldWidth = constraints.maxWidth >= 720
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: routeNumberController,
              decoration: _fieldDecoration(
                'Route No',
                Icons.confirmation_number_outlined,
              ),
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _SelectField(
              label: 'Route Type',
              icon: Icons.alt_route_rounded,
              values: const [
                'Normal Route',
                'Express Route',
                'Intercity Route',
                'School Route',
              ],
              value: routeType,
              onChanged: onRouteTypeChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _SelectField(
              label: 'Road Type',
              icon: Icons.add_road_outlined,
              values: const ['Normal Road', 'Highway', 'Expressway', 'Mixed'],
              value: roadType,
              onChanged: onRoadTypeChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _SelectField(
              label: 'Bus Type',
              icon: Icons.directions_bus_outlined,
              values: const [
                'Normal',
                'Semi Luxury',
                'Luxury',
                'Super Luxury',
                'Express',
              ],
              value: busType,
              onChanged: onBusTypeChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _SelectField(
              label: 'Day Type',
              icon: Icons.calendar_today_outlined,
              values: const [
                'Every Day',
                'Weekdays',
                'Saturday',
                'Sunday',
                'Holiday',
              ],
              value: dayType,
              onChanged: onDayTypeChanged,
            ),
          ),
        ],
      );
    },
  );

  List<Widget> _attachmentButtons() => [
    _AttachmentButton(
      icon: Icons.image_outlined,
      label: 'Image',
      onPressed: onImagePressed,
    ),
    _AttachmentButton(
      icon: Icons.picture_as_pdf_outlined,
      label: 'PDF',
      onPressed: onPdfPressed,
    ),
    _AttachmentButton(
      icon: Icons.table_chart_outlined,
      label: 'Excel',
      onPressed: onExcelPressed,
    ),
  ];

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFF222228),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
      );
}

class _SelectedFilePreview extends StatelessWidget {
  const _SelectedFilePreview({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.onRemove,
  });

  final Uint8List bytes;
  final String fileName;
  final String? extension;
  final VoidCallback onRemove;

  bool get _isImage => const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2635),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFF9B6CFF).withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 48,
            width: 48,
            child: _isImage
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFF393341),
                    child: Icon(
                      extension == 'pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.table_chart_outlined,
                      color: const Color(0xFFC9B4FF),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timetable attached',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove file',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF9B6CFF).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFFC9B4FF), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white70,
      side: const BorderSide(color: Colors.white12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({required this.isAnalyzing, required this.onPressed});
  final bool isAnalyzing;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: isAnalyzing ? null : onPressed,
    icon: isAnalyzing
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.arrow_upward_rounded, size: 18),
    label: Text(isAnalyzing ? 'Analyzing...' : 'Analyze'),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF9B6CFF),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.icon,
    required this.values,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final List<String> values;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFF222228),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white10),
      ),
    ),
    items: values
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
  );
}
