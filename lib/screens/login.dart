import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      // Iniciar sesión mediante Firebase Authentication.
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo obtener el usuario de Firebase');
      }

      // Buscar los datos del usuario en Firestore.
      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .get();

      if (!documento.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        mostrarMensaje(
          'Tu cuenta existe, pero no tiene un perfil registrado en StudyFlow.',
        );

        return;
      }

      final datos = documento.data()!;

      final nombre = datos['nombre']?.toString() ?? 'Usuario';
      final correoFirebase =
          datos['correo']?.toString() ?? firebaseUser.email ?? correo;
      final rol = datos['rol']?.toString() ?? 'estudiante';
      final usuario = Usuario(
        uid: firebaseUser.uid,
        nombre: nombre,
        correo: correoFirebase,
        password: '',
        rol: rol,
      );
      // Actualizar último acceso.
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .set({
            'ultimoAcceso': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      // Revisar el rol guardado en Firestore.
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
      // Cerrar una sesión anterior de Google.
      await GoogleSignIn.instance.signOut();

      // Iniciar autenticación con Google.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      // Obtener autenticación de Google.
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No se obtuvo el ID Token de Google');
      }

      // Crear credencial para Firebase.
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      // Iniciar sesión en Firebase.
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo obtener el usuario de Firebase');
      }

      // ==========================================================
      // BUSCAR O CREAR PERFIL EN FIRESTORE
      // ==========================================================

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
            googleUser.displayName ??
            'Usuario';

        correo =
            datos['correo']?.toString() ??
            firebaseUser.email ??
            googleUser.email;

        rol = datos['rol']?.toString() ?? 'usuario';

        // Actualizar información del usuario.
        await referencia.set({
          'uid': firebaseUser.uid,
          'nombre': nombre,
          'correo': correo,
          'foto': firebaseUser.photoURL ?? googleUser.photoUrl,
          'ultimoAcceso': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Primer inicio de sesión con Google.
        nombre =
            firebaseUser.displayName ?? googleUser.displayName ?? 'Usuario';

        correo = firebaseUser.email ?? googleUser.email;

        rol = 'usuario';

        await referencia.set({
          'uid': firebaseUser.uid,
          'nombre': nombre,
          'correo': correo,
          'foto': firebaseUser.photoURL ?? googleUser.photoUrl,
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

      // Enviar al panel correspondiente según Firestore.
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
