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
  final _formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool mostrarPassword = false;
  bool cargando = false;

  String? _validarPasswordSegura(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa una contraseña';
    }
    if (value.length < 8) {
      return 'Debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Incluye al menos una letra mayúscula';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Incluye al menos una letra minúscula';
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
      return 'Incluye al menos un número';
    }
    // Se usa un patrón limpio de expresión regular sin interferencias
    if (!RegExp(r'(?=.*[!@#\$%^&*(),.?":{}|<>])').hasMatch(value)) {
      return 'Incluye al menos un símbolo especial (!@#\$%...)';
    }
    return null;
  }

  Future<void> registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      mostrarMensaje('Las contraseñas no coinciden');
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: correo, password: password);

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo crear el usuario');
      }

      await firebaseUser.updateDisplayName(nombre);

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
            child: Form(
              key: _formKey,
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

                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) => val == null || !val.contains('@')
                        ? 'Ingresa un correo válido'
                        : null,
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
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
                    validator: _validarPasswordSegura,
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !mostrarPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Confirma tu contraseña'
                        : null,
                  ),
                  const SizedBox(height: 30),

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
      ),
    );
  }
}
