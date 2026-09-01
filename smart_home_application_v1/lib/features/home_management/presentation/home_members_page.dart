import 'package:flutter/material.dart';
import '../../../core/models/access_control_models.dart';
import '../../../core/repositories/account_home_repository.dart';

class HomeMembersPage extends StatefulWidget {
  const HomeMembersPage({
    super.key,
    required this.homeId,
    required this.homeName,
    required this.repository,
    this.canManageMembers = true,
  });

  final String homeId;
  final String homeName;
  final AccountHomeRepository repository;
  final bool canManageMembers;

  @override
  State<HomeMembersPage> createState() => _HomeMembersPageState();
}

class _HomeMembersPageState extends State<HomeMembersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<HomeMemberItem> _members = [];
  List<HomeInviteItem> _invitations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final members = await widget.repository.listMembers(widget.homeId);
      final invites = await widget.repository.listHomeInvitations(widget.homeId);
      if (mounted) {
        setState(() {
          _members = members;
          _invitations = invites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showInviteDialog() async {
    final emailCtrl = TextEditingController();
    String selectedRole = 'MEMBER';

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'user@example.com',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Home Role'),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin (Can manage devices & members)')),
                  DropdownMenuItem(value: 'MEMBER', child: Text('Member (Can control devices & scenes)')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer (Read-only status)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );

    if (sent == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        await widget.repository.createInvitation(
          widget.homeId,
          email: emailCtrl.text.trim(),
          role: selectedRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation sent successfully')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send invite: $e')),
          );
        }
      }
    }
  }

  Future<void> _showMemberActions(HomeMemberItem member) async {
    if (!widget.canManageMembers || member.role == 'OWNER') return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Change Role to Admin'),
              onTap: () async {
                Navigator.pop(ctx);
                await _updateRole(member.userId, 'ADMIN');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Change Role to Member'),
              onTap: () async {
                Navigator.pop(ctx);
                await _updateRole(member.userId, 'MEMBER');
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Change Role to Viewer'),
              onTap: () async {
                Navigator.pop(ctx);
                await _updateRole(member.userId, 'VIEWER');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
              title: const Text('Remove from Home', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _removeMember(member.userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await widget.repository.updateMemberRole(widget.homeId, userId: userId, role: newRole);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await widget.repository.removeMember(widget.homeId, userId: userId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  Future<void> _revokeInvite(String inviteId) async {
    try {
      await widget.repository.revokeInvitation(widget.homeId, inviteId: inviteId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke invite: $e')),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return Colors.deepPurple;
      case 'ADMIN':
        return Colors.blue;
      case 'MEMBER':
        return Colors.teal;
      case 'VIEWER':
      case 'GUEST':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.homeName} Members'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Members (${_members.length})'),
            Tab(text: 'Invitations (${_invitations.length})'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Members Tab
                    _members.isEmpty
                        ? const Center(child: Text('No members found in this home.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _members.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final m = _members[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getRoleColor(m.role).withAlpha(50),
                                  child: Text(
                                    (m.email ?? 'U')[0].toUpperCase(),
                                    style: TextStyle(color: _getRoleColor(m.role), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(m.email ?? 'User ${m.userId}'),
                                subtitle: Text('Role: ${m.role}'),
                                trailing: Chip(
                                  label: Text(m.role, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  backgroundColor: _getRoleColor(m.role),
                                ),
                                onTap: () => _showMemberActions(m),
                              );
                            },
                          ),

                    // Invitations Tab
                    _invitations.isEmpty
                        ? const Center(child: Text('No pending invitations.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invitations.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final inv = _invitations[idx];
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.mail_outline),
                                ),
                                title: Text(inv.inviteeEmail),
                                subtitle: Text('Role: ${inv.role} • Status: ${inv.status}'),
                                trailing: widget.canManageMembers
                                    ? IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        tooltip: 'Revoke Invitation',
                                        onPressed: () => _revokeInvite(inv.id),
                                      )
                                    : null,
                              );
                            },
                          ),
                  ],
                ),
      floatingActionButton: widget.canManageMembers
          ? FloatingActionButton.extended(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite'),
            )
          : null,
    );
  }
}
