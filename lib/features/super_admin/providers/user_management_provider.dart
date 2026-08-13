import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final superAdminUserSearchProvider =
    NotifierProvider<
      UserSearchNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >(UserSearchNotifier.new);

class UserSearchNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> searchUsers(String query, {String? institutionCode}) async {
    if (query.isEmpty && institutionCode == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      // Base query - NO institution filter in Firestore to avoid composite index requirement
      Query<Map<String, dynamic>> baseQuery = FirebaseFirestore.instance
          .collection('users');

      // If query is empty, we just fetch recent users (and filter by institution in memory)
      if (query.isEmpty) {
        final snapshot = await baseQuery
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
        var users = snapshot.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();

        // In-memory filter
        if (institutionCode != null && institutionCode.isNotEmpty) {
          users = users
              .where((u) => u['institutionCode'] == institutionCode)
              .toList();
        }

        state = AsyncValue.data(users);
        return;
      }

      // Search Logic
      String capitalizedQuery = query;
      if (query.isNotEmpty) {
        capitalizedQuery = query[0].toUpperCase() + query.substring(1);
      }

      final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      // Query 1: As-is
      futures.add(
        baseQuery
            .where('displayName', isGreaterThanOrEqualTo: query)
            .where('displayName', isLessThan: '${query}z')
            .limit(20)
            .get(),
      );

      // Query 2: Capitalized
      if (capitalizedQuery != query) {
        futures.add(
          baseQuery
              .where('displayName', isGreaterThanOrEqualTo: capitalizedQuery)
              .where('displayName', isLessThan: '${capitalizedQuery}z')
              .limit(20)
              .get(),
        );
      }

      // Query 3: Uppercase (e.g. "bibek" -> "BIBEK")
      final upperQuery = query.toUpperCase();
      if (upperQuery != query && upperQuery != capitalizedQuery) {
        futures.add(
          baseQuery
              .where('displayName', isGreaterThanOrEqualTo: upperQuery)
              .where('displayName', isLessThan: '${upperQuery}z')
              .limit(20)
              .get(),
        );
      }

      // Query 4: Email
      futures.add(
        baseQuery
            .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
            .where('email', isLessThan: '${query.toLowerCase()}z')
            .limit(20)
            .get(),
      );

      final results = await Future.wait(futures);

      // Deduplicate and Filter in Memory
      final Map<String, Map<String, dynamic>> uniqueResults = {};

      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          // In-memory filter for institution
          if (institutionCode != null &&
              institutionCode.isNotEmpty &&
              data['institutionCode'] != institutionCode) {
            continue;
          }

          data['id'] = doc.id;
          uniqueResults[doc.id] = data;
        }
      }

      state = AsyncValue.data(uniqueResults.values.toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
