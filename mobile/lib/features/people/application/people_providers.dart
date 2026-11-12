import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// People the user is connected with (friends only), by name.
final FutureProvider<List<PublicProfile>> friendsProvider =
    FutureProvider.autoDispose<List<PublicProfile>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      final List<PublicProfile> all = await ref
          .read(peopleApiProvider)
          .friends();
      return all
          .where(
            (PublicProfile p) => p.connection == PublicProfileConnection.friend,
          )
          .toList()
        ..sort(
          (PublicProfile a, PublicProfile b) =>
              _byName(a.displayName, b.displayName),
        );
    });

/// The user's active groups, by name.
final FutureProvider<List<GroupDto>> groupsProvider =
    FutureProvider.autoDispose<List<GroupDto>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      final List<GroupDto> all = await ref.read(peopleApiProvider).groups();
      return all
          .where((GroupDto g) => g.status == GroupDtoStatus.active)
          .toList()
        ..sort((GroupDto a, GroupDto b) => _byName(a.name, b.name));
    });

/// Group names by ID (for labels; empty until groups load).
final Provider<Map<String, GroupDto>> groupIndexProvider =
    Provider.autoDispose<Map<String, GroupDto>>(
      (Ref ref) => <String, GroupDto>{
        for (final GroupDto g
            in ref.watch(groupsProvider).value ?? const <GroupDto>[])
          g.id: g,
      },
    );

/// One group with its members.
final FutureProviderFamily<GroupDetail, String> groupDetailProvider =
    FutureProvider.autoDispose.family<GroupDetail, String>((
      Ref ref,
      String id,
    ) async {
      ref.watch(currentUserIdProvider);
      return ref.read(peopleApiProvider).group(id);
    });

/// Current members of group [id] other than the user, by name.
final FutureProviderFamily<List<GroupMemberDto>, String> groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMemberDto>, String>((
      Ref ref,
      String id,
    ) async {
      final String? me = ref.watch(currentUserIdProvider);
      final GroupDetail group = await ref.watch(groupDetailProvider(id).future);
      return group.members
          .where(
            (GroupMemberDto m) =>
                m.status == GroupMemberDtoStatus.active && m.userId != me,
          )
          .toList()
        ..sort(
          (GroupMemberDto a, GroupMemberDto b) =>
              _byName(a.displayName, b.displayName),
        );
    });
