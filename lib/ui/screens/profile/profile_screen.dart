import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/services/role_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../common/primary_button.dart';
import '../../common/custom_text_field.dart';
import '../../../data/models/shop_model.dart';
import '../shop/setup_shop_screen.dart';
import '../../../core/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);
    final profileState = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.system
                  ? Icons.brightness_auto_outlined
                  : themeMode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Theme mode: ${ref.read(themeProvider) == ThemeMode.system ? "System Default" : ref.read(themeProvider) == ThemeMode.dark ? "Dark Theme" : "Light Theme"}'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: shopState.when(
              data: (shop) {
                final lat = shop?.latitude;
                final lng = shop?.longitude;
                final coordinatesText = (lat != null && lng != null)
                    ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                    : 'Not Set (Required for discovery)';

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.horizontalPadding,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    // ── Premium Hero Header ──────────────────────────────
                    _ProfileHeroHeader(shop: shop),
                    AppSpacing.verticalMd,

                    // ── Open/Closed toggle ───────────────────────────────
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SwitchListTile(
                        value: shop?.isOpen ?? false,
                        onChanged: shop == null ? null : (value) async {
                          final updatedShop = shop.copyWith(isOpen: value);
                          try {
                            await ref.read(shopRepositoryProvider).updateShopProfile(updatedShop);
                            // Track manual close date so the auto-open timer won't
                            // reopen the shop on the same day the vendor closed it.
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              final today = DateTime.now().toIso8601String().split('T')[0];
                              await FirebaseDatabase.instance.ref('shop/$uid').update({
                                'manuallyClosedAt': value ? null : today,
                              });
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value ? 'Shop marked as Open' : 'Shop marked as Closed'),
                                  backgroundColor: value ? AppColors.success : AppColors.warning,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                        title: const Text('Shop is Open', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(shop?.isOpen == true ? 'Customers can see you as open' : 'Customers will see your shop as closed'),
                        activeThumbColor: AppColors.success,
                        secondary: Icon(
                          shop?.isOpen == true ? Icons.storefront : Icons.storefront_outlined,
                          color: shop?.isOpen == true ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // ── Shop Details section ─────────────────────────────
                    AppSpacing.verticalMd,
                    const _SectionLabel(label: 'Shop Details'),
                    AppSpacing.verticalSm,
                    _buildListTile(context, 'Shop Name', shop?.name ?? 'Not Set', Icons.business),
                    _buildListTile(context, 'Description', shop?.description ?? 'Not Set', Icons.description),
                    _buildListTile(context, 'Address', shop?.address ?? 'Not Set', Icons.location_on),
                    _buildListTile(
                      context,
                      'Storefront GPS Coordinates',
                      coordinatesText,
                      Icons.map_outlined,
                    ),
                    _buildListTile(context, 'Phone', shop?.phone ?? 'Not Set', Icons.phone),

                    // ── App Preferences section ──────────────────────────
                    AppSpacing.verticalLg,
                    const _SectionLabel(label: 'App Preferences'),
                    AppSpacing.verticalSm,
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            themeMode == ThemeMode.system
                                ? Icons.brightness_auto_outlined
                                : themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text('App Theme'),
                        subtitle: Text(
                          themeMode == ThemeMode.system
                              ? 'System Default (follows device)'
                              : themeMode == ThemeMode.dark
                                  ? 'Dark Theme'
                                  : 'Light Theme',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeSelectionSheet(context, ref, themeMode),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: AppColors.primary),
                        ),
                        title: const Text('Security'),
                        subtitle: const Text(
                            'App lock, two-factor auth, signed-in devices'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/security'),
                      ),
                    ),

                    // ── Security & Linked Accounts section ───────────────
                    AppSpacing.verticalLg,
                    const _SectionLabel(label: 'Security & Linked Accounts'),
                    AppSpacing.verticalSm,

                    profileState.when(
                      data: (profile) {
                        final email = profile?['email'] as String?;
                        final phone = profile?['phone'] as String?;

                        return Column(
                          children: [
                            Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ListTile(
                                leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                                title: const Text('Bound Email Address'),
                                subtitle: Text(email != null && email.isNotEmpty ? email : 'Not Bound'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final updated = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _BindEmailDialog(initialEmail: email, ref: ref),
                                    );
                                    if (updated == true && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Email bound successfully!'),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ListTile(
                                leading: const Icon(Icons.phone_android_outlined, color: AppColors.primary),
                                title: const Text('Bound Phone Number'),
                                subtitle: Text(phone != null && phone.isNotEmpty ? phone : 'Not Bound'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final updated = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _BindPhoneDialog(ref: ref),
                                    );
                                    if (updated == true && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Phone number bound successfully!'),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading accounts: $e', style: const TextStyle(color: AppColors.error))),
                    ),

                    AppSpacing.verticalXl,
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderLg,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: AppRadius.borderLg,
                        onTap: () => _showShareAppSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.share_outlined,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              AppSpacing.horizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Share Local Vyapari',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Invite other vyaparis or customers',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.verticalMd,
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderLg,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: AppRadius.borderLg,
                        onTap: () async {
                          try {
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            await RoleService.instance.switchRoleAndLaunchApp('customer');

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to switch: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people_outline,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              AppSpacing.horizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Switch to Customer App',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Browse and buy from local vyaparis',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.verticalLg,
                    PrimaryButton(
                      text: 'Edit Profile',
                      onPressed: () {
                        if (shop != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SetupShopScreen(existingShop: shop),
                            ),
                          );
                        }
                      },
                    ),
                    AppSpacing.verticalMd,
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMedium),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, String subtitle, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: cs.onSurfaceVariant),
        title: Text(title, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showThemeSelectionSheet(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.horizontalPadding,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    'Select App Theme',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.brightness_auto_outlined),
                  title: const Text('System Default'),
                  subtitle: const Text('Follows device settings'),
                  trailing: currentMode == ThemeMode.system
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.light_mode_outlined),
                  title: const Text('Light Theme'),
                  subtitle: const Text('Light background with dark text'),
                  trailing: currentMode == ThemeMode.light
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Theme'),
                  subtitle: const Text('Dark background with light text'),
                  trailing: currentMode == ThemeMode.dark
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareAppSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Local Vyapari',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: AppColors.primary),
                title: const Text('Copy download link'),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(
                    text: 'Check out Local Vyapari App! Discover nearby retail shops and get exclusive local offers: https://localvyapari.com/download'
                  ));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('App link copied to your clipboard.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.green),
                title: const Text('Share via WhatsApp'),
                onTap: () async {
                  final message = Uri.encodeComponent(
                    'Check out Local Vyapari App! Discover nearby retail shops and get exclusive local offers: https://localvyapari.com/download'
                  );
                  final url = Uri.parse('https://wa.me/?text=$message');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open WhatsApp.'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Profile Hero Header ──────────────────────────────────────────────────────

class _ProfileHeroHeader extends StatelessWidget {
  final ShopModel? shop;
  const _ProfileHeroHeader({required this.shop});

  @override
  Widget build(BuildContext context) {
    final isOpen = shop?.isOpen ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Shop logo
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: shop?.logoUrl != null ? NetworkImage(shop!.logoUrl!) : null,
            child: shop?.logoUrl == null
                ? const Icon(Icons.storefront, size: 34, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          // Shop info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop?.name ?? 'Your Store',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shop?.address.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.white.withValues(alpha: 0.55), size: 11),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          shop!.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Open/closed pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOpen ? 'Open' : 'Closed',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ),
                    if (shop?.rating != null && (shop?.rating ?? 0) > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                            const SizedBox(width: 3),
                            Text(
                              shop!.rating!.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ─── Bind Email Dialog ────────────────────────────────────────────────────────
class _BindEmailDialog extends StatefulWidget {
  final String? initialEmail;
  final WidgetRef ref;

  const _BindEmailDialog({required this.initialEmail, required this.ref});

  @override
  State<_BindEmailDialog> createState() => _BindEmailDialogState();
}

class _BindEmailDialogState extends State<_BindEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bind Email Address'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: 'Email Address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Email is required';
                if (!val.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isLoading = true);

            final success = await widget.ref.read(authProvider.notifier).bindEmail(_emailController.text.trim());

            if (context.mounted) {
              setState(() => _isLoading = false);
              if (success) {
                Navigator.pop(context, true);
              } else {
                final error = widget.ref.read(authProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Binding failed'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Bind'),
        ),
      ],
    );
  }
}

// ─── Bind Phone Dialog ────────────────────────────────────────────────────────
class _BindPhoneDialog extends StatefulWidget {
  final WidgetRef ref;

  const _BindPhoneDialog({required this.ref});

  @override
  State<_BindPhoneDialog> createState() => _BindPhoneDialogState();
}

class _BindPhoneDialogState extends State<_BindPhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fullPhone = '+91$phone';
    await widget.ref.read(authProvider.notifier).requestBindPhoneOtp(
      fullPhone,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _otpSent = true;
            _verificationId = verificationId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent. Please check your SMS messages.'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 10),
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  void _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verificationId == null) return;

    setState(() => _isLoading = true);

    final code = _otpController.text.trim();

    final success = await widget.ref.read(authProvider.notifier).verifyAndBindPhone(_verificationId!, code);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        final error = widget.ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Verification failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bind Phone Number'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_android,
                prefixText: '+91 ',
                readOnly: _otpSent,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Phone number is required';
                  if (val.length != 10) return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              if (_otpSent) ...[
                AppSpacing.verticalMd,
                CustomTextField(
                  label: 'Enter 6-Digit OTP',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.lock_outline,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'OTP code is required';
                    if (val.length != 6) return 'OTP must be 6 digits';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_otpSent ? 'Verify & Link' : 'Send OTP'),
        ),
      ],
    );
  }
}
