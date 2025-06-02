import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportForm extends StatelessWidget {
  final void Function(PoorLightingReport) onSubmit;
  const ReportForm({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement the form UI and logic
    return const Text('Report Form Placeholder');
  }
}
