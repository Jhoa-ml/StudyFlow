import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/usuario.dart';
import '../firebase_options.dart';
import 'gestion_tareas.dart';
import 'login.dart';

class AdminScreen extends StatefulWidget {
  final Usuario usuario;

  const AdminScreen({super.key, required this.usuario});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Usuario> usuarios = [];

  String busqueda = '';

  int totalTareas = 0;
  int tareasPendientes = 0;
  int tareasCompletadas = 0;
  int totalUsuariosFirebase = 0;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  // ============================================================
  // CARGAR USUARIOS Y TAREAS DESDE FIRESTORE
  // ============================================================

  Future<void> cargarDatos() async {
    try {
      final usuariosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('nombre')
          .get();

      final tareasSnapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .get();

      final usuariosFirebase = usuariosSnapshot.docs.map((doc) {
        final datos = doc.data();

        return Usuario(
          uid: doc.id,
          nombre: datos['nombre']?.toString() ?? 'Usuario',
          correo: datos['correo']?.toString() ?? '',
          password: '',
          rol: datos['rol']?.toString() ?? 'estudiante',
        );
      }).toList();

      int completadas = 0;

      for (final tarea in tareasSnapshot.docs) {
        final datos = tarea.data();
        final completada = datos['completada'];

        if (completada == true || completada == 1) {
          completadas++;
        }
      }

      if (!mounted) return;

      setState(() {
        usuarios = usuariosFirebase;
        totalUsuariosFirebase = usuariosFirebase.length;
        totalTareas = tareasSnapshot.docs.length;
        tareasCompletadas = completadas;
        tareasPendientes = tareasSnapshot.docs.length - completadas;
      });
    } catch (e) {
      debugPrint('Error al cargar datos de Firebase: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los datos: $e')),
      );
    }
  }

  // ============================================================
  // FILTRO DE USUARIOS
  // ============================================================

  List<Usuario> get usuariosFiltrados {
    final texto = busqueda.toLowerCase().trim();

    if (texto.isEmpty) {
      return usuarios;
    }

    return usuarios.where((usuario) {
      return usuario.nombre.toLowerCase().contains(texto) ||
          usuario.correo.toLowerCase().contains(texto);
    }).toList();
  }

  // ============================================================
  // ESTADÍSTICAS
  // ============================================================

  int get totalEstudiantes {
    return usuarios.where((usuario) => usuario.rol == 'estudiante').length;
  }

  int get totalAdministradores {
    return usuarios.where((usuario) => usuario.rol == 'administrador').length;
  }

  double get progresoTareas {
    if (totalTareas == 0) {
      return 0;
    }

    return tareasCompletadas / totalTareas;
  }

  // ============================================================
  // CREAR / EDITAR USUARIO
  // ============================================================

  Future<void> mostrarFormulario({Usuario? usuario}) async {
    final nombreController = TextEditingController(text: usuario?.nombre ?? '');

    final correoController = TextEditingController(text: usuario?.correo ?? '');

    final passwordController = TextEditingController();

    String rol = usuario?.rol ?? 'estudiante';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(usuario == null ? 'Nuevo usuario' : 'Editar usuario'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (usuario == null)
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),

                    if (usuario == null) const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'estudiante',
                          child: Text('Estudiante'),
                        ),
                        DropdownMenuItem(
                          value: 'administrador',
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            rol = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),

                FilledButton(
                  onPressed: () async {
                    final nombre = nombreController.text.trim();

                    final correo = correoController.text.trim();

                    final password = passwordController.text.trim();

                    if (nombre.isEmpty || correo.isEmpty) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Completa todos los campos.'),
                        ),
                      );

                      return;
                    }

                    if (usuario == null && password.length < 6) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La contraseña debe tener al menos 6 caracteres.',
                          ),
                        ),
                      );

                      return;
                    }

                    try {
                      if (usuario == null) {
                        // =================================================
                        // CREAR CUENTA EN FIREBASE AUTH
                        // =================================================

                        final secondaryApp = await Firebase.initializeApp(
                          name:
                              'adminCreateUser_${DateTime.now().millisecondsSinceEpoch}',
                          options: DefaultFirebaseOptions.currentPlatform,
                        );

                        try {
                          final secondaryAuth = FirebaseAuth.instanceFor(
                            app: secondaryApp,
                          );

                          final resultado = await secondaryAuth
                              .createUserWithEmailAndPassword(
                                email: correo,
                                password: password,
                              );

                          final nuevoUsuario = resultado.user;

                          if (nuevoUsuario == null) {
                            throw Exception('No se pudo crear la cuenta.');
                          }

                          // =================================================
                          // CREAR PERFIL EN FIRESTORE
                          // =================================================

                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(nuevoUsuario.uid)
                              .set({
                                'uid': nuevoUsuario.uid,
                                'nombre': nombre,
                                'correo': correo,
                                'rol': rol,
                                'fechaRegistro': FieldValue.serverTimestamp(),
                                'ultimoAcceso': null,
                              });

                          await secondaryAuth.signOut();
                        } finally {
                          await secondaryApp.delete();
                        }
                      } else {
                        // =================================================
                        // EDITAR USUARIO EN FIRESTORE
                        // =================================================

                        final consulta = await FirebaseFirestore.instance
                            .collection('usuarios')
                            .where('correo', isEqualTo: usuario.correo)
                            .limit(1)
                            .get();

                        if (consulta.docs.isEmpty) {
                          throw Exception('Usuario no encontrado.');
                        }

                        final referencia = consulta.docs.first.reference;

                        await referencia.update({
                          'nombre': nombre,
                          'correo': correo,
                          'rol': rol,
                        });
                      }

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);

                      await cargarDatos();

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            usuario == null
                                ? 'Usuario creado correctamente.'
                                : 'Usuario actualizado correctamente.',
                          ),
                        ),
                      );
                    } on FirebaseAuthException catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      String mensaje;

                      switch (e.code) {
                        case 'email-already-in-use':
                          mensaje =
                              'Ese correo ya está registrado en Firebase.';
                          break;

                        case 'invalid-email':
                          mensaje = 'El correo electrónico no es válido.';
                          break;

                        case 'weak-password':
                          mensaje = 'La contraseña es demasiado débil.';
                          break;

                        default:
                          mensaje =
                              'No se pudo crear el usuario: ${e.message ?? e.code}';
                      }

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text(mensaje)));
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo guardar el usuario: $e'),
                        ),
                      );
                    }
                  },
                  child: Text(usuario == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
  }

  // ============================================================
  // ELIMINAR USUARIO
  // ============================================================

  Future<void> eliminarUsuario(Usuario usuario) async {
    if (usuario.rol == 'administrador') {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes eliminar un administrador.')),
      );

      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar usuario'),
          content: Text('¿Eliminar a ${usuario.nombre}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmar != true) {
      return;
    }

    try {
      final consulta = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('correo', isEqualTo: usuario.correo)
          .limit(1)
          .get();

      if (consulta.docs.isEmpty) {
        throw Exception('Usuario no encontrado.');
      }

      await consulta.docs.first.reference.delete();

      await cargarDatos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el usuario: $e')),
      );
    }
  }

  // ============================================================
  // GESTIÓN DE TAREAS
  // ============================================================

  Future<void> abrirGestionTareas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GestionTareasScreen()),
    );

    if (!mounted) return;

    await cargarDatos();
  }

  // ============================================================
  // PERFIL
  // ============================================================

  void abrirPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPerfilScreen(usuario: widget.usuario),
      ),
    );
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lista = usuariosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel administrativo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),

          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: abrirPerfil,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF35A8FF),
                child: Text(
                  usuarioInicial,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),

      body: RefreshIndicator(
        onRefresh: cargarDatos,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hola, ${widget.usuario.nombre}',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            const Text(
              'Administración de StudyFlow',
              style: TextStyle(color: Colors.white54),
            ),

            const SizedBox(height: 25),

            const Text(
              'Resumen del sistema',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.groups,
                    titulo: 'Usuarios',
                    valor: totalUsuariosFirebase,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.school_outlined,
                    titulo: 'Estudiantes',
                    valor: totalEstudiantes,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.assignment_outlined,
                    titulo: 'Tareas',
                    valor: totalTareas,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.check_circle_outline,
                    titulo: 'Completadas',
                    valor: tareasCompletadas,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1727),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progreso de tareas',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      Text(
                        '${(progresoTareas * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF35A8FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progresoTareas,
                      minHeight: 9,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '$tareasCompletadas completadas • '
                    '$tareasPendientes pendientes',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1727),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF35A8FF),
                  child: Icon(Icons.assignment_outlined, color: Colors.white),
                ),
                title: const Text(
                  'Gestión de tareas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Crear y asignar tareas a estudiantes'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: abrirGestionTareas,
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              onChanged: (value) {
                setState(() {
                  busqueda = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: Icon(Icons.search),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usuarios',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),

                Text(
                  '${lista.length}',
                  style: const TextStyle(
                    color: Color(0xFF35A8FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (lista.isEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1727),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 45,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      busqueda.isEmpty
                          ? 'No hay usuarios registrados'
                          : 'No se encontraron usuarios',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),

            ...lista.map(
              (usuario) => Card(
                color: const Color(0xFF0B1727),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF35A8FF),
                    child: Text(
                      usuario.nombre.isNotEmpty
                          ? usuario.nombre[0].toUpperCase()
                          : 'U',
                    ),
                  ),

                  title: Text(usuario.nombre),

                  subtitle: Text('${usuario.correo}\n${usuario.rol}'),

                  isThreeLine: true,

                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'editar') {
                        mostrarFormulario(usuario: usuario);
                      } else {
                        eliminarUsuario(usuario);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get usuarioInicial {
    final nombre = widget.usuario.nombre.trim();

    if (nombre.isEmpty) {
      return 'A';
    }

    return nombre[0].toUpperCase();
  }
}

// ============================================================
// PERFIL DEL ADMINISTRADOR
// ============================================================

class AdminPerfilScreen extends StatefulWidget {
  final Usuario usuario;

  const AdminPerfilScreen({super.key, required this.usuario});

  @override
  State<AdminPerfilScreen> createState() => _AdminPerfilScreenState();
}

class _AdminPerfilScreenState extends State<AdminPerfilScreen> {
  int totalUsuarios = 0;
  int totalEstudiantes = 0;
  int totalAdministradores = 0;
  int totalTareas = 0;
  int tareasCompletadas = 0;
  int tareasPendientes = 0;

  @override
  void initState() {
    super.initState();
    cargarEstadisticas();
  }

  // ==========================================================
  // ESTADÍSTICAS DESDE FIRESTORE
  // ==========================================================

  Future<void> cargarEstadisticas() async {
    try {
      final usuariosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .get();

      final tareasSnapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .get();

      int estudiantes = 0;
      int administradores = 0;
      int completadas = 0;

      for (final usuario in usuariosSnapshot.docs) {
        final datos = usuario.data();

        if (datos['rol'] == 'estudiante') {
          estudiantes++;
        } else if (datos['rol'] == 'administrador') {
          administradores++;
        }
      }

      for (final tarea in tareasSnapshot.docs) {
        final datos = tarea.data();

        final completada = datos['completada'];

        if (completada == true || completada == 1) {
          completadas++;
        }
      }

      if (!mounted) return;

      setState(() {
        totalUsuarios = usuariosSnapshot.docs.length;

        totalEstudiantes = estudiantes;

        totalAdministradores = administradores;

        totalTareas = tareasSnapshot.docs.length;

        tareasCompletadas = completadas;

        tareasPendientes = tareasSnapshot.docs.length - completadas;
      });
    } catch (e) {
      debugPrint('Error al cargar estadísticas: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las estadísticas: $e')),
      );
    }
  }

  double get progreso {
    if (totalTareas == 0) {
      return 0;
    }

    return tareasCompletadas / totalTareas;
  }

  // ==========================================================
  // CERRAR SESIÓN
  // ==========================================================

  Future<void> cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ==========================================================
  // CAMBIAR CONTRASEÑA
  // ==========================================================

  Future<void> cambiarPassword() async {
    String actual = '';
    String nueva = '';
    String confirmar = '';

    bool mostrarActual = false;
    bool mostrarNueva = false;
    bool mostrarConfirmar = false;

    bool guardando = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (actual.trim().isEmpty ||
                  nueva.trim().isEmpty ||
                  confirmar.trim().isEmpty) {
                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos')),
                );

                return;
              }

              if (nueva.length < 6) {
                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La nueva contraseña debe tener al menos 6 caracteres',
                    ),
                  ),
                );

                return;
              }

              if (nueva != confirmar) {
                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas nuevas no coinciden'),
                  ),
                );

                return;
              }

              if (nueva == actual) {
                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('La nueva contraseña debe ser diferente'),
                  ),
                );

                return;
              }

              if (!dialogContext.mounted) {
                return;
              }

              setDialogState(() {
                guardando = true;
              });

              try {
                final firebaseUser = FirebaseAuth.instance.currentUser;

                if (firebaseUser == null) {
                  throw Exception('No hay una sesión activa.');
                }

                final email = firebaseUser.email;

                if (email == null || email.isEmpty) {
                  throw Exception('La cuenta no tiene correo electrónico.');
                }

                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: actual,
                );

                await firebaseUser.reauthenticateWithCredential(credential);

                await firebaseUser.updatePassword(nueva);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña actualizada correctamente'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  guardando = false;
                });

                String mensaje;

                switch (e.code) {
                  case 'wrong-password':
                  case 'invalid-credential':
                    mensaje = 'La contraseña actual es incorrecta.';
                    break;

                  case 'too-many-requests':
                    mensaje = 'Demasiados intentos. Intenta más tarde.';
                    break;

                  case 'requires-recent-login':
                    mensaje =
                        'Debes iniciar sesión nuevamente antes de cambiar la contraseña.';
                    break;

                  default:
                    mensaje =
                        'No se pudo actualizar la contraseña: ${e.message ?? e.code}';
                }

                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(mensaje)));
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  guardando = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('No se pudo actualizar la contraseña: $e'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Cambiar contraseña'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      obscureText: !mostrarActual,
                      onChanged: (value) {
                        actual = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            mostrarActual
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              mostrarActual = !mostrarActual;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      obscureText: !mostrarNueva,
                      onChanged: (value) {
                        nueva = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            mostrarNueva
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              mostrarNueva = !mostrarNueva;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      obscureText: !mostrarConfirmar,
                      onChanged: (value) {
                        confirmar = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            mostrarConfirmar
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              mostrarConfirmar = !mostrarConfirmar;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),

                FilledButton(
                  onPressed: guardando ? null : guardar,
                  child: guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // BUILD PERFIL
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final inicial = widget.usuario.nombre.trim().isEmpty
        ? 'A'
        : widget.usuario.nombre.trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarEstadisticas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: cargarEstadisticas,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),

            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFF35A8FF),
                child: Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                widget.usuario.nombre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),

            Center(
              child: Text(
                widget.usuario.correo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF35A8FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Administrador',
                  style: TextStyle(
                    color: Color(0xFF35A8FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Resumen del sistema',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _AdminEstadisticaCard(
                    icono: Icons.groups,
                    titulo: 'Usuarios',
                    valor: totalUsuarios,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _AdminEstadisticaCard(
                    icono: Icons.school_outlined,
                    titulo: 'Estudiantes',
                    valor: totalEstudiantes,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _AdminEstadisticaCard(
                    icono: Icons.admin_panel_settings_outlined,
                    titulo: 'Admins',
                    valor: totalAdministradores,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _AdminEstadisticaCard(
                    icono: Icons.assignment_outlined,
                    titulo: 'Tareas',
                    valor: totalTareas,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1727),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estado de las tareas',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      Text(
                        '${(progreso * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF35A8FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 9,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✓ $tareasCompletadas completadas',
                        style: const TextStyle(color: Colors.greenAccent),
                      ),

                      Text(
                        '• $tareasPendientes pendientes',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Información de cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              color: const Color(0xFF0B1727),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Nombre'),
                    subtitle: Text(widget.usuario.nombre),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Correo'),
                    subtitle: Text(widget.usuario.correo),
                  ),

                  const Divider(),

                  const ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: Text('Rol'),
                    subtitle: Text('Administrador'),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('ID de administrador'),
                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.uid ?? 'No disponible',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Administración',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              color: const Color(0xFF0B1727),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.people_outline,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Gestionar usuarios'),
                    subtitle: const Text('Crear, editar y eliminar usuarios'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(
                      Icons.assignment_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Gestionar tareas'),
                    subtitle: const Text('Crear y asignar tareas'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GestionTareasScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              color: const Color(0xFF0B1727),
              child: ListTile(
                leading: const Icon(
                  Icons.lock_reset_outlined,
                  color: Color(0xFF35A8FF),
                ),
                title: const Text('Cambiar contraseña'),
                subtitle: const Text(
                  'Actualiza la contraseña de administrador',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: cambiarPassword,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TARJETA DE ESTADÍSTICA
// ============================================================

class _EstadisticaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int valor;

  const _EstadisticaCard({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 30),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),

                const SizedBox(height: 2),

                Text(
                  valor.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TARJETA DE ESTADÍSTICA DEL PERFIL
// ============================================================

class _AdminEstadisticaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int valor;

  const _AdminEstadisticaCard({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 28),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),

                const SizedBox(height: 2),

                Text(
                  valor.toString(),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
