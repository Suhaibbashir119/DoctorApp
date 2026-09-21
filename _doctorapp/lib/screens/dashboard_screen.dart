import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/dtos.dart';
import '../models/consultation_queue_item.dart';
import '../services/consultation_service.dart';
import '../theme/app_theme.dart';
import 'begin_consultation_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ClinicDto> _clinics = [];
  ClinicDto? _selectedClinic;
  DoctorDashboardDto? _dashboardData;
  bool _isLoadingDashboard = false;
  bool _isSessionActive = true;
  int _activeScheduleId = 1;
  String _doctorName = currentDoctorName.isNotEmpty ? currentDoctorName : 'Doctor';

  @override
  void initState() {
    super.initState();
    consultationService.addListener(_refresh);
    _loadDoctorProfile();
    _loadClinics();
    _loadDashboard(_activeScheduleId);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    consultationService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final response = await apiClient.get(ApiEndpoints.getDoctorDetails);
      final data = response['data'] is Map ? response['data'] as Map<String, dynamic> : response;
      final dto = DoctorDetailsDto.fromJson(data);

      final fetchedName = dto.fullName.isNotEmpty
          ? dto.fullName
          : '${data['FullName'] ?? data['UserName'] ?? data['name'] ?? ''}'.trim();

      if (mounted && fetchedName.isNotEmpty) {
        final formattedName = fetchedName.startsWith('Dr.') ? fetchedName : 'Dr. $fetchedName';
        setState(() {
          _doctorName = formattedName;
          currentDoctorName = formattedName;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctor profile: $e');
    }
  }

  Future<void> _loadClinics() async {
    try {
      final response = await apiClient.get(ApiEndpoints.getClinics);
      final list = response['data'] as List? ?? response['clinics'] as List? ?? [];
      final parsed = list.map((json) => ClinicDto.fromJson(json)).toList();

      final uniqueClinics = <int, ClinicDto>{};
      for (final c in parsed) {
        uniqueClinics[c.id] = c;
      }
      final cleanList = uniqueClinics.values.toList();

      if (mounted && cleanList.isNotEmpty) {
        setState(() {
          _clinics = cleanList;
          _selectedClinic = cleanList.first;
          _activeScheduleId = cleanList.first.id;
        });
        _loadDashboard(_activeScheduleId);
      }
    } catch (_) {
      // Fallback silently if offline or mock
    }
  }

  Future<void> _loadDashboard(int scheduleId) async {
    if (_isLoadingDashboard) return;

    setState(() {
      _isLoadingDashboard = true;
    });

    try {
      final response = await apiClient.get(
        ApiEndpoints.getDoctorDashboard,
        query: {'scheduleId': scheduleId},
      );

      final data = DoctorDashboardDto.fromJson(
        response['data'] is Map ? response['data'] : response,
      );

      if (mounted) {
        setState(() {
          _dashboardData = data;
        });
      }
    } catch (_) {
      // Keep local service queue on error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _toggleOpdSession() async {
    final newStatus = !_isSessionActive;
    setState(() {
      _isSessionActive = newStatus;
    });

    try {
      final endpoint = newStatus
          ? ApiEndpoints.startClinicSchedule
          : ApiEndpoints.closeClinicSchedule;

      await apiClient.post(
        endpoint,
        body: {
          'scheduleId': _activeScheduleId,
          'ScheduleID': _activeScheduleId,
        },
      );
    } catch (e) {
      debugPrint('OPD Session API toggle notice: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus
              ? 'OPD Session Started Successfully'
              : 'OPD Session Paused/Closed',
        ),
        backgroundColor: newStatus ? AppTheme.primaryGreen : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToBeginConsultation(
    BuildContext context,
    ConsultationQueueItem item,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BeginConsultationScreen(
          patientId: item.patientId,
          patientName: item.patientName,
          age: item.age,
          gender: item.gender == 'M' ? 'Male' : 'Female',
          consultationType: item.type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiAppointments = _dashboardData?.appointments ?? [];
    final selectedClinicName = _selectedClinic?.name.toLowerCase().trim() ?? '';

    // 1. Get API appointments for current clinic
    final apiQueueItems = apiAppointments.map((appt) {
      return ConsultationQueueItem(
        patientId: 'PAT${appt.patientId}',
        patientName: appt.patientName,
        age: 35,
        gender: 'M',
        type: 'General Consultation',
        status: 'Waiting',
        time: appt.checkInTime.isNotEmpty ? appt.checkInTime : '10:00 AM',
        clinicName: _selectedClinic?.name ?? '',
      );
    }).toList();

    // 2. Filter local queue items strictly by the selected clinic name
    final localQueueItems = [
      ...consultationService.queueItems,
      ...consultationService.followUpItems,
    ].where((item) {
      if (selectedClinicName.isEmpty) return true;
      final itemClinic = item.clinicName.toLowerCase().trim();
      if (itemClinic.isEmpty) return false; // Strictly require assigned clinic match
      return itemClinic == selectedClinicName;
    }).toList();

    // 3. Combine API appointments & local patients for selected clinic
    final combinedQueue = <ConsultationQueueItem>[...apiQueueItems];
    final existingIds = combinedQueue.map((e) => e.patientId).toSet();
    for (final localItem in localQueueItems) {
      if (!existingIds.contains(localItem.patientId)) {
        combinedQueue.add(localItem);
      }
    }

    final queueItems = combinedQueue;

    // Today's total and waiting counts dynamically calculated for selected clinic
    final totalCount = queueItems.length;
    final waitingCount = queueItems.where((e) => e.status == 'Waiting' || e.status == 'On Hold').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Greeting & Clinic Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $_doctorName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_clinics.isNotEmpty)
                          DropdownButtonHideUnderline(
                            child: DropdownButton<ClinicDto>(
                              value: _clinics.contains(_selectedClinic) ? _selectedClinic : _clinics.first,
                              isDense: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: AppTheme.primaryDarkGreen,
                                size: 20,
                              ),
                              items: _clinics.map((clinic) {
                                return DropdownMenuItem(
                                  value: clinic,
                                  child: Text(
                                    clinic.name.isNotEmpty
                                        ? clinic.name
                                        : 'Main OPD Clinic',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryDarkGreen,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedClinic = val;
                                    _activeScheduleId = val.id;
                                  });
                                  _loadDashboard(val.id);
                                }
                              },
                            ),
                          )
                        else
                          const Text(
                            "Here's your today's overview",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Notification Bell & Refresh Icon
                  Row(
                    children: [
                      IconButton(
                        icon: _isLoadingDashboard
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, color: AppTheme.textPrimary),
                        tooltip: 'Refresh Queue',
                        onPressed: () => _loadDashboard(_activeScheduleId),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.cardBorder,
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.textPrimary,
                              size: 22,
                            ),
                            if (queueItems.isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // OPD Session Toggle Control
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isSessionActive ? AppTheme.accentGreen : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSessionActive
                        ? AppTheme.primaryGreen.withOpacity(0.3)
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSessionActive ? Icons.play_circle_fill : Icons.pause_circle_filled,
                      color: _isSessionActive ? AppTheme.primaryDarkGreen : Colors.orange.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSessionActive ? 'OPD SESSION ACTIVE' : 'OPD SESSION PAUSED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isSessionActive
                                  ? AppTheme.primaryDarkGreen
                                  : Colors.orange.shade900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isSessionActive
                                ? 'Receiving checked-in patients'
                                : 'Patients paused from queue',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleOpdSession,
                      child: Text(
                        _isSessionActive ? 'Pause OPD' : 'Start OPD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isSessionActive
                              ? AppTheme.primaryDarkGreen
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Today's Consultations Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.cardBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Consultations",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$waitingCount patients waiting in queue',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.groups,
                        color: AppTheme.primaryDarkGreen,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Consultation Queue Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Consultation Queue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${queueItems.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Queue List
              if (queueItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.cardBorder,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 42,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No patients waiting',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Patients added from the Patients section will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: queueItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = queueItems[index];
                    final isFollowUp = item.type == 'Follow-up';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.accentGreen,
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryDarkGreen,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.patientName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Patient #${item.patientId.replaceAll('PAT', '')}  •  ${item.age} Y',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.type,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isFollowUp
                                            ? Colors.blue.shade700
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.status}  •  ${item.time}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isFollowUp
                                            ? Colors.blue.shade700
                                            : Colors.orange.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () => _navigateToBeginConsultation(
                                context,
                                item,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                                side: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Begin Consultation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
