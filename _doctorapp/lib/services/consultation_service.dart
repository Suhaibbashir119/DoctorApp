import 'package:flutter/foundation.dart';

import '../models/consultation_history.dart';
import '../models/consultation_queue_item.dart';
import '../models/patient.dart';

class ConsultationService extends ChangeNotifier {
  final List<Patient> _patients = [];
  final List<ConsultationQueueItem> _consultations = [];
  final List<ConsultationHistory> _history = [];

  List<Patient> get patients => List.unmodifiable(_patients);

  List<ConsultationQueueItem> get allConsultations =>
      List.unmodifiable(_consultations);

  List<ConsultationHistory> get history =>
      List.unmodifiable(_history);

  List<ConsultationQueueItem> get queueItems => _consultations
      .where(
        (item) =>
    item.status == 'Waiting' &&
        item.type != 'Follow-up',
  )
      .toList();

  List<ConsultationQueueItem> get followUpItems => _consultations
      .where(
        (item) =>
    item.status == 'Waiting' &&
        item.type == 'Follow-up',
  )
      .toList();

  List<ConsultationQueueItem> get completedItems => _consultations
      .where((item) => item.status == 'Completed')
      .toList();

  int get totalCount => _consultations.length;

  int get queueCount => queueItems.length;

  int get followUpCount => followUpItems.length;

  int get completedCount => completedItems.length;

  void addPatient(
      Patient patient, {
        required String consultationType,
        String clinicName = '',
      }) {
    _patients.add(patient);

    _consultations.add(
      ConsultationQueueItem(
        patientId: patient.id,
        patientName: patient.name,
        age: patient.age,
        gender: patient.gender,
        type: consultationType,
        status: 'Waiting',
        time: _currentTime(),
        clinicName: clinicName,
      ),
    );

    notifyListeners();
  }

  void addConsultationHistory(
      ConsultationHistory consultation,
      ) {
    _history.insert(0, consultation);
    notifyListeners();
  }

  List<ConsultationHistory> getPatientHistory(
      String patientId,
      ) {
    return _history
        .where((item) => item.patientId == patientId)
        .toList();
  }

  void completeConsultation(String patientId) {
    final index = _consultations.indexWhere(
          (item) => item.patientId == patientId,
    );

    if (index == -1) return;

    _consultations[index].status = 'Completed';

    notifyListeners();
  }

  String _currentTime() {
    final now = DateTime.now();

    final hour = now.hour == 0
        ? 12
        : now.hour > 12
        ? now.hour - 12
        : now.hour;

    final minute = now.minute.toString().padLeft(2, '0');

    final period = now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}

final consultationService = ConsultationService();
