import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web options are not configured.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options are configured for Android and iOS only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA7rpMVRPp3ZMaGpy6Vp-GguAzmaZhsoSo',
    appId: '1:914262169818:android:049a676b579840a708ade3',
    messagingSenderId: '914262169818',
    projectId: 'chatmate-4485a',
    storageBucket: 'chatmate-4485a.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDlU-MDSBCKR7egV4Txc5qrAN6D4oJ4lnA',
    appId: '1:914262169818:ios:c5612e5fa2de942d08ade3',
    messagingSenderId: '914262169818',
    projectId: 'chatmate-4485a',
    storageBucket: 'chatmate-4485a.appspot.com',
    iosBundleId: 'com.yash.drovenue',
  );
}
