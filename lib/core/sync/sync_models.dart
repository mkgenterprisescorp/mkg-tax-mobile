import 'package:dio/dio.dart';

const int syncSchemaVersion = 1;

class SyncEventEnvelope {
  const SyncEventEnvelope({
    required this.schemaVersion,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.summary,
    this.eventId,
    this.operation,
    this.occurredAt,
  });

  final int schemaVersion;
  final String? eventId;
  final String entityType;
  final String entityId;
  final int entityVersion;
  final String? operation;
  final Map<String, dynamic> summary;
  final DateTime? occurredAt;

  String get cacheKey => '$entityType:$entityId';

  factory SyncEventEnvelope.fromJson(Map<String, dynamic> json) {
    final schema =
        _readInt(json['schema_version'] ?? json['schemaVersion']) ??
        syncSchemaVersion;
    if (schema != syncSchemaVersion) {
      throw FormatException('Unsupported sync schema version: $schema');
    }
    final summary = _readMap(
      json['summary'] ??
          json['data'] ??
          json['payload'] ??
          const <String, dynamic>{},
    );
    final entityType =
        (json['entity_type'] ??
                json['entityType'] ??
                summary['entity_type'] ??
                '')
            .toString();
    final entityId =
        (json['entity_id'] ?? json['entityId'] ?? summary['id'] ?? '')
            .toString();
    final entityVersion =
        _readInt(
          json['entity_version'] ??
              json['entityVersion'] ??
              summary['entity_version'] ??
              summary['version'],
        ) ??
        0;
    if (entityType.isEmpty || entityId.isEmpty) {
      throw const FormatException('Sync event is missing entity identity.');
    }
    return SyncEventEnvelope(
      schemaVersion: schema,
      eventId: (json['event_id'] ?? json['eventId'] ?? json['id'])?.toString(),
      entityType: entityType,
      entityId: entityId,
      entityVersion: entityVersion,
      operation: (json['operation'] ?? json['op'])?.toString(),
      summary: summary,
      occurredAt: DateTime.tryParse(
        '${json['occurred_at'] ?? json['occurredAt'] ?? ''}',
      ),
    );
  }

  SyncCachedSummary toCachedSummary() {
    return SyncCachedSummary(
      entityType: entityType,
      entityId: entityId,
      entityVersion: entityVersion,
      data: summary,
      updatedAt: occurredAt ?? DateTime.now().toUtc(),
    );
  }
}

class SyncPullResult {
  const SyncPullResult({
    required this.events,
    this.nextCursor,
    this.hasMore = false,
  });

  static const empty = SyncPullResult(events: []);

  final List<SyncEventEnvelope> events;
  final String? nextCursor;
  final bool hasMore;

  factory SyncPullResult.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final rawEvents =
        body['events'] ?? body['changes'] ?? body['items'] ?? const [];
    final events = <SyncEventEnvelope>[];
    if (rawEvents is List) {
      for (final raw in rawEvents) {
        if (raw is Map) {
          events.add(
            SyncEventEnvelope.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return SyncPullResult(
      events: events,
      nextCursor: (body['next_cursor'] ?? body['nextCursor'] ?? body['cursor'])
          ?.toString(),
      hasMore: body['has_more'] == true || body['hasMore'] == true,
    );
  }
}

class SyncCachedSummary {
  const SyncCachedSummary({
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.data,
    required this.updatedAt,
  });

  final String entityType;
  final String entityId;
  final int entityVersion;
  final Map<String, dynamic> data;
  final DateTime updatedAt;

  String get cacheKey => '$entityType:$entityId';

  factory SyncCachedSummary.fromJson(Map<String, dynamic> json) {
    return SyncCachedSummary(
      entityType: '${json['entity_type'] ?? json['entityType'] ?? ''}',
      entityId: '${json['entity_id'] ?? json['entityId'] ?? ''}',
      entityVersion:
          _readInt(json['entity_version'] ?? json['entityVersion']) ?? 0,
      data: _readMap(json['data']),
      updatedAt:
          DateTime.tryParse(
            '${json['updated_at'] ?? json['updatedAt'] ?? ''}',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'entity_version': entityVersion,
    'data': data,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class SyncConflict {
  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.fields,
    this.serverVersion,
    this.localVersion,
    this.serverValues = const {},
    this.localValues = const {},
    this.raw = const {},
  });

  final String entityType;
  final String entityId;
  final int? serverVersion;
  final int? localVersion;
  final List<SyncFieldConflict> fields;
  final Map<String, dynamic> serverValues;
  final Map<String, dynamic> localValues;
  final Map<String, dynamic> raw;

  factory SyncConflict.fromResponse(
    Response<Map<String, dynamic>> response, {
    required String entityType,
    required String entityId,
    Map<String, dynamic> localValues = const {},
  }) {
    final raw = Map<String, dynamic>.from(response.data ?? const {});
    final serverValues = _readMap(
      raw['server'] ?? raw['current'] ?? raw['data'],
    );
    final effectiveLocal = localValues.isEmpty
        ? _readMap(raw['local'] ?? raw['client'])
        : localValues;
    final fields = _readConflicts(raw['conflicts']);
    return SyncConflict(
      entityType: entityType,
      entityId: entityId,
      serverVersion: _readInt(
        raw['currentVersion'] ??
            raw['current_version'] ??
            raw['server_version'],
      ),
      localVersion: _readInt(
        raw['version'] ?? raw['localVersion'] ?? raw['local_version'],
      ),
      fields: fields.isNotEmpty
          ? fields
          : _diffFields(serverValues, effectiveLocal),
      serverValues: serverValues,
      localValues: effectiveLocal,
      raw: raw,
    );
  }
}

class SyncFieldConflict {
  const SyncFieldConflict({
    required this.path,
    this.serverValue,
    this.localValue,
  });

  final String path;
  final Object? serverValue;
  final Object? localValue;
}

class SyncConflictException implements Exception {
  const SyncConflictException(this.conflict);

  final SyncConflict conflict;

  String get message =>
      'This information changed on another device or in the client portal. Please review and try again.';

  @override
  String toString() => message;
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<SyncFieldConflict> _readConflicts(Object? value) {
  if (value is! List) return const [];
  return [
    for (final raw in value)
      if (raw is Map)
        SyncFieldConflict(
          path: '${raw['path'] ?? raw['field'] ?? ''}',
          serverValue:
              raw['server'] ??
              raw['server_value'] ??
              raw['serverValue'] ??
              raw['current'],
          localValue:
              raw['local'] ??
              raw['local_value'] ??
              raw['localValue'] ??
              raw['client'],
        ),
  ].where((field) => field.path.isNotEmpty).toList(growable: false);
}

List<SyncFieldConflict> _diffFields(
  Map<String, dynamic> server,
  Map<String, dynamic> local, {
  String prefix = '',
}) {
  final fields = <SyncFieldConflict>[];
  for (final entry in local.entries) {
    final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final localValue = entry.value;
    final serverValue = server[entry.key];
    if (localValue is Map && serverValue is Map) {
      fields.addAll(
        _diffFields(
          Map<String, dynamic>.from(serverValue),
          Map<String, dynamic>.from(localValue),
          prefix: path,
        ),
      );
    } else if ('$localValue' != '$serverValue') {
      fields.add(
        SyncFieldConflict(
          path: path,
          serverValue: serverValue,
          localValue: localValue,
        ),
      );
    }
  }
  if (fields.isEmpty) {
    fields.add(const SyncFieldConflict(path: 'version'));
  }
  return fields;
}
