import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/dtos.dart';
import '../../theme/app_theme.dart';

class ManageClinicsScreen extends StatefulWidget {
  const ManageClinicsScreen({super.key});

  @override
  State<ManageClinicsScreen> createState() => _ManageClinicsScreenState();
}

class _ManageClinicsScreenState extends State<ManageClinicsScreen> {
  List<ClinicDto> _clinics = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiClient.get(ApiEndpoints.getClinics);
      final list = response['data'] as List? ?? response['clinics'] as List? ?? [];
      final parsed = list.map((json) => ClinicDto.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _clinics = parsed;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load clinics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showClinicDialog({ClinicDto? clinicToEdit}) {
    final isEditing = clinicToEdit != null;
    final nameController = TextEditingController(text: clinicToEdit?.name ?? '');
    final addressController = TextEditingController(text: clinicToEdit?.address ?? '');
    final cityController = TextEditingController(text: clinicToEdit?.city ?? '');
    final phoneController = TextEditingController(text: clinicToEdit?.mobileNumber ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit OPD Clinic' : 'Add New OPD Clinic'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Clinic Name',
                    hintText: 'e.g. ShifaQ Central Clinic',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: 'e.g. Bemina Main Road',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'e.g. Srinagar',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile / Contact Number',
                    hintText: 'e.g. 9876543210',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a clinic name.')),
                  );
                  return;
                }

                if (isEditing) {
                  // Update Clinic
                  final index = _clinics.indexWhere((c) => c.id == clinicToEdit.id);
                  if (index != -1) {
                    setState(() {
                      _clinics[index] = ClinicDto(
                        id: clinicToEdit.id,
                        name: name,
                        address: addressController.text.trim(),
                        city: cityController.text.trim(),
                        mobileNumber: phoneController.text.trim(),
                      );
                    });
                  }
                } else {
                  // Add New Clinic
                  final newClinic = ClinicDto(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: name,
                    address: addressController.text.trim(),
                    city: cityController.text.trim(),
                    mobileNumber: phoneController.text.trim(),
                  );
                  setState(() {
                    _clinics.add(newClinic);
                  });
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? 'Clinic updated successfully!' : 'Clinic added successfully!'),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Clinic'),
            ),
          ],
        );
      },
    );
  }

  void _deleteClinic(ClinicDto clinic) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Clinic'),
          content: Text('Are you sure you want to delete "${clinic.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _clinics.removeWhere((c) => c.id == clinic.id);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clinic deleted successfully!'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manage OPD Clinics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Clinic',
            onPressed: () => _showClinicDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _clinics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 54,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No OPD Clinics Registered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap + to add your first clinic location.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showClinicDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Clinic'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _clinics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final clinic = _clinics[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          ),
                          title: Text(
                            clinic.name.isNotEmpty ? clinic.name : 'OPD Clinic',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              if (clinic.address.isNotEmpty || clinic.city.isNotEmpty)
                                Text(
                                  '${clinic.address}${clinic.address.isNotEmpty && clinic.city.isNotEmpty ? ', ' : ''}${clinic.city}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              if (clinic.mobileNumber.isNotEmpty)
                                Text(
                                  'Phone: ${clinic.mobileNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen),
                                tooltip: 'Edit Clinic',
                                onPressed: () => _showClinicDialog(clinicToEdit: clinic),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete Clinic',
                                onPressed: () => _deleteClinic(clinic),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClinicDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Clinic'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }
}
