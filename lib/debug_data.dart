// ignore_for_file: avoid_print
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Fetching students...');
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'student')
      .get();

  print('Found ${snapshot.docs.length} students.');
  for (final doc in snapshot.docs) {
    final data = doc.data();
    print('Student: ${data['displayName']} (${data['email']})');
    print('  UID: ${doc.id}');
    print('  Institution: ${data['institutionCode']}');
    print('  Lecture Group: ${data['lectureGroup']}');
    print('  Lab Group: ${data['labGroup']}');
    print('  Old Group Field: ${data['group']}');
    print('---');
  }

  print('Fetching subjects...');
  final subjectsSnap = await FirebaseFirestore.instance
      .collection('subjects')
      .get();
  for (final doc in subjectsSnap.docs) {
    final data = doc.data();
    print('Subject: ${data['name']}');
    print('  Group: ${data['group']}');
    print('  Teacher UID: ${data['teacherUid']}');
    print('---');
  }
}
