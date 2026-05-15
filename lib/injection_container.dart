import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'features/chat/chat_repository.dart';
import 'raid_service.dart';

final GetIt serviceLocator = GetIt.instance;

void configureDependencies({FirebaseFirestore? firestore}) {
  if (serviceLocator.isRegistered<FirebaseFirestore>()) {
    serviceLocator.unregister<FirebaseFirestore>();
  }
  if (serviceLocator.isRegistered<RaidService>()) {
    serviceLocator.unregister<RaidService>();
  }
  if (serviceLocator.isRegistered<ChatRepository>()) {
    serviceLocator.unregister<ChatRepository>();
  }

  final FirebaseFirestore resolvedFirestore =
      firestore ?? FirebaseFirestore.instance;

  serviceLocator.registerLazySingleton<FirebaseFirestore>(
    () => resolvedFirestore,
  );
  serviceLocator.registerFactory<RaidService>(
    () => RaidService(firestore: serviceLocator<FirebaseFirestore>()),
  );
  serviceLocator.registerFactory<ChatRepository>(
    () =>
        FirestoreChatRepository(firestore: serviceLocator<FirebaseFirestore>()),
  );
}
