import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/dtos.dart';
import '../../theme/app_theme.dart';

class ConsultationSettingsScreen extends StatefulWidget {
  final String initialStartTime;
  final String initialEndTime;
  final int initialFee;

  const ConsultationSettingsScreen({
    super.key,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.initialFee,
  });

  @override
  State<ConsultationSettingsScreen> createState() =>
      _ConsultationSettingsScreenState();
}

class _ConsultationSettingsScreenState
    extends State<ConsultationSettingsScreen> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final TextEditingController _feeController;

  List<MonthlyScheduleItemDto> _schedules = [];
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();

    _startTime = _parseTime(widget.initialStartTime) ??
        const TimeOfDay(hour: 9, minute: 0);

    _endTime = _parseTime(widget.initialEndTime) ??
        const TimeOfDay(hour: 17, minute: 0);

    _feeController = TextEditingController(
      text: widget.initialFee.toString(),
    );

    _fetchDoctorSchedules();
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctorSchedules() async {
    setState(() {
      _isLoadingSchedules = true;
    });

    try {
      final response = await apiClient.get(ApiEndpoints.getDoctorSchedules);
      final list = response['data'] as List? ?? response['schedules'] as List? ?? [];
      final parsed = list.map((json) => MonthlyScheduleItemDto.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _schedules = parsed;
        });
      }
    } catch (_) {
      // Fallback silently if offline or mock
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSchedules = false;
        });
      }
    }
  }

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (selected == null) return;

    setState(() {
      _startTime = selected;
    });
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (selected == null) return;

    setState(() {
      _endTime = selected;
    });
  }

  void _saveSettings() {
    final fee = int.tryParse(_feeController.text.trim());

    if (fee == null || fee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid consultation fee.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      {
        'startTime': _startTime.format(context),
        'endTime': _endTime.format(context),
        'fee': fee,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Fees & Timings'),
        actions: [
          IconButton(
            icon: _isLoadingSchedules
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Schedules',
            onPressed: _fetchDoctorSchedules,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default Consultation Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.login,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      title: const Text(
                        'Start Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _startTime.format(context),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: _selectStartTime,
                    ),

                    const Divider(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),

                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: AppTheme.primaryDarkGreen,
                        ),
                      ),
                      title: const Text(
                        'End Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _endTime.format(context),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: _selectEndTime,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Consultation Fee',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fee per consultation',
                  prefixText: '₹ ',
                  prefixIcon: Icon(
                    Icons.currency_rupee,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Doctor Schedules Section
              const Text(
                'Registered Doctor OPD Schedules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              if (_isLoadingSchedules)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_schedules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Text(
                    'No upcoming OPD schedule slots registered.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _schedules[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.date} (${item.day})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.startTime} - ${item.endTime} (${item.duration} mins)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.status == 'ACT'
                                  ? AppTheme.accentGreen
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.status == 'ACT' ? 'Active' : item.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.status == 'ACT'
                                    ? AppTheme.primaryDarkGreen
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    int? hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();

    if (hour == null || minute == null) return null;
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return null;
    }

    if (period == 'AM') {
      if (hour == 12) {
        hour = 0;
      }
    } else {
      if (hour != 12) {
        hour += 12;
      }
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }
}
