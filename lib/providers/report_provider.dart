import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportProvider extends ChangeNotifier {
  final List<PoorLightingReport> _reports = [];

  List<PoorLightingReport> get reports => List.unmodifiable(_reports);

  void addReport(PoorLightingReport report) {
    _reports.add(report);
    notifyListeners();
  }
}
