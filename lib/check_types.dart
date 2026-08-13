// ignore_for_file: avoid_print
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Checking user data types...');

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .limit(10)
      .get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final idNumber = data['idNumber'];
    final rollNumber = data['rollNumber'];

    print('User ${doc.id}:');
    print('  idNumber: $idNumber (${idNumber.runtimeType})');
    print('  rollNumber: $rollNumber (${rollNumber.runtimeType})');
  }

  print('Done.');
}
