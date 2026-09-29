class Tarea {
  final int? id;
  final String titulo;
  final String materia;
  final String fecha;
  final String prioridad;
  final bool completada;
  final int? usuarioId;

  Tarea({
    this.id,
    required this.titulo,
    required this.materia,
    required this.fecha,
    required this.prioridad,
    this.completada = false,
    this.usuarioId,
  });

  factory Tarea.fromMap(Map<String, dynamic> map) {
    return Tarea(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      materia: map['materia'] as String,
      fecha: map['fecha'] as String,
      prioridad: map['prioridad'] as String,
      completada: map['completada'] == 1,
      usuarioId: map['usuario_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'materia': materia,
      'fecha': fecha,
      'prioridad': prioridad,
      'completada': completada ? 1 : 0,
      'usuario_id': usuarioId,
    };
  }

  Tarea copyWith({
    int? id,
    String? titulo,
    String? materia,
    String? fecha,
    String? prioridad,
    bool? completada,
    int? usuarioId,
  }) {
    return Tarea(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      materia: materia ?? this.materia,
      fecha: fecha ?? this.fecha,
      prioridad: prioridad ?? this.prioridad,
      completada: completada ?? this.completada,
      usuarioId: usuarioId ?? this.usuarioId,
    );
  }
}
