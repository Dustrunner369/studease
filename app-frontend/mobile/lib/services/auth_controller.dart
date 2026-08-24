import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/services/api_service.dart';

enum AuthPhase { loading, ready, needsRegistration, needsEmailVerification, error }

class AuthController extends ChangeNotifier {
  AuthPhase phase = AuthPhase.loading;
  Me? me;
  Object? error;

  // True once the signed-in Firebase user is a real, password-provider identity that
  // hasn't clicked their verification link yet. Google Sign-In accounts come back
  // already verified, so this never fires for those.
  bool get _needsEmailVerification {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    return hasPasswordProvider && !user.emailVerified;
  }

  Future<void> bootstrap() async {
    phase = AuthPhase.loading;
    error = null;
    notifyListeners();

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      if (_needsEmailVerification) {
        // A cached, non-anonymous session that never finished verifying — most often
        // the app was closed right after sign-up. Land back on the verify screen
        // rather than skipping ahead to /me.
        phase = AuthPhase.needsEmailVerification;
      } else {
        me = await fetchMe();
        phase = AuthPhase.ready;
      }
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

  // Shared by bootstrap() and checkVerification(): once a password-provider identity
  // is confirmed verified, resolve it exactly like any other authenticated session.
  //
  // GET /me succeeds (200) for a guest who just linked a credential — the guest's row
  // already existed before sign-up — so a thrown ApiException is NOT the only signal
  // that a handle is still needed. me.isGuest is the real one; missing this is what
  // stranded verified accounts as permanent guests before this fix.
  Future<void> completeEmailVerification() async {
    try {
      me = await fetchMe();
      phase = me!.isGuest ? AuthPhase.needsRegistration : AuthPhase.ready;
    } catch (e) {
      if (e is ApiException && e.needsRegistration) {
        phase = AuthPhase.needsRegistration;
      } else {
        error = e;
        phase = AuthPhase.error;
      }
    }
    notifyListeners();
  }

  // Re-checks Firebase for a verified email. Returns the fresh status; on true, also
  // advances phase out of needsEmailVerification.
  Future<bool> checkVerification() async {
    await FirebaseAuth.instance.currentUser!.reload();
    final verified = FirebaseAuth.instance.currentUser!.emailVerified;
    if (verified) await completeEmailVerification();
    return verified;
  }

  Future<void> resendVerificationEmail() =>
      FirebaseAuth.instance.currentUser!.sendEmailVerification();

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

    await FirebaseAuth.instance.currentUser!.sendEmailVerification();
    phase = AuthPhase.needsEmailVerification;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    await refreshMe();
  }

  // Google accounts arrive pre-verified, so — unlike signUpWithEmail — this goes
  // straight to fetchMe() rather than through needsEmailVerification. Links from an
  // active guest session the same way signUpWithEmail does, so a guest's spots carry
  // over. GoogleSignIn.instance.initialize() must already have completed (called once,
  // at startup, in main()) before this is called.
  //
  // Deliberately not refreshMe(): linking a guest's credential still returns the
  // guest's existing (isGuest: true) row from GET /me, so phase has to be decided from
  // me.isGuest here rather than just "the fetch didn't throw" — see
  // completeEmailVerification for the same fix, applied after the same bug shipped
  // here first. A genuine 404 (no row at all) still propagates to the caller, which
  // handles ApiException.needsRegistration the same way LoginPage's email path does.
  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    final current = FirebaseAuth.instance.currentUser;

    if (current != null && current.isAnonymous) {
      await current.linkWithCredential(credential);
    } else {
      await FirebaseAuth.instance.signInWithCredential(credential);
    }

    me = await fetchMe();
    phase = me!.isGuest ? AuthPhase.needsRegistration : AuthPhase.ready;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await bootstrap();
  }
}
