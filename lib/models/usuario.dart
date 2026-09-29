class Usuario {
  final String? uid;
  final String nombre;
  final String correo;
  final String password;
  final String rol;

  Usuario({
    this.uid,
    required this.nombre,
    required this.correo,
    required this.password,
    required this.rol,
  });

  factory Usuario.fromFirestore(String uid, Map<String, dynamic> data) {
    return Usuario(
      uid: uid,
      nombre: data['nombre']?.toString() ?? '',
      correo: data['correo']?.toString() ?? '',
      password: '',
      rol: data['rol']?.toString() ?? 'usuario',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'nombre': nombre, 'correo': correo, 'rol': rol};
  }
}
