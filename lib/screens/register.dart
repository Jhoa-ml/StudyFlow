import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario.dart';
import 'user_main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool mostrarPassword = false;
  bool cargando = false;

  Future<void> registrarUsuario() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (nombre.isEmpty ||
        correo.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      mostrarMensaje('Completa todos los campos');
      return;
    }

    if (password != confirmPassword) {
      mostrarMensaje('Las contraseñas no coinciden');
      return;
    }

    if (password.length < 6) {
      mostrarMensaje('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      // 1. Crear el usuario en Firebase Authentication
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: correo, password: password);

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // Actualizar el nombre en el perfil de Auth
      await firebaseUser.updateDisplayName(nombre);

      // 2. Guardar el perfil en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(firebaseUser.uid)
          .set({
            'uid': firebaseUser.uid,
            'nombre': nombre,
            'correo': correo,
            'rol': 'estudiante',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'ultimoAcceso': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      final usuario = Usuario(
        uid: firebaseUser.uid,
        nombre: nombre,
        correo: correo,
        password: '',
        rol: 'estudiante',
      );

      mostrarMensaje('¡Cuenta creada exitosamente!');

      // 3. Entrar directamente a la app
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => UserMainScreen(usuario: usuario)),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;
      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Este correo ya está registrado';
          break;
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido';
          break;
        case 'weak-password':
          mensaje = 'La contraseña es muy débil';
          break;
        default:
          mensaje = 'Error al registrar: ${e.message ?? e.code}';
      }
      mostrarMensaje(mensaje);
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje('Ocurrió un error al crear la cuenta');
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Text(
                  'Únete a StudyFlow',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF35A8FF),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Crea tu cuenta manual para organizar tu vida académica',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 35),

                // Nombre completo
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 18),

                // Correo
                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 18),

                // Contraseña
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
                const SizedBox(height: 18),

                // Confirmar Contraseña
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !mostrarPassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón de Registro
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: cargando ? null : registrarUsuario,
                    child: cargando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Registrarse',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
