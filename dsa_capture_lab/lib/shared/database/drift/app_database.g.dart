// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES folders (id)'));
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        parentId,
        isPinned,
        position,
        createdAt,
        isArchived,
        isDeleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(Insertable<Folder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String name;
  final int? parentId;
  final bool isPinned;
  final int position;
  final DateTime createdAt;
  final bool isArchived;
  final bool isDeleted;
  const Folder(
      {required this.id,
      required this.name,
      this.parentId,
      required this.isPinned,
      required this.position,
      required this.createdAt,
      required this.isArchived,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isPinned: Value(isPinned),
      position: Value(position),
      createdAt: Value(createdAt),
      isArchived: Value(isArchived),
      isDeleted: Value(isDeleted),
    );
  }

  factory Folder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<int?>(parentId),
      'isPinned': serializer.toJson<bool>(isPinned),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Folder copyWith(
          {int? id,
          String? name,
          Value<int?> parentId = const Value.absent(),
          bool? isPinned,
          int? position,
          DateTime? createdAt,
          bool? isArchived,
          bool? isDeleted}) =>
      Folder(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: parentId.present ? parentId.value : this.parentId,
        isPinned: isPinned ?? this.isPinned,
        position: position ?? this.position,
        createdAt: createdAt ?? this.createdAt,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('isPinned: $isPinned, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, parentId, isPinned, position, createdAt, isArchived, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.isPinned == this.isPinned &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.isArchived == this.isArchived &&
          other.isDeleted == this.isDeleted);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> parentId;
  final Value<bool> isPinned;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<bool> isArchived;
  final Value<bool> isDeleted;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.parentId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime createdAt,
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
  })  : name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? parentId,
    Expression<bool>? isPinned,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<bool>? isArchived,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (isPinned != null) 'is_pinned': isPinned,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  FoldersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int?>? parentId,
      Value<bool>? isPinned,
      Value<int>? position,
      Value<DateTime>? createdAt,
      Value<bool>? isArchived,
      Value<bool>? isDeleted}) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      isPinned: isPinned ?? this.isPinned,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('isPinned: $isPinned, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileTypeMeta =
      const VerificationMeta('fileType');
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
      'file_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('text'));
  static const VerificationMeta _folderIdMeta =
      const VerificationMeta('folderId');
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
      'folder_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES folders (id)'));
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isChecklistMeta =
      const VerificationMeta('isChecklist');
  @override
  late final GeneratedColumn<bool> isChecklist = GeneratedColumn<bool>(
      'is_checklist', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_checklist" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        content,
        thumbnailPath,
        imagePath,
        fileType,
        folderId,
        isPinned,
        position,
        color,
        isChecklist,
        isArchived,
        isDeleted,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(Insertable<Note> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('file_type')) {
      context.handle(_fileTypeMeta,
          fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta));
    }
    if (data.containsKey('folder_id')) {
      context.handle(_folderIdMeta,
          folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('is_checklist')) {
      context.handle(
          _isChecklistMeta,
          isChecklist.isAcceptableOrUnknown(
              data['is_checklist']!, _isChecklistMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      fileType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_type'])!,
      folderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}folder_id']),
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      isChecklist: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_checklist'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final String title;
  final String content;
  final String? thumbnailPath;
  final String? imagePath;
  final String fileType;
  final int? folderId;
  final bool isPinned;
  final int position;
  final int color;
  final bool isChecklist;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  const Note(
      {required this.id,
      required this.title,
      required this.content,
      this.thumbnailPath,
      this.imagePath,
      required this.fileType,
      this.folderId,
      required this.isPinned,
      required this.position,
      required this.color,
      required this.isChecklist,
      required this.isArchived,
      required this.isDeleted,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['file_type'] = Variable<String>(fileType);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['position'] = Variable<int>(position);
    map['color'] = Variable<int>(color);
    map['is_checklist'] = Variable<bool>(isChecklist);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      fileType: Value(fileType),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      isPinned: Value(isPinned),
      position: Value(position),
      color: Value(color),
      isChecklist: Value(isChecklist),
      isArchived: Value(isArchived),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
    );
  }

  factory Note.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      fileType: serializer.fromJson<String>(json['fileType']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      position: serializer.fromJson<int>(json['position']),
      color: serializer.fromJson<int>(json['color']),
      isChecklist: serializer.fromJson<bool>(json['isChecklist']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'imagePath': serializer.toJson<String?>(imagePath),
      'fileType': serializer.toJson<String>(fileType),
      'folderId': serializer.toJson<int?>(folderId),
      'isPinned': serializer.toJson<bool>(isPinned),
      'position': serializer.toJson<int>(position),
      'color': serializer.toJson<int>(color),
      'isChecklist': serializer.toJson<bool>(isChecklist),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Note copyWith(
          {int? id,
          String? title,
          String? content,
          Value<String?> thumbnailPath = const Value.absent(),
          Value<String?> imagePath = const Value.absent(),
          String? fileType,
          Value<int?> folderId = const Value.absent(),
          bool? isPinned,
          int? position,
          int? color,
          bool? isChecklist,
          bool? isArchived,
          bool? isDeleted,
          DateTime? createdAt}) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        fileType: fileType ?? this.fileType,
        folderId: folderId.present ? folderId.value : this.folderId,
        isPinned: isPinned ?? this.isPinned,
        position: position ?? this.position,
        color: color ?? this.color,
        isChecklist: isChecklist ?? this.isChecklist,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
      );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      position: data.position.present ? data.position.value : this.position,
      color: data.color.present ? data.color.value : this.color,
      isChecklist:
          data.isChecklist.present ? data.isChecklist.value : this.isChecklist,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('imagePath: $imagePath, ')
          ..write('fileType: $fileType, ')
          ..write('folderId: $folderId, ')
          ..write('isPinned: $isPinned, ')
          ..write('position: $position, ')
          ..write('color: $color, ')
          ..write('isChecklist: $isChecklist, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      content,
      thumbnailPath,
      imagePath,
      fileType,
      folderId,
      isPinned,
      position,
      color,
      isChecklist,
      isArchived,
      isDeleted,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.thumbnailPath == this.thumbnailPath &&
          other.imagePath == this.imagePath &&
          other.fileType == this.fileType &&
          other.folderId == this.folderId &&
          other.isPinned == this.isPinned &&
          other.position == this.position &&
          other.color == this.color &&
          other.isChecklist == this.isChecklist &&
          other.isArchived == this.isArchived &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String?> thumbnailPath;
  final Value<String?> imagePath;
  final Value<String> fileType;
  final Value<int?> folderId;
  final Value<bool> isPinned;
  final Value<int> position;
  final Value<int> color;
  final Value<bool> isChecklist;
  final Value<bool> isArchived;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.fileType = const Value.absent(),
    this.folderId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.position = const Value.absent(),
    this.color = const Value.absent(),
    this.isChecklist = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String content,
    this.thumbnailPath = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.fileType = const Value.absent(),
    this.folderId = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.position = const Value.absent(),
    this.color = const Value.absent(),
    this.isChecklist = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
  })  : title = Value(title),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? thumbnailPath,
    Expression<String>? imagePath,
    Expression<String>? fileType,
    Expression<int>? folderId,
    Expression<bool>? isPinned,
    Expression<int>? position,
    Expression<int>? color,
    Expression<bool>? isChecklist,
    Expression<bool>? isArchived,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (imagePath != null) 'image_path': imagePath,
      if (fileType != null) 'file_type': fileType,
      if (folderId != null) 'folder_id': folderId,
      if (isPinned != null) 'is_pinned': isPinned,
      if (position != null) 'position': position,
      if (color != null) 'color': color,
      if (isChecklist != null) 'is_checklist': isChecklist,
      if (isArchived != null) 'is_archived': isArchived,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  NotesCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? content,
      Value<String?>? thumbnailPath,
      Value<String?>? imagePath,
      Value<String>? fileType,
      Value<int?>? folderId,
      Value<bool>? isPinned,
      Value<int>? position,
      Value<int>? color,
      Value<bool>? isChecklist,
      Value<bool>? isArchived,
      Value<bool>? isDeleted,
      Value<DateTime>? createdAt}) {
    return NotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imagePath: imagePath ?? this.imagePath,
      fileType: fileType ?? this.fileType,
      folderId: folderId ?? this.folderId,
      isPinned: isPinned ?? this.isPinned,
      position: position ?? this.position,
      color: color ?? this.color,
      isChecklist: isChecklist ?? this.isChecklist,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (isChecklist.present) {
      map['is_checklist'] = Variable<bool>(isChecklist.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('imagePath: $imagePath, ')
          ..write('fileType: $fileType, ')
          ..write('folderId: $folderId, ')
          ..write('isPinned: $isPinned, ')
          ..write('position: $position, ')
          ..write('color: $color, ')
          ..write('isChecklist: $isChecklist, ')
          ..write('isArchived: $isArchived, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $NoteImagesTable extends NoteImages
    with TableInfo<$NoteImagesTable, NoteImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
      'note_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES notes (id) ON DELETE CASCADE'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, noteId, imagePath, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_images';
  @override
  VerificationContext validateIntegrity(Insertable<NoteImage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta,
          noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteImage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}note_id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $NoteImagesTable createAlias(String alias) {
    return $NoteImagesTable(attachedDatabase, alias);
  }
}

class NoteImage extends DataClass implements Insertable<NoteImage> {
  final int id;
  final int noteId;
  final String imagePath;
  final int position;
  const NoteImage(
      {required this.id,
      required this.noteId,
      required this.imagePath,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note_id'] = Variable<int>(noteId);
    map['image_path'] = Variable<String>(imagePath);
    map['position'] = Variable<int>(position);
    return map;
  }

  NoteImagesCompanion toCompanion(bool nullToAbsent) {
    return NoteImagesCompanion(
      id: Value(id),
      noteId: Value(noteId),
      imagePath: Value(imagePath),
      position: Value(position),
    );
  }

  factory NoteImage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteImage(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<int>(json['noteId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<int>(noteId),
      'imagePath': serializer.toJson<String>(imagePath),
      'position': serializer.toJson<int>(position),
    };
  }

  NoteImage copyWith(
          {int? id, int? noteId, String? imagePath, int? position}) =>
      NoteImage(
        id: id ?? this.id,
        noteId: noteId ?? this.noteId,
        imagePath: imagePath ?? this.imagePath,
        position: position ?? this.position,
      );
  NoteImage copyWithCompanion(NoteImagesCompanion data) {
    return NoteImage(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteImage(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, imagePath, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteImage &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.imagePath == this.imagePath &&
          other.position == this.position);
}

class NoteImagesCompanion extends UpdateCompanion<NoteImage> {
  final Value<int> id;
  final Value<int> noteId;
  final Value<String> imagePath;
  final Value<int> position;
  const NoteImagesCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.position = const Value.absent(),
  });
  NoteImagesCompanion.insert({
    this.id = const Value.absent(),
    required int noteId,
    required String imagePath,
    this.position = const Value.absent(),
  })  : noteId = Value(noteId),
        imagePath = Value(imagePath);
  static Insertable<NoteImage> custom({
    Expression<int>? id,
    Expression<int>? noteId,
    Expression<String>? imagePath,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (imagePath != null) 'image_path': imagePath,
      if (position != null) 'position': position,
    });
  }

  NoteImagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? noteId,
      Value<String>? imagePath,
      Value<int>? position}) {
    return NoteImagesCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteImagesCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteImagesTable noteImages = $NoteImagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [folders, notes, noteImages];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('notes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('note_images', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  required String name,
  Value<int?> parentId,
  Value<bool> isPinned,
  Value<int> position,
  required DateTime createdAt,
  Value<bool> isArchived,
  Value<bool> isDeleted,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int?> parentId,
  Value<bool> isPinned,
  Value<int> position,
  Value<DateTime> createdAt,
  Value<bool> isArchived,
  Value<bool> isDeleted,
});

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _parentIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.folders.parentId, db.folders.id));

  $$FoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.notes,
          aliasName: $_aliasNameGenerator(db.folders.id, db.notes.folderId));

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  $$FoldersTableFilterComposer get parentId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> notesRefs(
      Expression<bool> Function($$NotesTableFilterComposer f) f) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.folderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  $$FoldersTableOrderingComposer get parentId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$FoldersTableAnnotationComposer get parentId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> notesRefs<T extends Object>(
      Expression<T> Function($$NotesTableAnnotationComposer a) f) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.folderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FoldersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FoldersTable,
    Folder,
    $$FoldersTableFilterComposer,
    $$FoldersTableOrderingComposer,
    $$FoldersTableAnnotationComposer,
    $$FoldersTableCreateCompanionBuilder,
    $$FoldersTableUpdateCompanionBuilder,
    (Folder, $$FoldersTableReferences),
    Folder,
    PrefetchHooks Function({bool parentId, bool notesRefs})> {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
          }) =>
              FoldersCompanion(
            id: id,
            name: name,
            parentId: parentId,
            isPinned: isPinned,
            position: position,
            createdAt: createdAt,
            isArchived: isArchived,
            isDeleted: isDeleted,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int?> parentId = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int> position = const Value.absent(),
            required DateTime createdAt,
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
          }) =>
              FoldersCompanion.insert(
            id: id,
            name: name,
            parentId: parentId,
            isPinned: isPinned,
            position: position,
            createdAt: createdAt,
            isArchived: isArchived,
            isDeleted: isDeleted,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$FoldersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({parentId = false, notesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (notesRefs) db.notes],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$FoldersTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$FoldersTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (notesRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Note>(
                        currentTable: table,
                        referencedTable:
                            $$FoldersTableReferences._notesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FoldersTableReferences(db, table, p0).notesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.folderId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FoldersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FoldersTable,
    Folder,
    $$FoldersTableFilterComposer,
    $$FoldersTableOrderingComposer,
    $$FoldersTableAnnotationComposer,
    $$FoldersTableCreateCompanionBuilder,
    $$FoldersTableUpdateCompanionBuilder,
    (Folder, $$FoldersTableReferences),
    Folder,
    PrefetchHooks Function({bool parentId, bool notesRefs})>;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  required String title,
  required String content,
  Value<String?> thumbnailPath,
  Value<String?> imagePath,
  Value<String> fileType,
  Value<int?> folderId,
  Value<bool> isPinned,
  Value<int> position,
  Value<int> color,
  Value<bool> isChecklist,
  Value<bool> isArchived,
  Value<bool> isDeleted,
  required DateTime createdAt,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> content,
  Value<String?> thumbnailPath,
  Value<String?> imagePath,
  Value<String> fileType,
  Value<int?> folderId,
  Value<bool> isPinned,
  Value<int> position,
  Value<int> color,
  Value<bool> isChecklist,
  Value<bool> isArchived,
  Value<bool> isDeleted,
  Value<DateTime> createdAt,
});

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.notes.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager($_db, $_db.folders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$NoteImagesTable, List<NoteImage>>
      _noteImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.noteImages,
          aliasName: $_aliasNameGenerator(db.notes.id, db.noteImages.noteId));

  $$NoteImagesTableProcessedTableManager get noteImagesRefs {
    final manager = $$NoteImagesTableTableManager($_db, $_db.noteImages)
        .filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteImagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isChecklist => $composableBuilder(
      column: $table.isChecklist, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.folderId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableFilterComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> noteImagesRefs(
      Expression<bool> Function($$NoteImagesTableFilterComposer f) f) {
    final $$NoteImagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteImages,
        getReferencedColumn: (t) => t.noteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteImagesTableFilterComposer(
              $db: $db,
              $table: $db.noteImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isChecklist => $composableBuilder(
      column: $table.isChecklist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.folderId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableOrderingComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isChecklist => $composableBuilder(
      column: $table.isChecklist, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.folderId,
        referencedTable: $db.folders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FoldersTableAnnotationComposer(
              $db: $db,
              $table: $db.folders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> noteImagesRefs<T extends Object>(
      Expression<T> Function($$NoteImagesTableAnnotationComposer a) f) {
    final $$NoteImagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.noteImages,
        getReferencedColumn: (t) => t.noteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NoteImagesTableAnnotationComposer(
              $db: $db,
              $table: $db.noteImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$NotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotesTable,
    Note,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (Note, $$NotesTableReferences),
    Note,
    PrefetchHooks Function({bool folderId, bool noteImagesRefs})> {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<String> fileType = const Value.absent(),
            Value<int?> folderId = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<bool> isChecklist = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              NotesCompanion(
            id: id,
            title: title,
            content: content,
            thumbnailPath: thumbnailPath,
            imagePath: imagePath,
            fileType: fileType,
            folderId: folderId,
            isPinned: isPinned,
            position: position,
            color: color,
            isChecklist: isChecklist,
            isArchived: isArchived,
            isDeleted: isDeleted,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String content,
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<String> fileType = const Value.absent(),
            Value<int?> folderId = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<bool> isChecklist = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required DateTime createdAt,
          }) =>
              NotesCompanion.insert(
            id: id,
            title: title,
            content: content,
            thumbnailPath: thumbnailPath,
            imagePath: imagePath,
            fileType: fileType,
            folderId: folderId,
            isPinned: isPinned,
            position: position,
            color: color,
            isChecklist: isChecklist,
            isArchived: isArchived,
            isDeleted: isDeleted,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$NotesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({folderId = false, noteImagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteImagesRefs) db.noteImages],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (folderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.folderId,
                    referencedTable: $$NotesTableReferences._folderIdTable(db),
                    referencedColumn:
                        $$NotesTableReferences._folderIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteImagesRefs)
                    await $_getPrefetchedData<Note, $NotesTable, NoteImage>(
                        currentTable: table,
                        referencedTable:
                            $$NotesTableReferences._noteImagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$NotesTableReferences(db, table, p0)
                                .noteImagesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.noteId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$NotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotesTable,
    Note,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (Note, $$NotesTableReferences),
    Note,
    PrefetchHooks Function({bool folderId, bool noteImagesRefs})>;
typedef $$NoteImagesTableCreateCompanionBuilder = NoteImagesCompanion Function({
  Value<int> id,
  required int noteId,
  required String imagePath,
  Value<int> position,
});
typedef $$NoteImagesTableUpdateCompanionBuilder = NoteImagesCompanion Function({
  Value<int> id,
  Value<int> noteId,
  Value<String> imagePath,
  Value<int> position,
});

final class $$NoteImagesTableReferences
    extends BaseReferences<_$AppDatabase, $NoteImagesTable, NoteImage> {
  $$NoteImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$AppDatabase db) => db.notes
      .createAlias($_aliasNameGenerator(db.noteImages.noteId, db.notes.id));

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NotesTableTableManager($_db, $_db.notes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$NoteImagesTableFilterComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableFilterComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableOrderingComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteImagesTable> {
  $$NoteImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.noteId,
        referencedTable: $db.notes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$NotesTableAnnotationComposer(
              $db: $db,
              $table: $db.notes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$NoteImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteImagesTable,
    NoteImage,
    $$NoteImagesTableFilterComposer,
    $$NoteImagesTableOrderingComposer,
    $$NoteImagesTableAnnotationComposer,
    $$NoteImagesTableCreateCompanionBuilder,
    $$NoteImagesTableUpdateCompanionBuilder,
    (NoteImage, $$NoteImagesTableReferences),
    NoteImage,
    PrefetchHooks Function({bool noteId})> {
  $$NoteImagesTableTableManager(_$AppDatabase db, $NoteImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> noteId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              NoteImagesCompanion(
            id: id,
            noteId: noteId,
            imagePath: imagePath,
            position: position,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int noteId,
            required String imagePath,
            Value<int> position = const Value.absent(),
          }) =>
              NoteImagesCompanion.insert(
            id: id,
            noteId: noteId,
            imagePath: imagePath,
            position: position,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$NoteImagesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (noteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.noteId,
                    referencedTable:
                        $$NoteImagesTableReferences._noteIdTable(db),
                    referencedColumn:
                        $$NoteImagesTableReferences._noteIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$NoteImagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteImagesTable,
    NoteImage,
    $$NoteImagesTableFilterComposer,
    $$NoteImagesTableOrderingComposer,
    $$NoteImagesTableAnnotationComposer,
    $$NoteImagesTableCreateCompanionBuilder,
    $$NoteImagesTableUpdateCompanionBuilder,
    (NoteImage, $$NoteImagesTableReferences),
    NoteImage,
    PrefetchHooks Function({bool noteId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteImagesTableTableManager get noteImages =>
      $$NoteImagesTableTableManager(_db, _db.noteImages);
}
