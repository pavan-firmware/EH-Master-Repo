import 'package:flutter/material.dart';
import '../../../core/models/access_control_models.dart';
import '../../../core/repositories/account_home_repository.dart';
import '../../../core/theme/app_theme.dart';

class PendingInvitationsDialog extends StatefulWidget {
  const PendingInvitationsDialog({
    super.key,
    required this.accountHomeRepository,
    required this.onAccepted,
  });

  final AccountHomeRepository accountHomeRepository;
  final ValueChanged<String?> onAccepted;

  @override
  State<PendingInvitationsDialog> createState() => _PendingInvitationsDialogState();
}

class _PendingInvitationsDialogState extends State<PendingInvitationsDialog> {
  late Future<List<HomeInviteItem>> _invitationsFuture;
  String? _processingCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _invitationsFuture = widget.accountHomeRepository.listPendingInvitations();
    });
  }

  Future<void> _accept(HomeInviteItem invite) async {
    setState(() {
      _processingCode = invite.inviteCode;
      _errorMessage = null;
    });

    try {
      await widget.accountHomeRepository.acceptInvitation(invite.inviteCode);
      if (!mounted) return;
      widget.onAccepted(invite.homeId);
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingCode = null;
        _errorMessage = 'Failed to accept invitation: ${e.toString().replaceFirst('ApiException: ', '')}';
      });
    }
  }

  Future<void> _decline(HomeInviteItem invite) async {
    setState(() {
      _processingCode = invite.inviteCode;
      _errorMessage = null;
    });

    try {
      await widget.accountHomeRepository.rejectInvitation(invite.inviteCode);
      if (!mounted) return;
      _load();
      setState(() {
        _processingCode = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingCode = null;
        _errorMessage = 'Failed to decline invitation: ${e.toString().replaceFirst('ApiException: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Dialog(
      backgroundColor: tokens.bgApp,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<List<HomeInviteItem>>(
            future: _invitationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final invites = snapshot.data ?? [];
              if (invites.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 48, color: tokens.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Invitations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have any pending household invitations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.bluePrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.mark_email_unread_rounded, color: tokens.bluePrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home Invitations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'You have ${invites.length} pending invitation${invites.length > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: tokens.isDark ? tokens.errorContainer : const Color(0xFFFFE8E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: tokens.errorText, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],

                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: invites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final inv = invites[index];
                        final isProcessing = _processingCode == inv.inviteCode;
                        final isHomeAdmin = inv.role == 'ADMIN' || inv.role == 'HOME_ADMIN';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: tokens.borderControl),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inv.homeName.isEmpty ? 'EH Home' : inv.homeName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isHomeAdmin
                                          ? (tokens.isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD))
                                          : (tokens.isDark ? const Color(0xFF1B4D3E) : const Color(0xFFE8F5E9)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isHomeAdmin ? 'Home Admin' : 'Member',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isHomeAdmin ? tokens.bluePrimary : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You have been invited to join this home with ${isHomeAdmin ? 'administrative management' : 'device control and automation'} access.',
                                style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.3),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: isProcessing ? null : () => _decline(inv),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: tokens.textSecondary,
                                      side: BorderSide(color: tokens.borderControl),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Decline', style: TextStyle(fontSize: 13)),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: isProcessing ? null : () => _accept(inv),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: tokens.bluePrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
