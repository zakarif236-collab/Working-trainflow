import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

const mockFirebaseOptions = FirebaseOptions(
  apiKey: 'mock-api-key',
  appId: 'mock-app-id',
  messagingSenderId: 'mock-sender-id',
  projectId: 'mock-project-id',
);

class _FakeFirebaseCoreHostApi extends TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions options,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: options,
      isAutomaticDataCollectionEnabled: false,
      pluginConstants: <String?, Object?>{},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return <CoreInitializeResponse>[];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    return CoreFirebaseOptions(
      apiKey: mockFirebaseOptions.apiKey,
      appId: mockFirebaseOptions.appId,
      messagingSenderId: mockFirebaseOptions.messagingSenderId,
      projectId: mockFirebaseOptions.projectId,
    );
  }
}

/// Initializes mocked Firebase core channels so the app can be pumped
/// in widget tests without a native Firebase configuration.
Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FakeFirebaseCoreHostApi());
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: mockFirebaseOptions);
  }
}
