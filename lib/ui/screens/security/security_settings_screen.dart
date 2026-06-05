import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/security/account_security_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/responsive_center.dart';
import '../../common/error_dialog.dart';

/// Central account-security hub: the devices signed in to this account and a
/// "sign out everywhere" control.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  Future<void> _signOutEverywhere() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutEverywhereTitle),
        content: Text(l10n.signOutEverywhereBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.signOutAll)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(accountSecurityServiceProvider).signOutEverywhere();
      ref.invalidate(accountDevicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signedOutOtherDevices)),
        );
      }
    } catch (_) {
      if (mounted) {
        AppErrorDialog.show(
          context: context,
          message: l10n.couldNotComplete,
          title: l10n.signOutFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devicesAsync = ref.watch(accountDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.security)),
      body: ResponsiveCenter(
        child: ListView(
          children: [
            _sectionHeader(context, l10n.whereYouSignedIn),
            devicesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l10n.couldNotLoadDevices),
              ),
              data: (devices) {
                if (devices.isEmpty) {
                  return ListTile(
                      title: Text(l10n.noOtherDevices));
                }
                return Column(
                  children: [for (final d in devices) _deviceTile(context, d)],
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOutAllOtherDevices),
                onPressed: _signOutEverywhere,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: Text(l10n.sendFeedback),
              subtitle: Text(l10n.feedbackMenuSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(BuildContext context, AccountDevice d) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final location = (d.location != null && d.location!.isNotEmpty)
        ? d.location!
        : (d.ip != null && d.ip!.isNotEmpty ? d.ip! : l10n.locationUnavailable);

    return ListTile(
      isThreeLine: true,
      leading: const Icon(Icons.smartphone),
      title: Text(_friendlyDeviceName(d.userAgent, l10n)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(location)),
            ],
          ),
          if (d.lastSeen != null)
            Text(
              l10n.lastActive(
                  DateFormat('MMM d, yyyy • h:mm a').format(d.lastSeen!)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.remove,
        onPressed: () async {
          await ref.read(accountSecurityServiceProvider).revokeDevice(d.id);
          ref.invalidate(accountDevicesProvider);
        },
      ),
    );
  }

  /// Turns a raw HTTP user-agent into a friendly device label, the way consumer
  /// apps do (e.g. "LE2111 · Android 14") instead of showing the verbose
  /// "Dalvik/2.1.0 (Linux; U; Android 14; LE2111 Build/...)" string.
  String _friendlyDeviceName(String? ua, AppLocalizations l10n) {
    if (ua == null || ua.trim().isEmpty) return l10n.unknownDevice;

    // Android (Dalvik/OkHttp): "...; Android 14; LE2111 Build/UKQ..."
    final android = RegExp(r'Android\s+([\d.]+)').firstMatch(ua);
    if (android != null) {
      final version = android.group(1);
      final model = RegExp(r'Android\s+[\d.]+;\s*([^;)/]+?)\s+Build/')
          .firstMatch(ua)
          ?.group(1)
          ?.trim();
      if (model != null && model.isNotEmpty) {
        return '$model · Android $version';
      }
      return 'Android $version';
    }

    // Apple (CFNetwork/Darwin) — the UA rarely carries a marketing name.
    if (ua.contains('iPhone')) return 'iPhone';
    if (ua.contains('iPad')) return 'iPad';
    if (ua.contains('Darwin') ||
        ua.contains('CFNetwork') ||
        ua.contains('Mac OS')) {
      return 'Apple device';
    }

    // Desktop browsers / other clients.
    if (ua.contains('Windows')) return 'Windows device';
    if (ua.contains('Linux')) return 'Linux device';

    // Last resort: the leading product token (e.g. "Dalvik/2.1.0").
    final firstToken = ua.split(RegExp(r'[\s(]')).first.trim();
    return firstToken.isNotEmpty ? firstToken : l10n.unknownDevice;
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
