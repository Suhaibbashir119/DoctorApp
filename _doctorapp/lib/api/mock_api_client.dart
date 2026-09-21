import 'api_client.dart';
import 'api_config.dart';
import 'api_endpoints.dart';
import 'api_response.dart';
import 'backend_codes.dart';

/// A fake backend that lives entirely in memory.
///
/// It answers the exact same endpoints as the real server (see [ApiEndpoints])
/// with the same JSON shape, and keeps mutable state so hold / complete / save
/// actually change the queue. Used for the demo build and the tests.
class MockApiClient implements ApiClient {
  final _MockDb _db = _MockDb();

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    await _latency();
    final q = query ?? const {};

    switch (_pathOnly(path)) {
      case ApiEndpoints.getClinics:
        return _ok(_db.clinics);
      case ApiEndpoints.getClinicDetails:
        return _ok(_db.clinicById(_toInt(q['clinicID'])));
      case ApiEndpoints.getDoctorSchedules:
        return _ok(_db.doctorSchedules());
      case ApiEndpoints.getScheduleInfo:
        return _ok(_db.scheduleInfo(_toInt(q['ScheduleID'])));
      case ApiEndpoints.getDoctorDashboard:
        return _ok(_db.doctorDashboard(_toInt(q['scheduleId'])));
      case ApiEndpoints.getPatientEpisodes:
        return _ok(_db.episodesForPatient(_toInt(q['patientID'])));
      case ApiEndpoints.searchIcdCodes:
        return _ok(_db.searchIcd('${q['searchTerm'] ?? ''}'));
      case ApiEndpoints.getPatientsWithSearch:
        return _ok(_db.searchPatients(
          '${q['searchTerm'] ?? ''}',
          _toInt(q['pageNum'], 1),
          _toInt(q['limit'], 20),
        ));
      case ApiEndpoints.getDoctorDetails:
        return _ok(_db.doctorDetails());
      default:
        throw ApiException('Mock: unhandled GET $path', statusCode: 404);
    }
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    await _latency();
    final data = (body is Map) ? body.cast<String, dynamic>() : <String, dynamic>{};

    switch (_pathOnly(path)) {
      case ApiEndpoints.requestOtp:
        return _ok({
          'message': 'OTP sent',
          'key': 'mock-key-${DateTime.now().millisecondsSinceEpoch}',
          'mobileNumber': '${data['mobileNumber'] ?? ''}',
        });
      case ApiEndpoints.confirmOtp:
        final otp = '${data['otp'] ?? ''}';
        if (otp.length != 4 && otp != ApiConfig.mockOtp) {
          return _fail('Invalid or expired OTP. Please try again.');
        }
        return _ok(_db.confirmOtp('${data['mobileNumber'] ?? ''}'));
      case ApiEndpoints.saveEpisode:
        _db.saveEpisode(data);
        return _ok({'saved': true});
      case ApiEndpoints.updateAppointmentStatus:
        _db.updateAppointmentStatus(data);
        return _ok({'StatusId': '${data['StatusId'] ?? ''}'});
      case ApiEndpoints.startClinicSchedule:
        return _ok(_db.startClinic(_toInt(data['scheduleId'])));
      case ApiEndpoints.closeClinicSchedule:
        return _ok(_db.closeClinic(_toInt(data['scheduleId'])));
      default:
        throw ApiException('Mock: unhandled POST $path', statusCode: 404);
    }
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    await _latency();
    throw ApiException('Mock: unhandled PUT $path', statusCode: 404);
  }

  // ── helpers ────────────────────────────────────────────────────────────

  /// Pretend the network took a moment.
  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 260));

  /// Drops any query string so `switch` can match against [ApiEndpoints].
  String _pathOnly(String path) => Uri.parse(path).path;

  int _toInt(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  /// A success envelope, same shape as the real server.
  Map<String, dynamic> _ok(Object? data) => {
    'success': true,
    'statusCode': 200,
    'message': 'OK',
    'data': data,
  };

  /// A failure envelope.
  Map<String, dynamic> _fail(String message) => {
    'success': false,
    'statusCode': 400,
    'message': message,
  };
}

// ─────────────────────────────────────────────────────────────────────────
class _MockDb {
  _MockDb() {
    _seed();
  }

  final List<Map<String, dynamic>> clinics = [];
  final List<Map<String, dynamic>> _appointments = [];
  // patientId -> episodes (newest first)
  final Map<int, List<Map<String, dynamic>>> _episodes = {};
  int _epId = 5000;
  String _clinicStartTime = '';
  String _clinicEndTime = '';

  static const int _activeScheduleId = 9001;
  static const int _doctorId = 21;
  static const int _userId = 101;

  // ── seed ──────────────────────────────────────────────────────────────
  void _seed() {
    clinics.addAll(const [
      {
        'ID': 1,
        'ClinicName': 'DSM CLINIC - SOPORE',
        'Address': 'Main Road Sopore',
        'City': 'Baramulla',
        'MobileNumber': '9419013267',
        'IsActive': 'Y',
      },
      {
        'ID': 2,
        'ClinicName': 'DSM CLINIC - BHAGAT',
        'Address': 'Bhagat Chowk',
        'City': 'Srinagar',
        'MobileNumber': '9419055512',
        'IsActive': 'Y',
      },
      {
        'ID': 3,
        'ClinicName': 'DSM CLINIC - SOURA',
        'Address': 'Near SKIMS, Soura',
        'City': 'Srinagar',
        'MobileNumber': '9419077788',
        'IsActive': 'Y',
      },
    ]);

    final base = <List<Object>>[];

    var aid = 4000;
    for (final r in base) {
      aid++;
      _appointments.add({
        'ID': aid,
        'ScheduleID': _activeScheduleId,
        'ScheduleId': _activeScheduleId,
        'SequenceNo': r[6],
        'CheckInTime': _isoNow(minusMinutes: (7 - (r[6] as int)) * 9),
        'PatientRemarks': r[8],
        'StatusId': r[7],
        'patient': {
          'ID': aid + 500,
          'FullName': r[0],
          'Address': r[1],
          'City': r[2],
          'MobileNumber': r[3],
          'DateOfBirth': r[4],
          'Gender': r[5],
        },
      });
    }

    // A couple of historical (VST) episodes per patient for the history view.
    final hx = <int, List<List<String>>>{};
    for (final a in _appointments) {
      final pid = a['patient']['ID'] as int;
      hx[pid] = [
        [
          'Follow-up review',
          'E11.9',
          'Type 2 diabetes mellitus without complications',
          'Continue metformin 500mg BD. Repeat fasting glucose in 2 weeks.',
        ],
        [
          'Seasonal viral illness',
          'J06.9',
          'Acute upper respiratory infection, unspecified',
          'Paracetamol 650mg TDS x3d, steam inhalation, rest.',
        ],
      ];
    }
    hx.forEach((pid, rows) {
      var d = DateTime.now().subtract(const Duration(days: 14));
      for (final row in rows) {
        _episodes.putIfAbsent(pid, () => []).add({
          'EpisodeId': ++_epId,
          'AppointmentId': -(_epId),
          'PatientId': pid,
          'SequenceNo': 0,
          'StatusId': 'VST',
          'PatientRemarks': row[0],
          'CheckInTime': d.toIso8601String(),
          'ChiefComplaint': row[0],
          'DoctorRemarks': row[3],
          'PrimaryICD': row[1],
          'PrimaryDesc': row[2],
          'SecondaryICD': null,
          'SecondaryDesc': null,
          'TreatementDate': d.toIso8601String().substring(0, 10),
        });
        d = d.subtract(const Duration(days: 21));
      }
    });
  }

  // ── auth ─────────────────────────────────────────────────────────────
  Map<String, dynamic> confirmOtp(String mobile) => {
    'userBasicInformation': {
      'ID': _userId,
      'UserName': mobile,
      'UserType': UserType.doctor,
      'IsVerified': 'Y',
      'RecordId': _doctorId,
    },
    'userFullInformation': doctorDetails(),
    'token': 'mock.jwt.${DateTime.now().millisecondsSinceEpoch}',
  };

  Map<String, dynamic> doctorDetails() => {
    'ID': _doctorId,
    'FullName': 'Dr. Shariq Masoodi',
    'Address': 'Bemina',
    'City': 'Srinagar',
    'Specility': 'Endocrinology & General Medicine',
    'UserId': _userId,
  };

  // ── clinics ──────────────────────────────────────────────────────────
  Map<String, dynamic>? clinicById(int id) =>
      clinics.where((c) => c['ID'] == id).cast<Map<String, dynamic>?>().firstWhere(
            (_) => true,
        orElse: () => null,
      );

  // ── schedules ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> doctorSchedules() {
    final out = <Map<String, dynamic>>[];
    final today = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final key = _dateKey(d);
      out.add({
        'ScheduleId': i == 0 ? _activeScheduleId : 9100 + i,
        'Date': key,
        'Day': days[d.weekday - 1],
        'StartTime': '09:30:00',
        'EndTime': '14:00:00',
        'Duration': 6,
        'Status': i == 0 ? 'ACT' : 'RDY',
        'SlotsAvailable': i == 0 ? 45 : 60,
      });
      if (i == 0) {
        out.add({
          'ScheduleId': 9050,
          'Date': key,
          'Day': days[d.weekday - 1],
          'StartTime': '17:00:00',
          'EndTime': '21:00:00',
          'Duration': 8,
          'Status': 'RDY',
          'SlotsAvailable': 25,
        });
      }
    }
    return out;
  }

  Map<String, dynamic> scheduleInfo(int id) => {
    'ID': id,
    'ScheduleDate': _dateKey(DateTime.now()),
    'StartTime': '09:30:00',
    'EndTime': '14:00:00',
    'Status': id == _activeScheduleId ? 'ACT' : 'RDY',
    'DoctorName': 'Dr. Shariq Masoodi',
    'SlotCount': 45,
  };

  Map<String, dynamic> startClinic(int id) {
    _clinicStartTime = _isoNow();
    return {'ScheduleId': id, 'ClinicStartTime': _clinicStartTime, 'alreadyStarted': false};
  }

  Map<String, dynamic> closeClinic(int id) {
    _clinicEndTime = _isoNow();
    return {'ScheduleId': id, 'ClinicEndTime': _clinicEndTime, 'alreadyStarted': true};
  }

  // ── doctor dashboard ─────────────────────────────────────────────────
  Map<String, dynamic> doctorDashboard(int scheduleId) {
    final mine = _appointments
        .where((a) => a['ScheduleID'] == (scheduleId == 0 ? _activeScheduleId : scheduleId))
        .toList();

    List<Map<String, dynamic>> byStatus(String s) => mine
        .where((a) => a['StatusId'] == s)
        .toList()
      ..sort((a, b) => (a['SequenceNo'] as int).compareTo(b['SequenceNo'] as int));

    Map<String, dynamic> count(String s) => {
      'Status': s,
      'StatusCount': mine.where((a) => a['StatusId'] == s).length,
      'ScheduleID': scheduleId,
    };

    return {
      'dashboardSummary': [
        count(AppointmentStatus.booked),
        count(AppointmentStatus.checkedIn),
        count(AppointmentStatus.onHold),
        count(AppointmentStatus.visited),
      ],
      'appointments': byStatus(AppointmentStatus.checkedIn),
      'heldAppointments': byStatus(AppointmentStatus.onHold),
    };
  }

  // ── episodes ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> episodesForPatient(int patientId) =>
      List<Map<String, dynamic>>.from(_episodes[patientId] ?? const []);

  void saveEpisode(Map<String, dynamic> payload) {
    final patientId = _asInt(payload['PatientId']);
    final appointmentId = _asInt(payload['AppointmentId']);
    final list = _episodes.putIfAbsent(patientId, () => []);
    final existingIndex =
    list.indexWhere((e) => _asInt(e['AppointmentId']) == appointmentId);

    final episode = {
      'EpisodeId': existingIndex >= 0 ? list[existingIndex]['EpisodeId'] : ++_epId,
      'AppointmentId': appointmentId,
      'PatientId': patientId,
      'SequenceNo': existingIndex >= 0 ? list[existingIndex]['SequenceNo'] : 0,
      'StatusId': 'CKD',
      'PatientRemarks': _apptFor(appointmentId)?['PatientRemarks'],
      'CheckInTime': _apptFor(appointmentId)?['CheckInTime'] ?? _isoNow(),
      'ChiefComplaint': payload['ChiefComplaint'],
      'DoctorRemarks': payload['DoctorRemarks'],
      'PrimaryICD': payload['PrimaryICD'],
      'PrimaryDesc': _icdDesc(payload['PrimaryICD']),
      'SecondaryICD': payload['SecondaryICD'],
      'SecondaryDesc': _icdDesc(payload['SecondaryICD']),
      'TreatementDate': payload['TreatmentDate'],
    };

    if (existingIndex >= 0) {
      list[existingIndex] = episode;
    } else {
      list.insert(0, episode);
    }
  }

  void updateAppointmentStatus(Map<String, dynamic> payload) {
    final appt = _apptFor(_asInt(payload['AppointmentId']));
    if (appt == null) return;

    final next = '${payload['StatusId'] ?? ''}';
    appt['StatusId'] = next;

    // Returning a held patient to the back of the queue: give them a fresh
    // (highest) sequence number.
    final position = '${payload['RequeuePosition'] ?? RequeuePosition.end}';
    if (next == AppointmentStatus.checkedIn &&
        position == RequeuePosition.end) {
      final maxSeq = _appointments
          .map((a) => a['SequenceNo'] as int)
          .fold<int>(0, (m, s) => s > m ? s : m);
      appt['SequenceNo'] = maxSeq + 1;
    }
  }

  // ── icd ──────────────────────────────────────────────────────────────
  static const List<List<String>> _icd = [
    ['R51', 'Headache'],
    ['E11.9', 'Type 2 diabetes mellitus without complications'],
    ['I10', 'Essential (primary) hypertension'],
    ['E05.9', 'Thyrotoxicosis, unspecified'],
    ['J02.9', 'Acute pharyngitis, unspecified'],
    ['J06.9', 'Acute upper respiratory infection, unspecified'],
    ['R50.9', 'Fever, unspecified'],
    ['M10.9', 'Gout, unspecified'],
    ['M25.5', 'Pain in joint'],
    ['R00.2', 'Palpitations'],
    ['K21.9', 'GERD without oesophagitis'],
    ['R42', 'Dizziness and giddiness'],
    ['J45.909', 'Unspecified asthma, uncomplicated'],
    ['N39.0', 'Urinary tract infection, site not specified'],
  ];

  List<Map<String, dynamic>> searchIcd(String term) {
    final t = term.trim().toLowerCase();
    return _icd
        .where((r) =>
    t.isEmpty ||
        r[0].toLowerCase().contains(t) ||
        r[1].toLowerCase().contains(t))
        .take(20)
        .map((r) => {'ICDCode': r[0], 'ShortDescription': r[1]})
        .toList();
  }

  String? _icdDesc(Object? code) {
    if (code == null) return null;
    final c = '$code';
    for (final r in _icd) {
      if (r[0] == c) return r[1];
    }
    return null;
  }

  // ── patient directory ────────────────────────────────────────────────
  Map<String, dynamic> searchPatients(String term, int page, int limit) {
    final t = term.trim().toLowerCase();
    final all = _appointments.map((a) {
      final p = a['patient'] as Map<String, dynamic>;
      return {
        'ID': p['ID'],
        'FullName': p['FullName'],
        'MobileNumber': p['MobileNumber'],
        'DateOfBirth': p['DateOfBirth'],
        'Gender': p['Gender'],
        'Address': p['Address'],
        'City': p['City'],
      };
    }).where((p) {
      if (t.isEmpty) return true;
      return '${p['FullName']}'.toLowerCase().contains(t) ||
          '${p['MobileNumber']}'.contains(t);
    }).toList();

    final start = (page - 1) * limit;
    final items = start >= all.length
        ? <Map<String, dynamic>>[]
        : all.sublist(start, (start + limit).clamp(0, all.length));
    return {'items': items, 'total': all.length};
  }

  // ── utils ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _apptFor(int appointmentId) => _appointments
      .cast<Map<String, dynamic>?>()
      .firstWhere((a) => a?['ID'] == appointmentId, orElse: () => null);

  int _asInt(Object? v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _isoNow({int minusMinutes = 0}) => DateTime.now()
      .subtract(Duration(minutes: minusMinutes))
      .toIso8601String();
}
