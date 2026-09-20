class ConsultationQueueItem {
  final String patientId;
  final String patientName;
  final int age;
  final String gender;
  final String type;
  String status;
  final String time;
  final String clinicName;

  ConsultationQueueItem({
    required this.patientId,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.type,
    required this.status,
    required this.time,
    this.clinicName = '',
  });
}
