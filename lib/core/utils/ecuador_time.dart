/// Centraliza la interpretación de fechas enviadas por la API.
///
/// PostgreSQL y Node.js entregan instantes UTC. La interfaz móvil debe mostrar
/// siempre la hora civil de Ecuador continental (UTC-5), independientemente de
/// la zona horaria configurada en el dispositivo.
class EcuadorTime {
  EcuadorTime._();

  static const Duration utcOffset = Duration(hours: -5);

  static DateTime parse(Object? value, {DateTime? fallbackUtc}) {
    final text = value?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(text);
    final source = parsed ?? fallbackUtc ?? DateTime.now().toUtc();

    final utc = source.isUtc
        ? source
        : DateTime.utc(
            source.year,
            source.month,
            source.day,
            source.hour,
            source.minute,
            source.second,
            source.millisecond,
            source.microsecond,
          );

    return utc.add(utcOffset);
  }
}
