import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../models/usuario.dart';
import 'admin.dart';
import 'user_main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final correoController = TextEditingController();
  final passwordController = TextEditingController();

  bool mostrarPassword = false;
  bool cargando = false;

  final GoogleSignIn googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();

    googleSignIn.initialize(
      serverClientId:
          '278467773883-419n1bci82e1qrmett5f9dsj5kjeig3v.apps.googleusercontent.com',
    );
  }

  // ============================================================
  // LOGIN CON CORREO Y CONTRASEÑA
  // ============================================================

  Future<void> iniciarSesion() async {
    final correo = correoController.text.trim();
    final password = passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      mostrarMensaje('Completa todos los campos');
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo obtener el usuario de Firebase');
      }

      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .get();

      String nombre;
      String correoFirebase;
      String rol;

      if (!documento.exists) {
        // Si el usuario existe en Auth pero no en Firestore, creamos su perfil automáticamente
        nombre = firebaseUser.displayName ?? correo.split('@')[0];
        correoFirebase = firebaseUser.email ?? correo;
        rol = 'estudiante';

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(firebaseUser.uid)
            .set({
              'uid': firebaseUser.uid,
              'nombre': nombre,
              'correo': correoFirebase,
              'rol': rol,
              'fechaRegistro': FieldValue.serverTimestamp(),
              'ultimoAcceso': FieldValue.serverTimestamp(),
            });
      } else {
        final datos = documento.data()!;
        nombre = datos['nombre']?.toString() ?? 'Usuario';
        correoFirebase =
            datos['correo']?.toString() ?? firebaseUser.email ?? correo;
        rol = datos['rol']?.toString() ?? 'estudiante';

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(firebaseUser.uid)
            .set({
              'ultimoAcceso': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      final usuario = Usuario(
        uid: firebaseUser.uid,
        nombre: nombre,
        correo: correoFirebase,
        password: '',
        rol: rol,
      );

      if (!mounted) return;

      _navegarSegunRol(rol, usuario);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          mensaje = 'Correo o contraseña incorrectos';
          break;

        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido';
          break;

        case 'user-disabled':
          mensaje = 'Esta cuenta está deshabilitada';
          break;

        case 'too-many-requests':
          mensaje = 'Demasiados intentos. Intenta nuevamente más tarde';
          break;

        default:
          mensaje = 'No se pudo iniciar sesión: ${e.message ?? e.code}';
      }

      mostrarMensaje(mensaje);
    } catch (e) {
      if (!mounted) return;

      mostrarMensaje('Ocurrió un error al iniciar sesión');
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  // ============================================================
  // LOGIN CON GOOGLE
  // ============================================================

  Future<void> iniciarSesionGoogle() async {
    setState(() {
      cargando = true;
    });

    try {
      await GoogleSignIn.instance.signOut();

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No se obtuvo el ID Token de Google');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo obtener el usuario de Firebase');
      }

      await _procesarUsuarioSocial(
        firebaseUser: firebaseUser,
        nombreFallback: googleUser.displayName,
        correoFallback: googleUser.email,
        fotoFallback: googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      mostrarMensaje('Error de Firebase: ${e.message ?? e.code}');
    } on GoogleSignInException catch (e) {
      if (!mounted) return;

      mostrarMensaje('Error de Google: ${e.description ?? e.code}');
    } catch (e) {
      if (!mounted) return;

      mostrarMensaje('No se pudo iniciar sesión con Google');
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  // ============================================================
  // LOGIN CON FACEBOOK
  // ============================================================

  Future<void> iniciarSesionFacebook() async {
    setState(() {
      cargando = true;
    });

    try {
      await FacebookAuth.instance.logOut();

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;

        final OAuthCredential credential = FacebookAuthProvider.credential(
          accessToken.tokenString,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        final firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('No se pudo obtener el usuario de Firebase');
        }

        final facebookData = await FacebookAuth.instance.getUserData();

        final String? nombreFb = facebookData['name']?.toString();
        final String? correoFb = facebookData['email']?.toString();
        final String? fotoFb = facebookData['picture']?['data']?['url']
            ?.toString();

        await _procesarUsuarioSocial(
          firebaseUser: firebaseUser,
          nombreFallback: nombreFb,
          correoFallback: correoFb,
          fotoFallback: fotoFb,
        );
      } else if (result.status == LoginStatus.cancelled) {
        if (!mounted) return;
        mostrarMensaje('Inicio de sesión con Facebook cancelado');
      } else {
        if (!mounted) return;
        mostrarMensaje('Error de Facebook: ${result.message}');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mostrarMensaje('Error de Firebase: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje('No se pudo iniciar sesión con Facebook');
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  // ============================================================
  // REGISTRO Y GESTIÓN EN FIRESTORE
  // ============================================================

  Future<void> _procesarUsuarioSocial({
    required User firebaseUser,
    String? nombreFallback,
    String? correoFallback,
    String? fotoFallback,
  }) async {
    final referencia = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(firebaseUser.uid);

    final documento = await referencia.get();

    String nombre;
    String correo;
    String rol;

    if (documento.exists) {
      final datos = documento.data()!;

      nombre =
          datos['nombre']?.toString() ??
          firebaseUser.displayName ??
          nombreFallback ??
          'Usuario';

      correo =
          datos['correo']?.toString() ??
          firebaseUser.email ??
          correoFallback ??
          '';

      rol = datos['rol']?.toString() ?? 'estudiante';

      await referencia.set({
        'uid': firebaseUser.uid,
        'nombre': nombre,
        'correo': correo,
        'foto': firebaseUser.photoURL ?? fotoFallback,
        'ultimoAcceso': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      nombre = firebaseUser.displayName ?? nombreFallback ?? 'Usuario';
      correo = firebaseUser.email ?? correoFallback ?? '';
      rol = 'estudiante';

      await referencia.set({
        'uid': firebaseUser.uid,
        'nombre': nombre,
        'correo': correo,
        'foto': firebaseUser.photoURL ?? fotoFallback,
        'rol': rol,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

    final usuario = Usuario(
      uid: firebaseUser.uid,
      nombre: nombre,
      correo: correo,
      password: '',
      rol: rol,
    );

    _navegarSegunRol(rol, usuario);
  }

  void _navegarSegunRol(String rol, Usuario usuario) {
    if (rol == 'administrador') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminScreen(usuario: usuario)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserMainScreen(usuario: usuario)),
      );
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================

  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    correoController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF35A8FF),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'StudyFlow',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF35A8FF),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Organiza tu vida académica',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),

                const SizedBox(height: 45),

                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: passwordController,
                  obscureText: !mostrarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        mostrarPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          mostrarPassword = !mostrarPassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: cargando ? null : iniciarSesion,
                    child: cargando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('O', style: TextStyle(color: Colors.white54)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 18),

                // BOTÓN GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: cargando ? null : iniciarSesionGoogle,
                    icon: const Icon(Icons.account_circle_outlined, size: 25),
                    label: const Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // BOTÓN FACEBOOK
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: cargando ? null : iniciarSesionFacebook,
                    icon: const Icon(
                      Icons.facebook,
                      size: 25,
                      color: Color(0xFF1877F2),
                    ),
                    label: const Text(
                      'Continuar con Facebook',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'StudyFlow • Gestión académica',
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
