import 'package:flutter/material.dart';

import '../../../core/models/room_models.dart';
import '../../../core/models/settings_models.dart';
import '../../../core/repositories/settings_repository.dart';
import 'settings_ui.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key, required this.repository, required this.home});

  final SettingsRepository repository;
  final HomeSettingsData home;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  late final Future<_PeopleData> _data = _load();

  Future<_PeopleData> _load() async => _PeopleData(
    members: await widget.repository.getMembers(),
    invitations: await widget.repository.getPendingInvitations(),
  );

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'People at home',
    subtitle: 'Manage who can access and control this home.',
    actions: [
      PopupMenuButton<_PeopleAction>(
        tooltip: 'People actions',
        onSelected: (value) {
          if (value == _PeopleAction.invite) _invite();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _PeopleAction.invite,
            child: Text('Invite someone'),
          ),
        ],
      ),
    ],
    child: FutureBuilder<_PeopleData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PeopleLoading();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _PeopleError(onRetry: () => setState(() {}));
        }
        return _PeopleContent(
          data: snapshot.data!,
          onInvite: _invite,
          onInvitationAction: _handleInvitation,
        );
      },
    ),
  );

  void _invite() => showSettingsUnavailable(
    context,
    message: 'Connect your home to invite people and manage household access.',
  );

  Future<void> _handleInvitation(HomeInvitation invitation, bool resend) async {
    final result = resend
        ? await widget.repository.resendInvitation(invitation.id)
        : await widget.repository.cancelInvitation(invitation.id);
    if (!mounted) return;
    if (result == SettingsOperationResult.success) return;
    showSettingsUnavailable(
      context,
      message: resend
          ? 'Connect your home to resend invitations.'
          : 'Connect your home to cancel invitations.',
    );
  }
}

enum _PeopleAction { invite }

class _PeopleData {
  const _PeopleData({required this.members, required this.invitations});
  final List<HomeMember> members;
  final List<HomeInvitation> invitations;
}

class _PeopleContent extends StatelessWidget {
  const _PeopleContent({
    required this.data,
    required this.onInvite,
    required this.onInvitationAction,
  });
  final _PeopleData data;
  final VoidCallback onInvite;
  final Future<void> Function(HomeInvitation invitation, bool resend)
  onInvitationAction;

  @override
  Widget build(BuildContext context) {
    final deviceCount = RoomCatalog.preview.fold<int>(
      0,
      (sum, room) => sum + room.deviceCount,
    );
    final onlineCount = RoomCatalog.preview
        .where((room) => room.isOnline)
        .fold<int>(0, (sum, room) => sum + room.deviceCount);
    final ownerCount = data.members
        .where((member) => member.role == HomeMemberRole.owner)
        .length;
    final memberCount = data.members.length - ownerCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        SettingsSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsIconBadge(icon: Icons.groups_rounded, size: 72),
              const SizedBox(height: 14),
              Text(
                '${data.members.length} people have access',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$ownerCount home owner · $memberCount members',
                style: const TextStyle(
                  color: SettingsColors.muted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: SettingsColors.paleGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: SettingsColors.green, size: 12),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Home access is active',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SettingsColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: SettingsColors.line),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AccessStat(
                    icon: Icons.meeting_room_outlined,
                    value: '${RoomCatalog.preview.length}',
                    label: 'Rooms',
                    color: SettingsColors.blue,
                  ),
                  _AccessStat(
                    icon: Icons.inventory_2_outlined,
                    value: '$deviceCount',
                    label: 'Devices',
                    color: SettingsColors.green,
                  ),
                  _AccessStat(
                    icon: Icons.check_circle_outline_rounded,
                    value: '$onlineCount',
                    label: 'Online',
                    color: const Color(0xFF7A3DD5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsSurface(
          color: const Color(0xFFF3F7FF),
          borderColor: const Color(0xFFD8E5FF),
          child: InkWell(
            onTap: onInvite,
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: SettingsColors.blue,
                    foregroundColor: Colors.white,
                    radius: 24,
                    child: Icon(Icons.add_rounded, size: 28),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite someone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Give family or friends access to this home',
                          style: TextStyle(color: SettingsColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: SettingsColors.ink),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const SettingsSectionTitle('People with access'),
        SettingsSurface(
          child: Column(
            children: [
              for (var index = 0; index < data.members.length; index++)
                _MemberRow(
                  member: data.members[index],
                  showDivider: index != data.members.length - 1,
                ),
            ],
          ),
        ),
        if (data.invitations.isNotEmpty) ...[
          const SizedBox(height: 26),
          SettingsSectionTitle(
            'Pending invitations',
            trailing: _CountBadge(count: data.invitations.length),
          ),
          SettingsSurface(
            child: Column(
              children: data.invitations
                  .map(
                    (invitation) => _InvitationRow(
                      invitation: invitation,
                      onAction: onInvitationAction,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SettingsSurface(
          color: const Color(0xFFF2F6FF),
          borderColor: const Color(0xFFD8E5FF),
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                SettingsIconBadge(icon: Icons.verified_user_outlined, size: 54),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A safe and secure home',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Only people you invite can access and control supported devices in your home.',
                        style: TextStyle(
                          color: SettingsColors.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessStat extends StatelessWidget {
  const _AccessStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(color: SettingsColors.muted, fontSize: 13),
        ),
      ],
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.showDivider});
  final HomeMember member;
  final bool showDivider;
  @override
  Widget build(BuildContext context) {
    final owner = member.role == HomeMemberRole.owner;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: owner
                    ? SettingsColors.paleBlue
                    : SettingsColors.paleGreen,
                foregroundColor: owner
                    ? SettingsColors.blue
                    : SettingsColors.green,
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (owner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SettingsColors.paleBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(
                                color: SettingsColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owner
                          ? 'Home owner'
                          : 'Member · ${member.lastActiveLabel ?? 'Access active'}',
                      style: TextStyle(
                        color: owner
                            ? SettingsColors.muted
                            : SettingsColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                owner ? Icons.more_vert_rounded : Icons.chevron_right_rounded,
                color: SettingsColors.muted,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 80),
            child: Divider(height: 1, color: SettingsColors.line),
          ),
      ],
    );
  }
}

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({required this.invitation, required this.onAction});
  final HomeInvitation invitation;
  final Future<void> Function(HomeInvitation invitation, bool resend) onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: SettingsColors.paleOrange,
          foregroundColor: SettingsColors.orange,
          child: Text(
            invitation.initials,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation.recipientName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Invitation pending',
                style: TextStyle(color: SettingsColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                '${invitation.invitedLabel} · ${invitation.expiresLabel}',
                style: const TextStyle(
                  color: SettingsColors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              tooltip: 'Resend invitation',
              onPressed: () => onAction(invitation, true),
              icon: const Icon(Icons.send_outlined, color: SettingsColors.blue),
            ),
            IconButton(
              tooltip: 'Cancel invitation',
              onPressed: () => onAction(invitation, false),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: SettingsColors.red,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: SettingsColors.paleBlue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: SettingsColors.blue,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PeopleLoading extends StatelessWidget {
  const _PeopleLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      SettingsSurface(child: SizedBox(height: 210)),
      SizedBox(height: 18),
      SettingsSurface(child: SizedBox(height: 90)),
      SizedBox(height: 26),
      SettingsSurface(child: SizedBox(height: 210)),
    ],
  );
}

class _PeopleError extends StatelessWidget {
  const _PeopleError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.group_off_outlined,
            size: 48,
            color: SettingsColors.muted,
          ),
          const SizedBox(height: 14),
          const Text(
            'People management is unavailable',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SettingsColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
