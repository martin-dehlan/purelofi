import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/data/auth.repository.impl.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/auth/domain/auth.repository.dart';
import 'package:purelofi/features/auth/domain/identity.service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

class _FakeAttributes extends Fake implements UserAttributes {}

/// A native sheet that hands back [token], or `null` for a closed sheet, or
/// throws [error].
class _FakeIdentity implements IdentityService {
  _FakeIdentity({this.token, this.error});

  final IdentityToken? token;
  final Object? error;
  int forgotten = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<IdentityToken?> requestToken() async {
    final Object? failure = error;
    if (failure != null) throw failure;
    return token;
  }

  @override
  Future<void> forget() async => forgotten++;
}

User _user({
  String provider = 'email',
  String? email,
  Map<String, dynamic>? metadata,
  List<UserIdentity>? identities,
}) => User(
  id: 'u1',
  appMetadata: <String, dynamic>{'provider': provider},
  userMetadata: metadata,
  aud: 'authenticated',
  email: email,
  createdAt: '2026-10-29T00:00:00Z',
  identities: identities,
);

void main() {
  late _MockAuth auth;
  late int browserOpened;
  late int deleted;

  setUpAll(() {
    registerFallbackValue(_FakeAttributes());
    registerFallbackValue(OAuthProvider.google);
    registerFallbackValue(OtpType.email);
  });

  setUp(() {
    auth = _MockAuth();
    browserOpened = 0;
    deleted = 0;
    when(
      () => auth.signInWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
        accessToken: any(named: 'accessToken'),
        nonce: any(named: 'nonce'),
      ),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => auth.updateUser(any()),
    ).thenAnswer((_) async => UserResponse.fromJson(<String, dynamic>{}));
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  AuthRepositoryImpl repository({
    _FakeIdentity? apple,
    _FakeIdentity? google,
  }) => AuthRepositoryImpl(
    auth: auth,
    apple: apple ?? _FakeIdentity(),
    google: google ?? _FakeIdentity(),
    openGoogleInBrowser: () async => browserOpened++,
    deleteOwnAccount: () async => deleted++,
  );

  group('Apple', () {
    test('a closed sheet is not a sign-in, and not an error', () async {
      final bool done = await repository().signInWithApple();

      expect(done, isFalse);
      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });

    test('hands Supabase the token and the raw nonce', () async {
      await repository(
        apple: _FakeIdentity(
          token: const IdentityToken(idToken: 'apple-jwt', nonce: 'raw'),
        ),
      ).signInWithApple();

      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: 'apple-jwt',
          nonce: 'raw',
        ),
      ).called(1);
      // No name on this sign-in: nothing to keep.
      verifyNever(() => auth.updateUser(any()));
    });

    test('keeps the name Apple tells only once', () async {
      await repository(
        apple: _FakeIdentity(
          token: const IdentityToken(
            idToken: 'apple-jwt',
            nonce: 'raw',
            name: 'Martin Dehlan',
          ),
        ),
      ).signInWithApple();

      final UserAttributes attributes =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(attributes.data, <String, dynamic>{'full_name': 'Martin Dehlan'});
    });
  });

  group('Google', () {
    test('signs in natively with the ID token', () async {
      final bool done = await repository(
        google: _FakeIdentity(token: const IdentityToken(idToken: 'g-jwt')),
      ).signInWithGoogle();

      expect(done, isTrue);
      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'g-jwt',
        ),
      ).called(1);
      expect(browserOpened, 0);
    });

    test('falls back to the browser only with no native sheet', () async {
      final bool done = await repository(
        google: _FakeIdentity(
          error: const NativeSignInUnavailable('no Play services'),
        ),
      ).signInWithGoogle();

      expect(done, isTrue);
      expect(browserOpened, 1);
    });

    test('any other failure is an error, not the browser', () async {
      await expectLater(
        repository(
          google: _FakeIdentity(error: StateError('boom')),
        ).signInWithGoogle(),
        throwsA(isA<AppError>()),
      );
      expect(browserOpened, 0);
    });
  });

  group('email', () {
    void answerCodes() {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => AuthResponse());
    }

    void answerResend() {
      when(
        () => auth.resend(
          type: any(named: 'type'),
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async => ResendResponse());
    }

    Matcher saying(String message) => throwsA(
      isA<AuthError>().having((AuthError e) => e.message, 'message', message),
    );

    test('signs in with the trimmed address and the password', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      final EmailSignIn result = await repository().signInWithPassword(
        email: '  me@example.com ',
        password: ' secret pw',
      );

      expect(result, EmailSignIn.signedIn);
      verify(
        () => auth.signInWithPassword(
          email: 'me@example.com',
          password: ' secret pw',
        ),
      ).called(1);
    });

    test('a wrong password says so in plain words', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );

      await expectLater(
        repository().signInWithPassword(email: 'me@example.com', password: 'x'),
        saying('Wrong email or password.'),
      );
    });

    test('an unconfirmed address gets a fresh code, not an error', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthException('Email not confirmed', code: 'email_not_confirmed'),
      );
      answerResend();

      final EmailSignIn result = await repository().signInWithPassword(
        email: 'me@example.com',
        password: 'secret123',
      );

      expect(result, EmailSignIn.needsCode);
      verify(
        () => auth.resend(type: OtpType.signup, email: 'me@example.com'),
      ).called(1);
    });

    test('a new account waits for its code', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => AuthResponse(user: _user(email: 'me@example.com')),
      );

      final EmailSignIn result = await repository().createAccount(
        email: ' me@example.com',
        password: 'secret123',
      );

      expect(result, EmailSignIn.needsCode);
      verify(
        () => auth.signUp(email: 'me@example.com', password: 'secret123'),
      ).called(1);
    });

    test('an address that already has an account says so', () async {
      // Supabase's stand-in for a taken address: a user with no identities.
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async =>
            AuthResponse(user: _user(identities: const <UserIdentity>[])),
      );

      await expectLater(
        repository().createAccount(
          email: 'me@example.com',
          password: 'secret123',
        ),
        saying('There is already an account with this email. Sign in instead.'),
      );
    });

    test('confirms the address with a signup code', () async {
      answerCodes();

      await repository().confirmEmail(
        email: 'me@example.com',
        code: ' 123456 ',
      );

      verify(
        () => auth.verifyOTP(
          email: 'me@example.com',
          token: '123456',
          type: OtpType.signup,
        ),
      ).called(1);
    });

    test('resends the confirmation code', () async {
      answerResend();

      await repository().resendConfirmation(' me@example.com');

      verify(
        () => auth.resend(type: OtpType.signup, email: 'me@example.com'),
      ).called(1);
    });

    test('a reset signs in with the code, then sets the password', () async {
      when(() => auth.resetPasswordForEmail(any())).thenAnswer((_) async {});
      answerCodes();

      final AuthRepositoryImpl repo = repository();
      await repo.sendPasswordReset(' me@example.com');
      await repo.resetPassword(
        email: 'me@example.com',
        code: '654321',
        newPassword: 'new secret',
      );

      verify(() => auth.resetPasswordForEmail('me@example.com')).called(1);
      verifyInOrder(<void Function()>[
        () => auth.verifyOTP(
          email: 'me@example.com',
          token: '654321',
          type: OtpType.recovery,
        ),
        () => auth.updateUser(
          any(
            that: isA<UserAttributes>().having(
              (UserAttributes a) => a.password,
              'password',
              'new secret',
            ),
          ),
        ),
      ]);
    });

    test('an expired code says so in plain words', () async {
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenThrow(
        const AuthException('Token has expired', code: 'otp_expired'),
      );

      await expectLater(
        repository().confirmEmail(email: 'me@example.com', code: '1'),
        saying('That code has expired. Send a new one.'),
      );
    });
  });

  group('leaving', () {
    test('signing out forgets the Google account on the device', () async {
      final _FakeIdentity google = _FakeIdentity();

      await repository(google: google).signOut();

      verify(() => auth.signOut()).called(1);
      expect(google.forgotten, 1);
    });

    test('deleting deletes, then signs out', () async {
      await repository().deleteAccount();

      expect(deleted, 1);
      verify(() => auth.signOut()).called(1);
    });
  });

  group('who is signed in', () {
    test('nobody is null', () {
      when(() => auth.currentUser).thenReturn(null);

      expect(repository().current, isNull);
    });

    test('reads the provider, the address and the name', () {
      when(() => auth.currentUser).thenReturn(
        _user(
          provider: 'google',
          email: 'me@example.com',
          metadata: <String, dynamic>{'full_name': 'Martin'},
        ),
      );

      expect(
        repository().current,
        const Account(
          id: 'u1',
          method: SignInMethod.google,
          email: 'me@example.com',
          name: 'Martin',
        ),
      );
    });

    test('Apple may keep the address private', () {
      when(() => auth.currentUser).thenReturn(_user(provider: 'apple'));

      expect(repository().current?.email, isNull);
      expect(repository().current?.method, SignInMethod.apple);
    });
  });
}
