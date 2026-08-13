import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger.dart';

/// Service to initialize Firestore collections on first launch
class FirestoreInitService {
  final FirebaseFirestore _firestore;

  FirestoreInitService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize all necessary Firestore collections and indexes
  /// This is called on app startup to ensure database structure exists
  Future<void> initializeDatabase() async {
    try {
      // Check if initialization has already been done
      final initDoc = await _firestore
          .collection('_system')
          .doc('initialized')
          .get();

      if (initDoc.exists && initDoc.data()?['initialized'] == true) {
        // Database already initialized
        return;
      }

      // Initialize collections by creating initial documents
      await _createCollectionIfNeeded('users');
      await _createCollectionIfNeeded('sessions');
      await _createCollectionIfNeeded('institutions');
      await _createCollectionIfNeeded('class_groups');
      await _createCollectionIfNeeded('subjects');
      await _createCollectionIfNeeded('scheduled_sessions');

      // Mark as initialized
      await _firestore.collection('_system').doc('initialized').set({
        'initialized': true,
        'version': '1.0.0',
        'initializedAt': FieldValue.serverTimestamp(),
      });

      appLogger.i('Firestore database initialized successfully');
    } catch (e) {
      appLogger.w('Error initializing Firestore', error: e);
      // Don't throw - app should continue even if initialization fails
    }
  }

  /// Create a collection with a placeholder document if it doesn't exist
  Future<void> _createCollectionIfNeeded(String collectionName) async {
    try {
      // Check if collection has any documents
      final snapshot = await _firestore
          .collection(collectionName)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Collection doesn't exist or is empty, create a placeholder
        await _firestore.collection(collectionName).doc('_placeholder').set({
          '_placeholder': true,
          'createdAt': FieldValue.serverTimestamp(),
          'description':
              'This is a placeholder document to ensure the collection exists. It will be automatically cleaned up.',
        });

        // Delete the placeholder immediately (it already created the collection)
        await _firestore
            .collection(collectionName)
            .doc('_placeholder')
            .delete();

        appLogger.d('Created collection: $collectionName');
      }
    } catch (e) {
      appLogger.w('Error creating collection $collectionName', error: e);
    }
  }

  /// Ensure required indexes exist (informational - indexes must be created via Firebase Console)
  void logRequiredIndexes() {
    appLogger.i('''
Required Firestore Indexes:

CRITICAL - Collection Group Indexes (Must be created manually):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Collection Group: attendance
   Fields: timestamp (Descending)
   Query Scope: Collection group
   Used by: Recent Attendance Dashboard, Admin Analytics
   
2. Collection Group: attendance
   Fields: uid (Ascending), timestamp (Descending)
   Query Scope: Collection group
   ⚡ Used by: Student Attendance History
   
3. Collection Group: attendance
   Fields: timestamp (Ascending/Descending) - both directions
   Query Scope: Collection group
   ⚡ Used by: Attendance Analytics, Charts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Standard Collection Indexes:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. Collection: sessions
   Fields: active (Ascending), createdAt (Descending)
   
5. Collection: sessions
   Fields: teacherUid (Ascending), createdAt (Descending)
   
6. Collection: sessions
   Fields: createdAt (Ascending), createdAt (Descending)
   
7. Collection: users
   Fields: role (Ascending), displayName (Ascending)
   
8. Collection: users
   Fields: role (Ascending), approved (Ascending)
   
9. Collection: users
   Fields: role (Ascending), createdAt (Descending)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 HOW TO CREATE INDEXES:
1. When you see an index error, Firebase will provide a direct link
2. Click the link to auto-create the index in Firebase Console
3. Wait 2-3 minutes for the index to build
4. Refresh your app

Or manually create at:
https://console.firebase.google.com/project/attendify/firestore/indexes

⚠️  If you see "missing index" errors, look for the Firebase Console link in the error message!
''');
  }

  /// Create initial demo data for testing (optional, only for development)
  Future<void> createDemoData() async {
    try {
      // Check if demo data already exists
      final demoCheck = await _firestore
          .collection('_system')
          .doc('demo_created')
          .get();
      if (demoCheck.exists) {
        appLogger.d('Demo data already exists');
        return;
      }

      appLogger.w(
        'Creating demo data is disabled. All data should be created through the app UI.',
      );

      // Mark demo as "not created" to prevent re-runs
      await _firestore.collection('_system').doc('demo_created').set({
        'created': false,
        'message':
            'Demo data creation is disabled. Use the app UI to create data.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLogger.e('Error with demo data', error: e);
    }
  }

  /// Verify database structure and permissions
  Future<Map<String, dynamic>> verifyDatabaseStructure() async {
    final results = <String, dynamic>{};

    try {
      // Check users collection
      final usersCount =
          (await _firestore.collection('users').count().get()).count;
      results['users'] = {'exists': true, 'count': usersCount};

      // Check sessions collection
      final sessionsCount =
          (await _firestore.collection('sessions').count().get()).count;
      results['sessions'] = {'exists': true, 'count': sessionsCount};

      // Check institutions collection
      final institutionsCount =
          (await _firestore.collection('institutions').count().get()).count;
      results['institutions'] = {'exists': true, 'count': institutionsCount};

      results['status'] = 'healthy';
    } catch (e) {
      results['status'] = 'error';
      results['error'] = e.toString();
    }

    return results;
  }
}
