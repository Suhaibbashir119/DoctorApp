import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/dtos.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'profile/abdm_credentials_screen.dart';
import 'profile/consultation_settings_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'profile/manage_clinics_screen.dart';
import 'profile/notification_settings_screen.dart';
import 'profile/security_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _doctorName = 'Dr. Rajesh Sharma';
  String _qualification = 'MBBS, MD (General Medicine)';
  String _registrationNumber = 'MCI-847291';

  String _startTime = '09:00 AM';
  String _endTime = '05:00 PM';
  int _consultationFee = 500;

  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctorProfile();
  }

  Future<void> _fetchDoctorProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiClient.get(ApiEndpoints.getDoctorDetails);
      final dto = DoctorDetailsDto.fromJson(
        response['data'] is Map ? response['data'] : response,
      );

      if (!mounted) return;

      setState(() {
        if (dto.fullName.isNotEmpty) {
          _doctorName = dto.fullName.startsWith('Dr.') ? dto.fullName : 'Dr. ${dto.fullName}';
        }
        if (dto.speciality.isNotEmpty) {
          _qualification = dto.speciality;
        }
      });
    } catch (_) {
      // Keep existing values if offline or mock error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: _doctorName,
          initialQualification: _qualification,
          initialRegistrationNumber: _registrationNumber,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _doctorName = result['name']!;
      _qualification = result['qualification']!;
      _registrationNumber = result['registrationNumber']!;
    });
  }

  Future<void> _editConsultationSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationSettingsScreen(
          initialStartTime: _startTime,
          initialEndTime: _endTime,
          initialFee: _consultationFee,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _startTime = result['startTime'] as String;
      _endTime = result['endTime'] as String;
      _consultationFee = result['fee'] as int;
    });
  }

  void _showManageClinics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageClinicsScreen(),
      ),
    );
  }

  void _showAbdmCredentials() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AbdmCredentialsScreen(),
      ),
    );
  }

  void _showSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SecuritySettingsScreen(),
      ),
    );
  }

  Future<void> _showNotificationSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          initialQueueAlerts: _notificationsEnabled,
          initialConsultationReminders: true,
          initialFollowUpReminders: true,
          initialSystemNotifications: true,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _notificationsEnabled = result['queueAlerts'] as bool;
    });
  }

  Future<void> _logout() async {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Profile',
            onPressed: _fetchDoctorProfile,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor profile card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.accentGreen,
                      child: const Icon(
                        Icons.medical_services_outlined,
                        color: AppTheme.primaryDarkGreen,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _doctorName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _qualification,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Reg. No: $_registrationNumber',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openEditProfile,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profile'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Authentication status
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: AppTheme.primaryDarkGreen,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUTHENTICATED SESSION',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDarkGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Local doctor session active',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Account & Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

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
                    _buildSettingTile(
                      icon: Icons.storefront,
                      title: 'Manage OPD Clinics',
                      subtitle: 'Add, edit, or remove clinic locations',
                      onTap: _showManageClinics,
                    ),

                    const Divider(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),

                    _buildSettingTile(
                      icon: Icons.access_time_filled,
                      title: 'Consultation Fees & Timings',
                      subtitle:
                          '$_startTime - $_endTime  •  ₹$_consultationFee',
                      onTap: _editConsultationSettings,
                    ),

                    const Divider(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),

                    _buildSettingTile(
                      icon: Icons.verified,
                      title: 'ABDM Credentials & Prescriptions',
                      subtitle: 'Active License verified',
                      onTap: _showAbdmCredentials,
                    ),

                    const Divider(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),

                    _buildSettingTile(
                      icon: Icons.security,
                      title: 'Security & PIN Settings',
                      subtitle: 'Manage authentication & PIN',
                      onTap: _showSecuritySettings,
                    ),

                    const Divider(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),

                    _buildSettingTile(
                      icon: Icons.notifications,
                      title: 'Notifications & Alerts',
                      subtitle: _notificationsEnabled
                          ? 'Patient queue alerts active'
                          : 'Patient queue alerts disabled',
                      onTap: _showNotificationSettings,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    side: BorderSide(
                      color: Colors.red.shade200,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryDarkGreen,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
