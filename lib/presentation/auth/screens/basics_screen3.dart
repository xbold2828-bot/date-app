import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'basics_screen4.dart';

class BasicsScreen3 extends StatefulWidget {
  const BasicsScreen3({super.key});

  @override
  State<BasicsScreen3> createState() => _BasicsScreen3State();
}

class _BasicsScreen3State extends State<BasicsScreen3> {
  bool _respectMyNos = true;
  bool _isLoading = false;

  final Set<String> _selectedRoles = {};
  final Set<String> _selectedInto = {};
  final Set<String> _selectedScenarios = {};
  final Set<String> _selectedFantasy = {};
  final Set<String> _selectedHardNos = {};

  final List<String> _roles = [
    'Dominant', 'Submissive', 'Switch',
    'Top', 'Bottom', 'Vers', 'Brat', 'Caregiver',
  ];

  final List<String> _into = [
    'Vanilla', 'Kink-friendly', 'Roleplay',
    'Power play', 'Sensation play', 'Toys', 'Experimental',
  ];

  final List<String> _scenarios = [
    'One-on-one', 'No-strings', 'FWB',
    'Discreet', 'Couples-friendly', 'Group-curious',
  ];

  final List<String> _fantasy = [
    'On the beach', 'Rooftop terrace',
    'Hotel escape', 'By the pool',
    'Golden hour', 'Candlelit', 'Travel fling',
  ];

  final List<String> _hardNos = [
    'No unsolicited pics',
    'No pushy energy', 'No ghosting',
    'No off-app', 'No smoking',
  ];

  Future<void> _onSave() async {
    setState(() => _isLoading = true);

    // TODO: ProfileService.updateDesires(
    //   roles: _selectedRoles,
    //   into: _selectedInto,
    //   scenarios: _selectedScenarios,
    //   fantasy: _selectedFantasy,
    //   hardNos: _selectedHardNos,
    //   respectMyNos: _respectMyNos,
    // )
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BasicsScreen4()),
  );
}

    setState(() => _isLoading = false);

    // TODO: GoRouter.of(context).go('/home')
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Radius',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            // Progress bar — full
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 3 OF 6',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'IDENTITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 3 / 6,
                      minHeight: 3,
                      backgroundColor: AppColors.inputBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // FINAL STEP label
                    const Text(
                      'STEP 3 OF 6',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Define your desires.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Verified members only. These tags are hidden until you reveal them.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),

                    const SizedBox(height: 20),

                    // Privacy preview card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Privacy Preview',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const Icon(Icons.lock_outline,
                                  size: 16, color: AppColors.textGrey),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'ENCRYPTED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textGrey,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const [
                              Text('Dominant',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textGrey)),
                              Text('Sensation play',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textGrey)),
                              Text('Experimental',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textGrey)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Role & Energy
                    _sectionLabel('ROLE & ENERGY'),
                    const SizedBox(height: 12),
                    _chipGroup(_roles, _selectedRoles),

                    const SizedBox(height: 28),

                    // Into
                    _sectionLabel('INTO'),
                    const SizedBox(height: 12),
                    _chipGroup(_into, _selectedInto),

                    const SizedBox(height: 28),

                    // Scenario
                    _sectionLabel('SCENARIO'),
                    const SizedBox(height: 12),
                    _chipGroup(_scenarios, _selectedScenarios),

                    const SizedBox(height: 28),

                    // Fantasy & Setting
                    _sectionLabel('FANTASY & SETTING'),
                    const SizedBox(height: 12),
                    _chipGroup(_fantasy, _selectedFantasy),

                    const SizedBox(height: 28),

                    // Hard No's
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "HARD NO'S",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Row(
                                children: [
                                  Switch(
                                    value: _respectMyNos,
                                    onChanged: (v) =>
                                        setState(() => _respectMyNos = v),
                                    activeColor: AppColors.primary,
                                  ),
                                  const Text(
                                    "Respect my no's",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _chipGroup(_hardNos, _selectedHardNos),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save & Enter button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: AppColors.white)
                            : const Text(
                                'Save & Enter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textGrey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _chipGroup(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = selected.contains(o);
        return GestureDetector(
          onTap: () => setState(() {
            isSelected ? selected.remove(o) : selected.add(o);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color:
                    isSelected ? AppColors.primary : AppColors.inputBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              o,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textDark,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}