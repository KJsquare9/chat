// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAzE3a53BUS__jDM1KNw9g_F8dXpGdi7E8',
    appId: '1:50383153998:web:59f068c5e9eba99a0f0c1f',
    messagingSenderId: '50383153998',
    projectId: 'chatapp-35273',
    authDomain: 'chatapp-35273.firebaseapp.com',
    storageBucket: 'chatapp-35273.firebasestorage.app',
    measurementId: 'G-BVLWXSBWSN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCFeXECcvWmJzlF-3LQvaaTu8w57vxDjY',
    appId: '1:50383153998:android:ce0c6d7c4b0381dd0f0c1f',
    messagingSenderId: '50383153998',
    projectId: 'chatapp-35273',
    storageBucket: 'chatapp-35273.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAzE3a53BUS__jDM1KNw9g_F8dXpGdi7E8',
    appId: '1:50383153998:web:6adf63da574590d40f0c1f',
    messagingSenderId: '50383153998',
    projectId: 'chatapp-35273',
    authDomain: 'chatapp-35273.firebaseapp.com',
    storageBucket: 'chatapp-35273.firebasestorage.app',
    measurementId: 'G-QCGV6XYVTE',
  );
}
