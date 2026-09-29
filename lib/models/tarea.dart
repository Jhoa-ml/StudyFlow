class Tarea {
  final String id;
  final String titulo;
  final String materia;
  final String fecha;
  final String prioridad;
  final bool completada;

  Tarea({
    this.id = '',
    required this.titulo,
    required this.materia,
    required this.fecha,
    required this.prioridad,
    this.completada = false,
  });

  // Constructor flexible: acepta Tarea.fromMap(data) o Tarea.fromMap(data, id)
  factory Tarea.fromMap(Map<String, dynamic> map, [String docId = '']) {
    return Tarea(
      id: docId.isNotEmpty ? docId : (map['id']?.toString() ?? ''),
      titulo: map['titulo'] ?? map['nombre'] ?? 'Sin título',
      materia: map['materia'] ?? 'General',
      fecha: map['fechaEntrega']?.toString() ?? map['fecha']?.toString() ?? '',
      prioridad: map['prioridad'] ?? 'Media',
      completada: map['completada'] ?? map['completado'] ?? false,
    );
  }

  Map<String, dynamic> toMap(String usuarioUid) {
    return {
      'usuarioId': usuarioUid,
      'titulo': titulo,
      'materia': materia,
      'fechaEntrega': fecha,
      'prioridad': prioridad,
      'completada': completada,
    };
  }
}
