// DTOs = "Data Transfer Objects": plain classes that mirror the JSON the
// backend sends. Field names match the backend (PascalCase) so the mapping is
// obvious. Each class has a `fromJson` that reads one `Map` safely.
//
// Shapes come from `lib/web/src/app/core/models/*` in the Angular reference app.

// ── small helpers so parsing never crashes on missing/typed-wrong fields ──

int readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String readString(Object? value) => value?.toString() ?? '';

String? readStringOrNull(Object? value) => value?.toString();

/// Reads a JSON array into a list of parsed items. Anything that is not a
/// `Map` is skipped.
List<T> readList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return [];
  final result = <T>[];
  for (final item in value) {
    if (item is Map) {
      result.add(fromJson(item.cast<String, dynamic>()));
    }
  }
  return result;
}

Map<String, dynamic> readMap(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

// ── Auth ──────────────────────────────────────────────────────────────────

class RequestOtpDto {
  RequestOtpDto({
    required this.message,
    required this.key,
    required this.mobileNumber,
  });

  final String message;
  final String key;
  final String mobileNumber;

  factory RequestOtpDto.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    return RequestOtpDto(
      message: readString(root['message'] ?? json['message']),
      key: readString(root['key'] ?? json['key']),
      mobileNumber: readString(root['mobileNumber'] ?? json['mobileNumber']),
    );
  }
}

class UserBasicInfoDto {
  UserBasicInfoDto({
    required this.id,
    required this.userName,
    required this.userType, // 'C' | 'P' | 'D'
    required this.recordId,
  });

  final int id;
  final String userName;
  final String userType;
  final int recordId;

  factory UserBasicInfoDto.fromJson(Map<String, dynamic> json) {
    return UserBasicInfoDto(
      id: readInt(json['ID']),
      userName: readString(json['UserName']),
      userType: readString(json['UserType']),
      recordId: readInt(json['RecordId']),
    );
  }
}

class ConfirmOtpDto {
  ConfirmOtpDto({this.user, this.fullInformation, this.token});

  final UserBasicInfoDto? user;

  /// The clinic record OR the doctor record, depending on `user.userType`.
  final Map<String, dynamic>? fullInformation;
  final String? token;

  factory ConfirmOtpDto.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    final userJson = root['userBasicInformation'] ?? json['userBasicInformation'];
    final fullJson = root['userFullInformation'] ?? json['userFullInformation'];
    return ConfirmOtpDto(
      user: userJson is Map
          ? UserBasicInfoDto.fromJson(userJson.cast<String, dynamic>())
          : null,
      fullInformation:
      fullJson is Map ? fullJson.cast<String, dynamic>() : null,
      token: readStringOrNull(root['token'] ?? json['token']),
    );
  }
}

// ── Clinic ────────────────────────────────────────────────────────────────

class ClinicDto {
  ClinicDto({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.mobileNumber,
  });

  final int id;
  final String name;
  final String address;
  final String city;
  final String mobileNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClinicDto && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  factory ClinicDto.fromJson(Map<String, dynamic> json) {
    return ClinicDto(
      id: readInt(json['ID'] ?? json['Id'] ?? json['id']),
      name: readString(json['ClinicName'] ?? json['Name'] ?? json['name']),
      address: readString(json['Address'] ?? json['address']),
      city: readString(json['City'] ?? json['city']),
      mobileNumber: readString(json['MobileNumber'] ?? json['ContactNumer'] ?? json['ContactNumber'] ?? json['mobileNumber']),
    );
  }
}


// ── Schedule (get-doctor-schedules) ──────────────────────────────────────

class MonthlyScheduleItemDto {
  MonthlyScheduleItemDto({
    required this.scheduleId,
    required this.date, // yyyy-MM-dd
    required this.day,
    required this.startTime, // HH:mm[:ss]
    required this.endTime,
    required this.duration,
    required this.status, // ACT | CMP | NEW | RDY | SKP | CNL
    required this.slotsAvailable,
  });

  final int scheduleId;
  final String date;
  final String day;
  final String startTime;
  final String endTime;
  final int duration;
  final String status;
  final int slotsAvailable;

  factory MonthlyScheduleItemDto.fromJson(Map<String, dynamic> json) {
    return MonthlyScheduleItemDto(
      scheduleId: readInt(json['ScheduleId'] ?? json['ID'] ?? json['id']),
      date: readString(json['Date'] ?? json['ScheduleDate']),
      day: readString(json['Day']),
      startTime: readString(json['StartTime']),
      endTime: readString(json['EndTime']),
      duration: readInt(json['Duration'] ?? json['DurationMin']),
      status: readString(json['Status']),
      slotsAvailable: readInt(json['SlotsAvailable']),
    );
  }
}

class ScheduleInfoDto {
  ScheduleInfoDto({
    required this.id,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.doctorName,
    required this.slotCount,
  });

  final int id;
  final String scheduleDate;
  final String startTime;
  final String endTime;
  final String status;
  final String doctorName;
  final int slotCount;

  factory ScheduleInfoDto.fromJson(Map<String, dynamic> json) {
    return ScheduleInfoDto(
      id: readInt(json['ID']),
      scheduleDate: readString(json['ScheduleDate']),
      startTime: readString(json['StartTime']),
      endTime: readString(json['EndTime']),
      status: readString(json['Status']),
      doctorName: readString(json['DoctorName']),
      slotCount: readInt(json['SlotCount']),
    );
  }
}

// ── Doctor dashboard (get-doctor-dashboard) ─────────────────────────────

class DashboardStatusDto {
  DashboardStatusDto({required this.status, required this.count});

  final String status; // BKD | CKD | HLD | VST ...
  final int count;

  factory DashboardStatusDto.fromJson(Map<String, dynamic> json) {
    return DashboardStatusDto(
      status: readString(json['Status'] ?? json['status']),
      count: readInt(json['StatusCount'] ?? json['statusCount'] ?? json['count']),
    );
  }
}

class DashboardAppointmentDto {
  DashboardAppointmentDto({
    required this.appointmentId,
    required this.scheduleId,
    required this.patientId,
    required this.sequenceNo,
    required this.checkInTime,
    required this.patientRemarks,
    required this.patientName,
    required this.address,
    required this.city,
  });

  final int appointmentId;
  final int scheduleId;
  final int patientId;
  final int sequenceNo;
  final String checkInTime;
  final String patientRemarks;
  final String patientName;
  final String address;
  final String city;

  String get location {
    final parts = [address, city].where((s) => s.trim().isNotEmpty);
    return parts.join(', ');
  }

  factory DashboardAppointmentDto.fromJson(Map<String, dynamic> json) {
    final patient = readMap(json['patient']);
    final name = readString(patient['FullName'] ?? json['PatientName'] ?? json['patientName'] ?? json['name']);
    return DashboardAppointmentDto(
      appointmentId:
      readInt(json['ID'] ?? json['AppointmentId'] ?? json['AppointmentID'] ?? json['id']),
      scheduleId: readInt(json['ScheduleID'] ?? json['ScheduleId'] ?? json['scheduleId']),
      patientId: readInt(patient['ID'] ?? json['PatientId'] ?? json['patientId'] ?? json['id']),
      sequenceNo: readInt(json['SequenceNo'] ?? json['sequenceNo']),
      checkInTime: readString(json['CheckInTime'] ?? json['checkInTime'] ?? json['time']),
      patientRemarks: readString(json['PatientRemarks'] ?? json['patientRemarks']),
      patientName: name.isEmpty ? 'Patient' : name,
      address: readString(patient['Address'] ?? json['Address']),
      city: readString(patient['City'] ?? json['City']),
    );
  }
}

class DoctorDashboardDto {
  DoctorDashboardDto({
    required this.summary,
    required this.appointments,
    required this.heldAppointments,
  });

  final List<DashboardStatusDto> summary;
  final List<DashboardAppointmentDto> appointments;
  final List<DashboardAppointmentDto> heldAppointments;

  factory DoctorDashboardDto.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    return DoctorDashboardDto(
      summary: readList(root['dashboardSummary'] ?? json['dashboardSummary'], DashboardStatusDto.fromJson),
      appointments:
      readList(root['appointments'] ?? json['appointments'], DashboardAppointmentDto.fromJson),
      heldAppointments:
      readList(root['heldAppointments'] ?? json['heldAppointments'], DashboardAppointmentDto.fromJson),
    );
  }
}

// ── Patient episode (get-patient-episodes / save-episode) ───────────────

class PatientEpisodeDto {
  PatientEpisodeDto({
    required this.episodeId,
    required this.appointmentId,
    required this.patientId,
    required this.sequenceNo,
    required this.statusId,
    required this.patientRemarks,
    required this.checkInTime,
    required this.chiefComplaint,
    required this.doctorRemarks,
    required this.primaryIcd,
    required this.primaryDesc,
    required this.secondaryIcd,
    required this.secondaryDesc,
    required this.treatmentDate,
  });

  final int episodeId;
  final int appointmentId;
  final int patientId;
  final int sequenceNo;
  final String statusId;
  final String? patientRemarks;
  final String? checkInTime;
  final String? chiefComplaint;
  final String? doctorRemarks;
  final String? primaryIcd;
  final String? primaryDesc;
  final String? secondaryIcd;
  final String? secondaryDesc;
  final String? treatmentDate;

  factory PatientEpisodeDto.fromJson(Map<String, dynamic> json) {
    return PatientEpisodeDto(
      episodeId: readInt(json['EpisodeId']),
      appointmentId: readInt(json['AppointmentId']),
      patientId: readInt(json['PatientId']),
      sequenceNo: readInt(json['SequenceNo']),
      statusId: readString(json['StatusId']),
      patientRemarks: readStringOrNull(json['PatientRemarks']),
      checkInTime: readStringOrNull(json['CheckInTime']),
      chiefComplaint: readStringOrNull(json['ChiefComplaint']),
      doctorRemarks: readStringOrNull(json['DoctorRemarks']),
      primaryIcd: readStringOrNull(json['PrimaryICD']),
      primaryDesc: readStringOrNull(json['PrimaryDesc']),
      secondaryIcd: readStringOrNull(json['SecondaryICD']),
      secondaryDesc: readStringOrNull(json['SecondaryDesc']),
      treatmentDate:
      readStringOrNull(json['TreatementDate'] ?? json['TreatmentDate']),
    );
  }
}

// ── ICD-10 (search-icd-codes) ──────────────────────────────────────────

class IcdCodeDto {
  IcdCodeDto({required this.code, required this.shortDescription});

  final String code;
  final String shortDescription;

  factory IcdCodeDto.fromJson(Map<String, dynamic> json) {
    return IcdCodeDto(
      code: readString(json['ICDCode']),
      shortDescription: readString(json['ShortDescription']),
    );
  }
}

// ── Patient directory (get-patients-with-search) ──────────────────────

class PatientSearchDto {
  PatientSearchDto({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.city,
  });

  final int id;
  final String fullName;
  final String mobileNumber;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String city;

  factory PatientSearchDto.fromJson(Map<String, dynamic> json) {
    return PatientSearchDto(
      id: readInt(json['ID']),
      fullName: readString(json['FullName']),
      mobileNumber: readString(json['MobileNumber']),
      dateOfBirth: readString(json['DateOfBirth']),
      gender: readString(json['Gender']),
      address: readString(json['Address']),
      city: readString(json['City']),
    );
  }
}

class DoctorDetailsDto {
  DoctorDetailsDto({
    required this.id,
    required this.fullName,
    required this.address,
    required this.city,
    required this.speciality,
  });

  final int id;
  final String fullName;
  final String address;
  final String city;
  final String speciality;

  factory DoctorDetailsDto.fromJson(Map<String, dynamic> json) {
    return DoctorDetailsDto(
      id: readInt(json['ID']),
      fullName: readString(json['FullName']),
      address: readString(json['Address']),
      city: readString(json['City']),
      speciality: readString(json['Specility'] ?? json['Speciality']),
    );
  }
}
