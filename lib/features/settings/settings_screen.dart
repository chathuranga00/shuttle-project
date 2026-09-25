import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  int _gpsRadius = 100;
  bool _gpsVerificationEnabled = true;
  final _priceCtrl = TextEditingController(text: '5000.00');
  bool _isSaving = false;
  bool _initialized = false;

  void _initForm(SystemSettingsData data) {
    if (!_initialized) {
      _gpsRadius = data.gpsRadiusMetres;
      _gpsVerificationEnabled = data.gpsVerificationEnabled;
      _priceCtrl.text = data.monthlyPassPrice.toStringAsFixed(2);
      _initialized = true;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'gpsRadiusMetres': _gpsRadius,
        'gpsVerificationEnabled': _gpsVerificationEnabled,
        'monthlyPassPrice': double.parse(_priceCtrl.text.trim()),
      };

      await api.post(ApiEndpoints.settingsConfig, data: payload);
      ref.invalidate(systemSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System settings saved successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load settings: $err', style: const TextStyle(color: AppTheme.danger))),
        data: (data) {
          _initForm(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Global Transit & System Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Configure geofencing boarding verification and campus pass pricing',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      // Card 1: GPS Verification & Radius
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.location_on, color: AppTheme.info, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'GPS Geofence Verification',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enforce GPS Verification on Boarding', style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text(
                                  'Requires the student to be within the allowed physical radius of the bus stop when scanning the QR code',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                value: _gpsVerificationEnabled,
                                onChanged: (v) => setState(() => _gpsVerificationEnabled = v),
                              ),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Allowed GPS Radius:', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text('$_gpsRadius metres', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                ],
                              ),
                              Slider(
                                min: 20,
                                max: 1000,
                                divisions: 98,
                                value: _gpsRadius.toDouble().clamp(20, 1000),
                                label: '$_gpsRadius m',
                                onChanged: _gpsVerificationEnabled
                                    ? (v) => setState(() => _gpsRadius = v.round())
                                    : null,
                              ),
                              const Text(
                                'Recommended radius: 100 metres around designated stop coordinates.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card 2: Monthly Pass Pricing
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.confirmation_number, color: AppTheme.success, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Monthly Pass Fee Configuration',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Set the fixed monthly subscription price charged to students for unlimited 30-day shuttle rides.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Monthly Pass Price (LKR) *',
                                  prefixText: 'LKR ',
                                ),
                                validator: (v) {
                                  final num = double.tryParse(v ?? '');
                                  if (num == null || num < 0) return 'Enter a valid price';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          icon: _isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: const Text('Save System Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
