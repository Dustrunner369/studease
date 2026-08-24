import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/services/api_service.dart';

enum AuthPhase { loading, ready, needsRegistration, error }

class AuthController extends ChangeNotifier {
  AuthPhase phase = AuthPhase.loading;
  Me? me;
  Object? error;

  Future<void> bootstrap() async {
    phase = AuthPhase.loading;
    error = null;
    notifyListeners();

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      me = await fetchMe();
      phase = AuthPhase.ready;
    } catch (e) {
      if (e is ApiException && e.needsRegistration) {
        // A real, non-anonymous identity with a valid token but no `users` row —
        // most often a Firebase session that outlived its account (e.g. cached
        // on-device across a database reset). ChooseHandlePage recovers this the
        // same way it handles an ordinary guest-just-linked-a-credential: pick a
        // handle to finish.
        phase = AuthPhase.needsRegistration;
      } else {
        error = e;
        phase = AuthPhase.error;
      }
    }

    notifyListeners();
  }

  // Refreshes state 
  Future<void> refreshMe() async {
    me = await fetchMe();
    notifyListeners();
  }

  // Allows user to input a custom handle
  Future<void> completeRegistration({required String handle, required String displayName}) async {
    me = await registerMe(handle: handle, displayName: displayName);
    phase = AuthPhase.ready;
    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final current = FirebaseAuth.instance.currentUser;

    if (current != null && current.isAnonymous) {
      await current.linkWithCredential(credential);
    } else {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    await refreshMe();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    await refreshMe();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await bootstrap();
  }
}
