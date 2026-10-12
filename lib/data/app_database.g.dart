// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WoodVarietiesTable extends WoodVarieties
    with TableInfo<$WoodVarietiesTable, WoodVarietyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WoodVarietiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, active, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wood_varieties';
  @override
  VerificationContext validateIntegrity(
    Insertable<WoodVarietyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WoodVarietyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WoodVarietyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WoodVarietiesTable createAlias(String alias) {
    return $WoodVarietiesTable(attachedDatabase, alias);
  }
}

class WoodVarietyRow extends DataClass implements Insertable<WoodVarietyRow> {
  /// Primary key.
  final int id;

  /// Display name, stored with its exact spelling (Req 1.1).
  final String name;

  /// Whether the variety is available for new receiving / selling.
  final bool active;

  /// Row creation time (UTC).
  final DateTime createdAt;
  const WoodVarietyRow({
    required this.id,
    required this.name,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WoodVarietiesCompanion toCompanion(bool nullToAbsent) {
    return WoodVarietiesCompanion(
      id: Value(id),
      name: Value(name),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory WoodVarietyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WoodVarietyRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WoodVarietyRow copyWith({
    int? id,
    String? name,
    bool? active,
    DateTime? createdAt,
  }) => WoodVarietyRow(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  WoodVarietyRow copyWithCompanion(WoodVarietiesCompanion data) {
    return WoodVarietyRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WoodVarietyRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, active, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WoodVarietyRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class WoodVarietiesCompanion extends UpdateCompanion<WoodVarietyRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  const WoodVarietiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WoodVarietiesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.active = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<WoodVarietyRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WoodVarietiesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? active,
    Value<DateTime>? createdAt,
  }) {
    return WoodVarietiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
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
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WoodVarietiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CrossSectionsTable extends CrossSections
    with TableInfo<$CrossSectionsTable, CrossSectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrossSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _widthInMeta = const VerificationMeta(
    'widthIn',
  );
  @override
  late final GeneratedColumn<int> widthIn = GeneratedColumn<int>(
    'width_in',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thicknessInMeta = const VerificationMeta(
    'thicknessIn',
  );
  @override
  late final GeneratedColumn<int> thicknessIn = GeneratedColumn<int>(
    'thickness_in',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, int> category =
      GeneratedColumn<int>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<CategoryKind>($CrossSectionsTable.$convertercategory);
  static const VerificationMeta _bunchSizeMeta = const VerificationMeta(
    'bunchSize',
  );
  @override
  late final GeneratedColumn<int> bunchSize = GeneratedColumn<int>(
    'bunch_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    widthIn,
    thicknessIn,
    category,
    bunchSize,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cross_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrossSectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('width_in')) {
      context.handle(
        _widthInMeta,
        widthIn.isAcceptableOrUnknown(data['width_in']!, _widthInMeta),
      );
    } else if (isInserting) {
      context.missing(_widthInMeta);
    }
    if (data.containsKey('thickness_in')) {
      context.handle(
        _thicknessInMeta,
        thicknessIn.isAcceptableOrUnknown(
          data['thickness_in']!,
          _thicknessInMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thicknessInMeta);
    }
    if (data.containsKey('bunch_size')) {
      context.handle(
        _bunchSizeMeta,
        bunchSize.isAcceptableOrUnknown(data['bunch_size']!, _bunchSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_bunchSizeMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CrossSectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrossSectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      widthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_in'],
      )!,
      thicknessIn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thickness_in'],
      )!,
      category: $CrossSectionsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}category'],
        )!,
      ),
      bunchSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bunch_size'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $CrossSectionsTable createAlias(String alias) {
    return $CrossSectionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, int, int> $convertercategory =
      const EnumIndexConverter<CategoryKind>(CategoryKind.values);
}

class CrossSectionRow extends DataClass implements Insertable<CrossSectionRow> {
  /// Primary key.
  final int id;

  /// First dimension (width) in inches.
  final int widthIn;

  /// Second dimension (thickness) in inches — used in the CFT formula.
  final int thicknessIn;

  /// Reaper or Plank.
  final CategoryKind category;

  /// Pieces per whole sale unit: 10 for a reaper, 1 for a plank.
  final int bunchSize;

  /// Whether the cross-section is available for new receiving / selling.
  final bool active;
  const CrossSectionRow({
    required this.id,
    required this.widthIn,
    required this.thicknessIn,
    required this.category,
    required this.bunchSize,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['width_in'] = Variable<int>(widthIn);
    map['thickness_in'] = Variable<int>(thicknessIn);
    {
      map['category'] = Variable<int>(
        $CrossSectionsTable.$convertercategory.toSql(category),
      );
    }
    map['bunch_size'] = Variable<int>(bunchSize);
    map['active'] = Variable<bool>(active);
    return map;
  }

  CrossSectionsCompanion toCompanion(bool nullToAbsent) {
    return CrossSectionsCompanion(
      id: Value(id),
      widthIn: Value(widthIn),
      thicknessIn: Value(thicknessIn),
      category: Value(category),
      bunchSize: Value(bunchSize),
      active: Value(active),
    );
  }

  factory CrossSectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrossSectionRow(
      id: serializer.fromJson<int>(json['id']),
      widthIn: serializer.fromJson<int>(json['widthIn']),
      thicknessIn: serializer.fromJson<int>(json['thicknessIn']),
      category: $CrossSectionsTable.$convertercategory.fromJson(
        serializer.fromJson<int>(json['category']),
      ),
      bunchSize: serializer.fromJson<int>(json['bunchSize']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'widthIn': serializer.toJson<int>(widthIn),
      'thicknessIn': serializer.toJson<int>(thicknessIn),
      'category': serializer.toJson<int>(
        $CrossSectionsTable.$convertercategory.toJson(category),
      ),
      'bunchSize': serializer.toJson<int>(bunchSize),
      'active': serializer.toJson<bool>(active),
    };
  }

  CrossSectionRow copyWith({
    int? id,
    int? widthIn,
    int? thicknessIn,
    CategoryKind? category,
    int? bunchSize,
    bool? active,
  }) => CrossSectionRow(
    id: id ?? this.id,
    widthIn: widthIn ?? this.widthIn,
    thicknessIn: thicknessIn ?? this.thicknessIn,
    category: category ?? this.category,
    bunchSize: bunchSize ?? this.bunchSize,
    active: active ?? this.active,
  );
  CrossSectionRow copyWithCompanion(CrossSectionsCompanion data) {
    return CrossSectionRow(
      id: data.id.present ? data.id.value : this.id,
      widthIn: data.widthIn.present ? data.widthIn.value : this.widthIn,
      thicknessIn: data.thicknessIn.present
          ? data.thicknessIn.value
          : this.thicknessIn,
      category: data.category.present ? data.category.value : this.category,
      bunchSize: data.bunchSize.present ? data.bunchSize.value : this.bunchSize,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrossSectionRow(')
          ..write('id: $id, ')
          ..write('widthIn: $widthIn, ')
          ..write('thicknessIn: $thicknessIn, ')
          ..write('category: $category, ')
          ..write('bunchSize: $bunchSize, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, widthIn, thicknessIn, category, bunchSize, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrossSectionRow &&
          other.id == this.id &&
          other.widthIn == this.widthIn &&
          other.thicknessIn == this.thicknessIn &&
          other.category == this.category &&
          other.bunchSize == this.bunchSize &&
          other.active == this.active);
}

class CrossSectionsCompanion extends UpdateCompanion<CrossSectionRow> {
  final Value<int> id;
  final Value<int> widthIn;
  final Value<int> thicknessIn;
  final Value<CategoryKind> category;
  final Value<int> bunchSize;
  final Value<bool> active;
  const CrossSectionsCompanion({
    this.id = const Value.absent(),
    this.widthIn = const Value.absent(),
    this.thicknessIn = const Value.absent(),
    this.category = const Value.absent(),
    this.bunchSize = const Value.absent(),
    this.active = const Value.absent(),
  });
  CrossSectionsCompanion.insert({
    this.id = const Value.absent(),
    required int widthIn,
    required int thicknessIn,
    required CategoryKind category,
    required int bunchSize,
    this.active = const Value.absent(),
  }) : widthIn = Value(widthIn),
       thicknessIn = Value(thicknessIn),
       category = Value(category),
       bunchSize = Value(bunchSize);
  static Insertable<CrossSectionRow> custom({
    Expression<int>? id,
    Expression<int>? widthIn,
    Expression<int>? thicknessIn,
    Expression<int>? category,
    Expression<int>? bunchSize,
    Expression<bool>? active,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (widthIn != null) 'width_in': widthIn,
      if (thicknessIn != null) 'thickness_in': thicknessIn,
      if (category != null) 'category': category,
      if (bunchSize != null) 'bunch_size': bunchSize,
      if (active != null) 'active': active,
    });
  }

  CrossSectionsCompanion copyWith({
    Value<int>? id,
    Value<int>? widthIn,
    Value<int>? thicknessIn,
    Value<CategoryKind>? category,
    Value<int>? bunchSize,
    Value<bool>? active,
  }) {
    return CrossSectionsCompanion(
      id: id ?? this.id,
      widthIn: widthIn ?? this.widthIn,
      thicknessIn: thicknessIn ?? this.thicknessIn,
      category: category ?? this.category,
      bunchSize: bunchSize ?? this.bunchSize,
      active: active ?? this.active,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (widthIn.present) {
      map['width_in'] = Variable<int>(widthIn.value);
    }
    if (thicknessIn.present) {
      map['thickness_in'] = Variable<int>(thicknessIn.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(
        $CrossSectionsTable.$convertercategory.toSql(category.value),
      );
    }
    if (bunchSize.present) {
      map['bunch_size'] = Variable<int>(bunchSize.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrossSectionsCompanion(')
          ..write('id: $id, ')
          ..write('widthIn: $widthIn, ')
          ..write('thicknessIn: $thicknessIn, ')
          ..write('category: $category, ')
          ..write('bunchSize: $bunchSize, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }
}

class $StockItemsTable extends StockItems
    with TableInfo<$StockItemsTable, StockItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _varietyIdMeta = const VerificationMeta(
    'varietyId',
  );
  @override
  late final GeneratedColumn<int> varietyId = GeneratedColumn<int>(
    'variety_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wood_varieties (id)',
    ),
  );
  static const VerificationMeta _crossSectionIdMeta = const VerificationMeta(
    'crossSectionId',
  );
  @override
  late final GeneratedColumn<int> crossSectionId = GeneratedColumn<int>(
    'cross_section_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cross_sections (id)',
    ),
  );
  static const VerificationMeta _lengthFtMeta = const VerificationMeta(
    'lengthFt',
  );
  @override
  late final GeneratedColumn<int> lengthFt = GeneratedColumn<int>(
    'length_ft',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedBalancePiecesMeta =
      const VerificationMeta('confirmedBalancePieces');
  @override
  late final GeneratedColumn<int> confirmedBalancePieces = GeneratedColumn<int>(
    'confirmed_balance_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pendingBalancePiecesMeta =
      const VerificationMeta('pendingBalancePieces');
  @override
  late final GeneratedColumn<int> pendingBalancePieces = GeneratedColumn<int>(
    'pending_balance_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    varietyId,
    crossSectionId,
    lengthFt,
    confirmedBalancePieces,
    pendingBalancePieces,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('variety_id')) {
      context.handle(
        _varietyIdMeta,
        varietyId.isAcceptableOrUnknown(data['variety_id']!, _varietyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_varietyIdMeta);
    }
    if (data.containsKey('cross_section_id')) {
      context.handle(
        _crossSectionIdMeta,
        crossSectionId.isAcceptableOrUnknown(
          data['cross_section_id']!,
          _crossSectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_crossSectionIdMeta);
    }
    if (data.containsKey('length_ft')) {
      context.handle(
        _lengthFtMeta,
        lengthFt.isAcceptableOrUnknown(data['length_ft']!, _lengthFtMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthFtMeta);
    }
    if (data.containsKey('confirmed_balance_pieces')) {
      context.handle(
        _confirmedBalancePiecesMeta,
        confirmedBalancePieces.isAcceptableOrUnknown(
          data['confirmed_balance_pieces']!,
          _confirmedBalancePiecesMeta,
        ),
      );
    }
    if (data.containsKey('pending_balance_pieces')) {
      context.handle(
        _pendingBalancePiecesMeta,
        pendingBalancePieces.isAcceptableOrUnknown(
          data['pending_balance_pieces']!,
          _pendingBalancePiecesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {varietyId, crossSectionId, lengthFt},
  ];
  @override
  StockItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      varietyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variety_id'],
      )!,
      crossSectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cross_section_id'],
      )!,
      lengthFt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length_ft'],
      )!,
      confirmedBalancePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed_balance_pieces'],
      )!,
      pendingBalancePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_balance_pieces'],
      )!,
    );
  }

  @override
  $StockItemsTable createAlias(String alias) {
    return $StockItemsTable(attachedDatabase, alias);
  }
}

class StockItemRow extends DataClass implements Insertable<StockItemRow> {
  /// Primary key.
  final int id;

  /// Owning variety.
  final int varietyId;

  /// Owning cross-section.
  final int crossSectionId;

  /// Piece length in feet (constrained to 2-9 by the domain layer).
  final int lengthFt;

  /// Sum of confirmed movements — the sellable quantity.
  final int confirmedBalancePieces;

  /// Sum of not-yet-confirmed received movements — display-only, not sellable.
  final int pendingBalancePieces;
  const StockItemRow({
    required this.id,
    required this.varietyId,
    required this.crossSectionId,
    required this.lengthFt,
    required this.confirmedBalancePieces,
    required this.pendingBalancePieces,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['variety_id'] = Variable<int>(varietyId);
    map['cross_section_id'] = Variable<int>(crossSectionId);
    map['length_ft'] = Variable<int>(lengthFt);
    map['confirmed_balance_pieces'] = Variable<int>(confirmedBalancePieces);
    map['pending_balance_pieces'] = Variable<int>(pendingBalancePieces);
    return map;
  }

  StockItemsCompanion toCompanion(bool nullToAbsent) {
    return StockItemsCompanion(
      id: Value(id),
      varietyId: Value(varietyId),
      crossSectionId: Value(crossSectionId),
      lengthFt: Value(lengthFt),
      confirmedBalancePieces: Value(confirmedBalancePieces),
      pendingBalancePieces: Value(pendingBalancePieces),
    );
  }

  factory StockItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockItemRow(
      id: serializer.fromJson<int>(json['id']),
      varietyId: serializer.fromJson<int>(json['varietyId']),
      crossSectionId: serializer.fromJson<int>(json['crossSectionId']),
      lengthFt: serializer.fromJson<int>(json['lengthFt']),
      confirmedBalancePieces: serializer.fromJson<int>(
        json['confirmedBalancePieces'],
      ),
      pendingBalancePieces: serializer.fromJson<int>(
        json['pendingBalancePieces'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'varietyId': serializer.toJson<int>(varietyId),
      'crossSectionId': serializer.toJson<int>(crossSectionId),
      'lengthFt': serializer.toJson<int>(lengthFt),
      'confirmedBalancePieces': serializer.toJson<int>(confirmedBalancePieces),
      'pendingBalancePieces': serializer.toJson<int>(pendingBalancePieces),
    };
  }

  StockItemRow copyWith({
    int? id,
    int? varietyId,
    int? crossSectionId,
    int? lengthFt,
    int? confirmedBalancePieces,
    int? pendingBalancePieces,
  }) => StockItemRow(
    id: id ?? this.id,
    varietyId: varietyId ?? this.varietyId,
    crossSectionId: crossSectionId ?? this.crossSectionId,
    lengthFt: lengthFt ?? this.lengthFt,
    confirmedBalancePieces:
        confirmedBalancePieces ?? this.confirmedBalancePieces,
    pendingBalancePieces: pendingBalancePieces ?? this.pendingBalancePieces,
  );
  StockItemRow copyWithCompanion(StockItemsCompanion data) {
    return StockItemRow(
      id: data.id.present ? data.id.value : this.id,
      varietyId: data.varietyId.present ? data.varietyId.value : this.varietyId,
      crossSectionId: data.crossSectionId.present
          ? data.crossSectionId.value
          : this.crossSectionId,
      lengthFt: data.lengthFt.present ? data.lengthFt.value : this.lengthFt,
      confirmedBalancePieces: data.confirmedBalancePieces.present
          ? data.confirmedBalancePieces.value
          : this.confirmedBalancePieces,
      pendingBalancePieces: data.pendingBalancePieces.present
          ? data.pendingBalancePieces.value
          : this.pendingBalancePieces,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockItemRow(')
          ..write('id: $id, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('confirmedBalancePieces: $confirmedBalancePieces, ')
          ..write('pendingBalancePieces: $pendingBalancePieces')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    varietyId,
    crossSectionId,
    lengthFt,
    confirmedBalancePieces,
    pendingBalancePieces,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockItemRow &&
          other.id == this.id &&
          other.varietyId == this.varietyId &&
          other.crossSectionId == this.crossSectionId &&
          other.lengthFt == this.lengthFt &&
          other.confirmedBalancePieces == this.confirmedBalancePieces &&
          other.pendingBalancePieces == this.pendingBalancePieces);
}

class StockItemsCompanion extends UpdateCompanion<StockItemRow> {
  final Value<int> id;
  final Value<int> varietyId;
  final Value<int> crossSectionId;
  final Value<int> lengthFt;
  final Value<int> confirmedBalancePieces;
  final Value<int> pendingBalancePieces;
  const StockItemsCompanion({
    this.id = const Value.absent(),
    this.varietyId = const Value.absent(),
    this.crossSectionId = const Value.absent(),
    this.lengthFt = const Value.absent(),
    this.confirmedBalancePieces = const Value.absent(),
    this.pendingBalancePieces = const Value.absent(),
  });
  StockItemsCompanion.insert({
    this.id = const Value.absent(),
    required int varietyId,
    required int crossSectionId,
    required int lengthFt,
    this.confirmedBalancePieces = const Value.absent(),
    this.pendingBalancePieces = const Value.absent(),
  }) : varietyId = Value(varietyId),
       crossSectionId = Value(crossSectionId),
       lengthFt = Value(lengthFt);
  static Insertable<StockItemRow> custom({
    Expression<int>? id,
    Expression<int>? varietyId,
    Expression<int>? crossSectionId,
    Expression<int>? lengthFt,
    Expression<int>? confirmedBalancePieces,
    Expression<int>? pendingBalancePieces,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (varietyId != null) 'variety_id': varietyId,
      if (crossSectionId != null) 'cross_section_id': crossSectionId,
      if (lengthFt != null) 'length_ft': lengthFt,
      if (confirmedBalancePieces != null)
        'confirmed_balance_pieces': confirmedBalancePieces,
      if (pendingBalancePieces != null)
        'pending_balance_pieces': pendingBalancePieces,
    });
  }

  StockItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? varietyId,
    Value<int>? crossSectionId,
    Value<int>? lengthFt,
    Value<int>? confirmedBalancePieces,
    Value<int>? pendingBalancePieces,
  }) {
    return StockItemsCompanion(
      id: id ?? this.id,
      varietyId: varietyId ?? this.varietyId,
      crossSectionId: crossSectionId ?? this.crossSectionId,
      lengthFt: lengthFt ?? this.lengthFt,
      confirmedBalancePieces:
          confirmedBalancePieces ?? this.confirmedBalancePieces,
      pendingBalancePieces: pendingBalancePieces ?? this.pendingBalancePieces,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (varietyId.present) {
      map['variety_id'] = Variable<int>(varietyId.value);
    }
    if (crossSectionId.present) {
      map['cross_section_id'] = Variable<int>(crossSectionId.value);
    }
    if (lengthFt.present) {
      map['length_ft'] = Variable<int>(lengthFt.value);
    }
    if (confirmedBalancePieces.present) {
      map['confirmed_balance_pieces'] = Variable<int>(
        confirmedBalancePieces.value,
      );
    }
    if (pendingBalancePieces.present) {
      map['pending_balance_pieces'] = Variable<int>(pendingBalancePieces.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockItemsCompanion(')
          ..write('id: $id, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('confirmedBalancePieces: $confirmedBalancePieces, ')
          ..write('pendingBalancePieces: $pendingBalancePieces')
          ..write(')'))
        .toString();
  }
}

class $ReceiptSessionsTable extends ReceiptSessions
    with TableInfo<$ReceiptSessionsTable, ReceiptSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReceiptStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ReceiptStatus>($ReceiptSessionsTable.$converterstatus);
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, status, startedAt, finishedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      status: $ReceiptSessionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $ReceiptSessionsTable createAlias(String alias) {
    return $ReceiptSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReceiptStatus, int, int> $converterstatus =
      const EnumIndexConverter<ReceiptStatus>(ReceiptStatus.values);
}

class ReceiptSessionRow extends DataClass
    implements Insertable<ReceiptSessionRow> {
  /// Primary key.
  final int id;

  /// Active or Finished.
  final ReceiptStatus status;

  /// When the session started (UTC).
  final DateTime startedAt;

  /// When the session finished (UTC); null while active.
  final DateTime? finishedAt;
  const ReceiptSessionRow({
    required this.id,
    required this.status,
    required this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['status'] = Variable<int>(
        $ReceiptSessionsTable.$converterstatus.toSql(status),
      );
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  ReceiptSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptSessionsCompanion(
      id: Value(id),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory ReceiptSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptSessionRow(
      id: serializer.fromJson<int>(json['id']),
      status: $ReceiptSessionsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<int>(
        $ReceiptSessionsTable.$converterstatus.toJson(status),
      ),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  ReceiptSessionRow copyWith({
    int? id,
    ReceiptStatus? status,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => ReceiptSessionRow(
    id: id ?? this.id,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  ReceiptSessionRow copyWithCompanion(ReceiptSessionsCompanion data) {
    return ReceiptSessionRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptSessionRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, status, startedAt, finishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptSessionRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class ReceiptSessionsCompanion extends UpdateCompanion<ReceiptSessionRow> {
  final Value<int> id;
  final Value<ReceiptStatus> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  const ReceiptSessionsCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
  });
  ReceiptSessionsCompanion.insert({
    this.id = const Value.absent(),
    required ReceiptStatus status,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
  }) : status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<ReceiptSessionRow> custom({
    Expression<int>? id,
    Expression<int>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
    });
  }

  ReceiptSessionsCompanion copyWith({
    Value<int>? id,
    Value<ReceiptStatus>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
  }) {
    return ReceiptSessionsCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $ReceiptSessionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptSessionsCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }
}

class $ReceiptEntriesTable extends ReceiptEntries
    with TableInfo<$ReceiptEntriesTable, ReceiptEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<int> receiptId = GeneratedColumn<int>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipt_sessions (id)',
    ),
  );
  static const VerificationMeta _stockItemIdMeta = const VerificationMeta(
    'stockItemId',
  );
  @override
  late final GeneratedColumn<int> stockItemId = GeneratedColumn<int>(
    'stock_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_items (id)',
    ),
  );
  static const VerificationMeta _qtyInputMeta = const VerificationMeta(
    'qtyInput',
  );
  @override
  late final GeneratedColumn<int> qtyInput = GeneratedColumn<int>(
    'qty_input',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InputUnit, int> unit =
      GeneratedColumn<int>(
        'unit',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<InputUnit>($ReceiptEntriesTable.$converterunit);
  static const VerificationMeta _piecesDeltaMeta = const VerificationMeta(
    'piecesDelta',
  );
  @override
  late final GeneratedColumn<int> piecesDelta = GeneratedColumn<int>(
    'pieces_delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    receiptId,
    stockItemId,
    qtyInput,
    unit,
    piecesDelta,
    idempotencyKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('stock_item_id')) {
      context.handle(
        _stockItemIdMeta,
        stockItemId.isAcceptableOrUnknown(
          data['stock_item_id']!,
          _stockItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stockItemIdMeta);
    }
    if (data.containsKey('qty_input')) {
      context.handle(
        _qtyInputMeta,
        qtyInput.isAcceptableOrUnknown(data['qty_input']!, _qtyInputMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyInputMeta);
    }
    if (data.containsKey('pieces_delta')) {
      context.handle(
        _piecesDeltaMeta,
        piecesDelta.isAcceptableOrUnknown(
          data['pieces_delta']!,
          _piecesDeltaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_piecesDeltaMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_id'],
      )!,
      stockItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_item_id'],
      )!,
      qtyInput: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_input'],
      )!,
      unit: $ReceiptEntriesTable.$converterunit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}unit'],
        )!,
      ),
      piecesDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pieces_delta'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReceiptEntriesTable createAlias(String alias) {
    return $ReceiptEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InputUnit, int, int> $converterunit =
      const EnumIndexConverter<InputUnit>(InputUnit.values);
}

class ReceiptEntryRow extends DataClass implements Insertable<ReceiptEntryRow> {
  /// Primary key.
  final int id;

  /// Owning receipt session.
  final int receiptId;

  /// Target stock item.
  final int stockItemId;

  /// Quantity as entered (bunches or pieces).
  final int qtyInput;

  /// Whether [qtyInput] is in bunches or pieces.
  final InputUnit unit;

  /// Resolved whole-piece delta.
  final int piecesDelta;

  /// Stable idempotency key; unique so resume/finish never double-adds.
  final String idempotencyKey;

  /// Row creation time (UTC).
  final DateTime createdAt;
  const ReceiptEntryRow({
    required this.id,
    required this.receiptId,
    required this.stockItemId,
    required this.qtyInput,
    required this.unit,
    required this.piecesDelta,
    required this.idempotencyKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['receipt_id'] = Variable<int>(receiptId);
    map['stock_item_id'] = Variable<int>(stockItemId);
    map['qty_input'] = Variable<int>(qtyInput);
    {
      map['unit'] = Variable<int>(
        $ReceiptEntriesTable.$converterunit.toSql(unit),
      );
    }
    map['pieces_delta'] = Variable<int>(piecesDelta);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReceiptEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReceiptEntriesCompanion(
      id: Value(id),
      receiptId: Value(receiptId),
      stockItemId: Value(stockItemId),
      qtyInput: Value(qtyInput),
      unit: Value(unit),
      piecesDelta: Value(piecesDelta),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
    );
  }

  factory ReceiptEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptEntryRow(
      id: serializer.fromJson<int>(json['id']),
      receiptId: serializer.fromJson<int>(json['receiptId']),
      stockItemId: serializer.fromJson<int>(json['stockItemId']),
      qtyInput: serializer.fromJson<int>(json['qtyInput']),
      unit: $ReceiptEntriesTable.$converterunit.fromJson(
        serializer.fromJson<int>(json['unit']),
      ),
      piecesDelta: serializer.fromJson<int>(json['piecesDelta']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'receiptId': serializer.toJson<int>(receiptId),
      'stockItemId': serializer.toJson<int>(stockItemId),
      'qtyInput': serializer.toJson<int>(qtyInput),
      'unit': serializer.toJson<int>(
        $ReceiptEntriesTable.$converterunit.toJson(unit),
      ),
      'piecesDelta': serializer.toJson<int>(piecesDelta),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReceiptEntryRow copyWith({
    int? id,
    int? receiptId,
    int? stockItemId,
    int? qtyInput,
    InputUnit? unit,
    int? piecesDelta,
    String? idempotencyKey,
    DateTime? createdAt,
  }) => ReceiptEntryRow(
    id: id ?? this.id,
    receiptId: receiptId ?? this.receiptId,
    stockItemId: stockItemId ?? this.stockItemId,
    qtyInput: qtyInput ?? this.qtyInput,
    unit: unit ?? this.unit,
    piecesDelta: piecesDelta ?? this.piecesDelta,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
  );
  ReceiptEntryRow copyWithCompanion(ReceiptEntriesCompanion data) {
    return ReceiptEntryRow(
      id: data.id.present ? data.id.value : this.id,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      stockItemId: data.stockItemId.present
          ? data.stockItemId.value
          : this.stockItemId,
      qtyInput: data.qtyInput.present ? data.qtyInput.value : this.qtyInput,
      unit: data.unit.present ? data.unit.value : this.unit,
      piecesDelta: data.piecesDelta.present
          ? data.piecesDelta.value
          : this.piecesDelta,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptEntryRow(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('qtyInput: $qtyInput, ')
          ..write('unit: $unit, ')
          ..write('piecesDelta: $piecesDelta, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    receiptId,
    stockItemId,
    qtyInput,
    unit,
    piecesDelta,
    idempotencyKey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptEntryRow &&
          other.id == this.id &&
          other.receiptId == this.receiptId &&
          other.stockItemId == this.stockItemId &&
          other.qtyInput == this.qtyInput &&
          other.unit == this.unit &&
          other.piecesDelta == this.piecesDelta &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt);
}

class ReceiptEntriesCompanion extends UpdateCompanion<ReceiptEntryRow> {
  final Value<int> id;
  final Value<int> receiptId;
  final Value<int> stockItemId;
  final Value<int> qtyInput;
  final Value<InputUnit> unit;
  final Value<int> piecesDelta;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  const ReceiptEntriesCompanion({
    this.id = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.stockItemId = const Value.absent(),
    this.qtyInput = const Value.absent(),
    this.unit = const Value.absent(),
    this.piecesDelta = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReceiptEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int receiptId,
    required int stockItemId,
    required int qtyInput,
    required InputUnit unit,
    required int piecesDelta,
    required String idempotencyKey,
    required DateTime createdAt,
  }) : receiptId = Value(receiptId),
       stockItemId = Value(stockItemId),
       qtyInput = Value(qtyInput),
       unit = Value(unit),
       piecesDelta = Value(piecesDelta),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<ReceiptEntryRow> custom({
    Expression<int>? id,
    Expression<int>? receiptId,
    Expression<int>? stockItemId,
    Expression<int>? qtyInput,
    Expression<int>? unit,
    Expression<int>? piecesDelta,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      if (stockItemId != null) 'stock_item_id': stockItemId,
      if (qtyInput != null) 'qty_input': qtyInput,
      if (unit != null) 'unit': unit,
      if (piecesDelta != null) 'pieces_delta': piecesDelta,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReceiptEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? receiptId,
    Value<int>? stockItemId,
    Value<int>? qtyInput,
    Value<InputUnit>? unit,
    Value<int>? piecesDelta,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
  }) {
    return ReceiptEntriesCompanion(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      stockItemId: stockItemId ?? this.stockItemId,
      qtyInput: qtyInput ?? this.qtyInput,
      unit: unit ?? this.unit,
      piecesDelta: piecesDelta ?? this.piecesDelta,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<int>(receiptId.value);
    }
    if (stockItemId.present) {
      map['stock_item_id'] = Variable<int>(stockItemId.value);
    }
    if (qtyInput.present) {
      map['qty_input'] = Variable<int>(qtyInput.value);
    }
    if (unit.present) {
      map['unit'] = Variable<int>(
        $ReceiptEntriesTable.$converterunit.toSql(unit.value),
      );
    }
    if (piecesDelta.present) {
      map['pieces_delta'] = Variable<int>(piecesDelta.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptEntriesCompanion(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('qtyInput: $qtyInput, ')
          ..write('unit: $unit, ')
          ..write('piecesDelta: $piecesDelta, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $InvoicesTable extends Invoices
    with TableInfo<$InvoicesTable, InvoiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _invoiceNumberMeta = const VerificationMeta(
    'invoiceNumber',
  );
  @override
  late final GeneratedColumn<String> invoiceNumber = GeneratedColumn<String>(
    'invoice_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InvoiceStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<InvoiceStatus>($InvoicesTable.$converterstatus);
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goodsSubtotalPaiseMeta =
      const VerificationMeta('goodsSubtotalPaise');
  @override
  late final GeneratedColumn<int> goodsSubtotalPaise = GeneratedColumn<int>(
    'goods_subtotal_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxPaiseMeta = const VerificationMeta(
    'taxPaise',
  );
  @override
  late final GeneratedColumn<int> taxPaise = GeneratedColumn<int>(
    'tax_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loadingPaiseMeta = const VerificationMeta(
    'loadingPaise',
  );
  @override
  late final GeneratedColumn<int> loadingPaise = GeneratedColumn<int>(
    'loading_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payablePaiseMeta = const VerificationMeta(
    'payablePaise',
  );
  @override
  late final GeneratedColumn<int> payablePaise = GeneratedColumn<int>(
    'payable_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCftNumMeta = const VerificationMeta(
    'totalCftNum',
  );
  @override
  late final GeneratedColumn<int> totalCftNum = GeneratedColumn<int>(
    'total_cft_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCftDenMeta = const VerificationMeta(
    'totalCftDen',
  );
  @override
  late final GeneratedColumn<int> totalCftDen = GeneratedColumn<int>(
    'total_cft_den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxPolicySnapshotMeta = const VerificationMeta(
    'taxPolicySnapshot',
  );
  @override
  late final GeneratedColumn<String> taxPolicySnapshot =
      GeneratedColumn<String>(
        'tax_policy_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _loadingPolicySnapshotMeta =
      const VerificationMeta('loadingPolicySnapshot');
  @override
  late final GeneratedColumn<String> loadingPolicySnapshot =
      GeneratedColumn<String>(
        'loading_policy_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _businessProfileSnapshotMeta =
      const VerificationMeta('businessProfileSnapshot');
  @override
  late final GeneratedColumn<String> businessProfileSnapshot =
      GeneratedColumn<String>(
        'business_profile_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _finalizedAtMeta = const VerificationMeta(
    'finalizedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finalizedAt = GeneratedColumn<DateTime>(
    'finalized_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    invoiceNumber,
    status,
    customerName,
    customerPhone,
    goodsSubtotalPaise,
    taxPaise,
    loadingPaise,
    payablePaise,
    totalCftNum,
    totalCftDen,
    taxPolicySnapshot,
    loadingPolicySnapshot,
    businessProfileSnapshot,
    finalizedAt,
    idempotencyKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('invoice_number')) {
      context.handle(
        _invoiceNumberMeta,
        invoiceNumber.isAcceptableOrUnknown(
          data['invoice_number']!,
          _invoiceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_invoiceNumberMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('goods_subtotal_paise')) {
      context.handle(
        _goodsSubtotalPaiseMeta,
        goodsSubtotalPaise.isAcceptableOrUnknown(
          data['goods_subtotal_paise']!,
          _goodsSubtotalPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goodsSubtotalPaiseMeta);
    }
    if (data.containsKey('tax_paise')) {
      context.handle(
        _taxPaiseMeta,
        taxPaise.isAcceptableOrUnknown(data['tax_paise']!, _taxPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_taxPaiseMeta);
    }
    if (data.containsKey('loading_paise')) {
      context.handle(
        _loadingPaiseMeta,
        loadingPaise.isAcceptableOrUnknown(
          data['loading_paise']!,
          _loadingPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loadingPaiseMeta);
    }
    if (data.containsKey('payable_paise')) {
      context.handle(
        _payablePaiseMeta,
        payablePaise.isAcceptableOrUnknown(
          data['payable_paise']!,
          _payablePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payablePaiseMeta);
    }
    if (data.containsKey('total_cft_num')) {
      context.handle(
        _totalCftNumMeta,
        totalCftNum.isAcceptableOrUnknown(
          data['total_cft_num']!,
          _totalCftNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalCftNumMeta);
    }
    if (data.containsKey('total_cft_den')) {
      context.handle(
        _totalCftDenMeta,
        totalCftDen.isAcceptableOrUnknown(
          data['total_cft_den']!,
          _totalCftDenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalCftDenMeta);
    }
    if (data.containsKey('tax_policy_snapshot')) {
      context.handle(
        _taxPolicySnapshotMeta,
        taxPolicySnapshot.isAcceptableOrUnknown(
          data['tax_policy_snapshot']!,
          _taxPolicySnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taxPolicySnapshotMeta);
    }
    if (data.containsKey('loading_policy_snapshot')) {
      context.handle(
        _loadingPolicySnapshotMeta,
        loadingPolicySnapshot.isAcceptableOrUnknown(
          data['loading_policy_snapshot']!,
          _loadingPolicySnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loadingPolicySnapshotMeta);
    }
    if (data.containsKey('business_profile_snapshot')) {
      context.handle(
        _businessProfileSnapshotMeta,
        businessProfileSnapshot.isAcceptableOrUnknown(
          data['business_profile_snapshot']!,
          _businessProfileSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessProfileSnapshotMeta);
    }
    if (data.containsKey('finalized_at')) {
      context.handle(
        _finalizedAtMeta,
        finalizedAt.isAcceptableOrUnknown(
          data['finalized_at']!,
          _finalizedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finalizedAtMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      invoiceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_number'],
      )!,
      status: $InvoicesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      goodsSubtotalPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goods_subtotal_paise'],
      )!,
      taxPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_paise'],
      )!,
      loadingPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loading_paise'],
      )!,
      payablePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payable_paise'],
      )!,
      totalCftNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cft_num'],
      )!,
      totalCftDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cft_den'],
      )!,
      taxPolicySnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_policy_snapshot'],
      )!,
      loadingPolicySnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loading_policy_snapshot'],
      )!,
      businessProfileSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_profile_snapshot'],
      )!,
      finalizedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finalized_at'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
    );
  }

  @override
  $InvoicesTable createAlias(String alias) {
    return $InvoicesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InvoiceStatus, int, int> $converterstatus =
      const EnumIndexConverter<InvoiceStatus>(InvoiceStatus.values);
}

class InvoiceRow extends DataClass implements Insertable<InvoiceRow> {
  /// Primary key.
  final int id;

  /// Permanent, unique invoice number.
  final String invoiceNumber;

  /// Finalized or Voided.
  final InvoiceStatus status;

  /// Customer name snapshot.
  final String? customerName;

  /// Customer phone snapshot.
  final String? customerPhone;

  /// Goods subtotal in paise.
  final int goodsSubtotalPaise;

  /// Tax in paise.
  final int taxPaise;

  /// Loading charge in paise.
  final int loadingPaise;

  /// Payable in paise.
  final int payablePaise;

  /// Total CFT numerator.
  final int totalCftNum;

  /// Total CFT denominator.
  final int totalCftDen;

  /// Serialized tax policy snapshot.
  final String taxPolicySnapshot;

  /// Serialized loading policy snapshot.
  final String loadingPolicySnapshot;

  /// Serialized business profile snapshot.
  final String businessProfileSnapshot;

  /// When finalized (UTC).
  final DateTime finalizedAt;

  /// Stable idempotency key; unique so retries yield exactly one invoice.
  final String idempotencyKey;
  const InvoiceRow({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    this.customerName,
    this.customerPhone,
    required this.goodsSubtotalPaise,
    required this.taxPaise,
    required this.loadingPaise,
    required this.payablePaise,
    required this.totalCftNum,
    required this.totalCftDen,
    required this.taxPolicySnapshot,
    required this.loadingPolicySnapshot,
    required this.businessProfileSnapshot,
    required this.finalizedAt,
    required this.idempotencyKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['invoice_number'] = Variable<String>(invoiceNumber);
    {
      map['status'] = Variable<int>(
        $InvoicesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['goods_subtotal_paise'] = Variable<int>(goodsSubtotalPaise);
    map['tax_paise'] = Variable<int>(taxPaise);
    map['loading_paise'] = Variable<int>(loadingPaise);
    map['payable_paise'] = Variable<int>(payablePaise);
    map['total_cft_num'] = Variable<int>(totalCftNum);
    map['total_cft_den'] = Variable<int>(totalCftDen);
    map['tax_policy_snapshot'] = Variable<String>(taxPolicySnapshot);
    map['loading_policy_snapshot'] = Variable<String>(loadingPolicySnapshot);
    map['business_profile_snapshot'] = Variable<String>(
      businessProfileSnapshot,
    );
    map['finalized_at'] = Variable<DateTime>(finalizedAt);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    return map;
  }

  InvoicesCompanion toCompanion(bool nullToAbsent) {
    return InvoicesCompanion(
      id: Value(id),
      invoiceNumber: Value(invoiceNumber),
      status: Value(status),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      goodsSubtotalPaise: Value(goodsSubtotalPaise),
      taxPaise: Value(taxPaise),
      loadingPaise: Value(loadingPaise),
      payablePaise: Value(payablePaise),
      totalCftNum: Value(totalCftNum),
      totalCftDen: Value(totalCftDen),
      taxPolicySnapshot: Value(taxPolicySnapshot),
      loadingPolicySnapshot: Value(loadingPolicySnapshot),
      businessProfileSnapshot: Value(businessProfileSnapshot),
      finalizedAt: Value(finalizedAt),
      idempotencyKey: Value(idempotencyKey),
    );
  }

  factory InvoiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceRow(
      id: serializer.fromJson<int>(json['id']),
      invoiceNumber: serializer.fromJson<String>(json['invoiceNumber']),
      status: $InvoicesTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      customerName: serializer.fromJson<String?>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      goodsSubtotalPaise: serializer.fromJson<int>(json['goodsSubtotalPaise']),
      taxPaise: serializer.fromJson<int>(json['taxPaise']),
      loadingPaise: serializer.fromJson<int>(json['loadingPaise']),
      payablePaise: serializer.fromJson<int>(json['payablePaise']),
      totalCftNum: serializer.fromJson<int>(json['totalCftNum']),
      totalCftDen: serializer.fromJson<int>(json['totalCftDen']),
      taxPolicySnapshot: serializer.fromJson<String>(json['taxPolicySnapshot']),
      loadingPolicySnapshot: serializer.fromJson<String>(
        json['loadingPolicySnapshot'],
      ),
      businessProfileSnapshot: serializer.fromJson<String>(
        json['businessProfileSnapshot'],
      ),
      finalizedAt: serializer.fromJson<DateTime>(json['finalizedAt']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'invoiceNumber': serializer.toJson<String>(invoiceNumber),
      'status': serializer.toJson<int>(
        $InvoicesTable.$converterstatus.toJson(status),
      ),
      'customerName': serializer.toJson<String?>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'goodsSubtotalPaise': serializer.toJson<int>(goodsSubtotalPaise),
      'taxPaise': serializer.toJson<int>(taxPaise),
      'loadingPaise': serializer.toJson<int>(loadingPaise),
      'payablePaise': serializer.toJson<int>(payablePaise),
      'totalCftNum': serializer.toJson<int>(totalCftNum),
      'totalCftDen': serializer.toJson<int>(totalCftDen),
      'taxPolicySnapshot': serializer.toJson<String>(taxPolicySnapshot),
      'loadingPolicySnapshot': serializer.toJson<String>(loadingPolicySnapshot),
      'businessProfileSnapshot': serializer.toJson<String>(
        businessProfileSnapshot,
      ),
      'finalizedAt': serializer.toJson<DateTime>(finalizedAt),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
    };
  }

  InvoiceRow copyWith({
    int? id,
    String? invoiceNumber,
    InvoiceStatus? status,
    Value<String?> customerName = const Value.absent(),
    Value<String?> customerPhone = const Value.absent(),
    int? goodsSubtotalPaise,
    int? taxPaise,
    int? loadingPaise,
    int? payablePaise,
    int? totalCftNum,
    int? totalCftDen,
    String? taxPolicySnapshot,
    String? loadingPolicySnapshot,
    String? businessProfileSnapshot,
    DateTime? finalizedAt,
    String? idempotencyKey,
  }) => InvoiceRow(
    id: id ?? this.id,
    invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    status: status ?? this.status,
    customerName: customerName.present ? customerName.value : this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    goodsSubtotalPaise: goodsSubtotalPaise ?? this.goodsSubtotalPaise,
    taxPaise: taxPaise ?? this.taxPaise,
    loadingPaise: loadingPaise ?? this.loadingPaise,
    payablePaise: payablePaise ?? this.payablePaise,
    totalCftNum: totalCftNum ?? this.totalCftNum,
    totalCftDen: totalCftDen ?? this.totalCftDen,
    taxPolicySnapshot: taxPolicySnapshot ?? this.taxPolicySnapshot,
    loadingPolicySnapshot: loadingPolicySnapshot ?? this.loadingPolicySnapshot,
    businessProfileSnapshot:
        businessProfileSnapshot ?? this.businessProfileSnapshot,
    finalizedAt: finalizedAt ?? this.finalizedAt,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
  );
  InvoiceRow copyWithCompanion(InvoicesCompanion data) {
    return InvoiceRow(
      id: data.id.present ? data.id.value : this.id,
      invoiceNumber: data.invoiceNumber.present
          ? data.invoiceNumber.value
          : this.invoiceNumber,
      status: data.status.present ? data.status.value : this.status,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      goodsSubtotalPaise: data.goodsSubtotalPaise.present
          ? data.goodsSubtotalPaise.value
          : this.goodsSubtotalPaise,
      taxPaise: data.taxPaise.present ? data.taxPaise.value : this.taxPaise,
      loadingPaise: data.loadingPaise.present
          ? data.loadingPaise.value
          : this.loadingPaise,
      payablePaise: data.payablePaise.present
          ? data.payablePaise.value
          : this.payablePaise,
      totalCftNum: data.totalCftNum.present
          ? data.totalCftNum.value
          : this.totalCftNum,
      totalCftDen: data.totalCftDen.present
          ? data.totalCftDen.value
          : this.totalCftDen,
      taxPolicySnapshot: data.taxPolicySnapshot.present
          ? data.taxPolicySnapshot.value
          : this.taxPolicySnapshot,
      loadingPolicySnapshot: data.loadingPolicySnapshot.present
          ? data.loadingPolicySnapshot.value
          : this.loadingPolicySnapshot,
      businessProfileSnapshot: data.businessProfileSnapshot.present
          ? data.businessProfileSnapshot.value
          : this.businessProfileSnapshot,
      finalizedAt: data.finalizedAt.present
          ? data.finalizedAt.value
          : this.finalizedAt,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceRow(')
          ..write('id: $id, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('status: $status, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('goodsSubtotalPaise: $goodsSubtotalPaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('loadingPaise: $loadingPaise, ')
          ..write('payablePaise: $payablePaise, ')
          ..write('totalCftNum: $totalCftNum, ')
          ..write('totalCftDen: $totalCftDen, ')
          ..write('taxPolicySnapshot: $taxPolicySnapshot, ')
          ..write('loadingPolicySnapshot: $loadingPolicySnapshot, ')
          ..write('businessProfileSnapshot: $businessProfileSnapshot, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('idempotencyKey: $idempotencyKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    invoiceNumber,
    status,
    customerName,
    customerPhone,
    goodsSubtotalPaise,
    taxPaise,
    loadingPaise,
    payablePaise,
    totalCftNum,
    totalCftDen,
    taxPolicySnapshot,
    loadingPolicySnapshot,
    businessProfileSnapshot,
    finalizedAt,
    idempotencyKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceRow &&
          other.id == this.id &&
          other.invoiceNumber == this.invoiceNumber &&
          other.status == this.status &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.goodsSubtotalPaise == this.goodsSubtotalPaise &&
          other.taxPaise == this.taxPaise &&
          other.loadingPaise == this.loadingPaise &&
          other.payablePaise == this.payablePaise &&
          other.totalCftNum == this.totalCftNum &&
          other.totalCftDen == this.totalCftDen &&
          other.taxPolicySnapshot == this.taxPolicySnapshot &&
          other.loadingPolicySnapshot == this.loadingPolicySnapshot &&
          other.businessProfileSnapshot == this.businessProfileSnapshot &&
          other.finalizedAt == this.finalizedAt &&
          other.idempotencyKey == this.idempotencyKey);
}

class InvoicesCompanion extends UpdateCompanion<InvoiceRow> {
  final Value<int> id;
  final Value<String> invoiceNumber;
  final Value<InvoiceStatus> status;
  final Value<String?> customerName;
  final Value<String?> customerPhone;
  final Value<int> goodsSubtotalPaise;
  final Value<int> taxPaise;
  final Value<int> loadingPaise;
  final Value<int> payablePaise;
  final Value<int> totalCftNum;
  final Value<int> totalCftDen;
  final Value<String> taxPolicySnapshot;
  final Value<String> loadingPolicySnapshot;
  final Value<String> businessProfileSnapshot;
  final Value<DateTime> finalizedAt;
  final Value<String> idempotencyKey;
  const InvoicesCompanion({
    this.id = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.goodsSubtotalPaise = const Value.absent(),
    this.taxPaise = const Value.absent(),
    this.loadingPaise = const Value.absent(),
    this.payablePaise = const Value.absent(),
    this.totalCftNum = const Value.absent(),
    this.totalCftDen = const Value.absent(),
    this.taxPolicySnapshot = const Value.absent(),
    this.loadingPolicySnapshot = const Value.absent(),
    this.businessProfileSnapshot = const Value.absent(),
    this.finalizedAt = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
  });
  InvoicesCompanion.insert({
    this.id = const Value.absent(),
    required String invoiceNumber,
    required InvoiceStatus status,
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    required int goodsSubtotalPaise,
    required int taxPaise,
    required int loadingPaise,
    required int payablePaise,
    required int totalCftNum,
    required int totalCftDen,
    required String taxPolicySnapshot,
    required String loadingPolicySnapshot,
    required String businessProfileSnapshot,
    required DateTime finalizedAt,
    required String idempotencyKey,
  }) : invoiceNumber = Value(invoiceNumber),
       status = Value(status),
       goodsSubtotalPaise = Value(goodsSubtotalPaise),
       taxPaise = Value(taxPaise),
       loadingPaise = Value(loadingPaise),
       payablePaise = Value(payablePaise),
       totalCftNum = Value(totalCftNum),
       totalCftDen = Value(totalCftDen),
       taxPolicySnapshot = Value(taxPolicySnapshot),
       loadingPolicySnapshot = Value(loadingPolicySnapshot),
       businessProfileSnapshot = Value(businessProfileSnapshot),
       finalizedAt = Value(finalizedAt),
       idempotencyKey = Value(idempotencyKey);
  static Insertable<InvoiceRow> custom({
    Expression<int>? id,
    Expression<String>? invoiceNumber,
    Expression<int>? status,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<int>? goodsSubtotalPaise,
    Expression<int>? taxPaise,
    Expression<int>? loadingPaise,
    Expression<int>? payablePaise,
    Expression<int>? totalCftNum,
    Expression<int>? totalCftDen,
    Expression<String>? taxPolicySnapshot,
    Expression<String>? loadingPolicySnapshot,
    Expression<String>? businessProfileSnapshot,
    Expression<DateTime>? finalizedAt,
    Expression<String>? idempotencyKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (status != null) 'status': status,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (goodsSubtotalPaise != null)
        'goods_subtotal_paise': goodsSubtotalPaise,
      if (taxPaise != null) 'tax_paise': taxPaise,
      if (loadingPaise != null) 'loading_paise': loadingPaise,
      if (payablePaise != null) 'payable_paise': payablePaise,
      if (totalCftNum != null) 'total_cft_num': totalCftNum,
      if (totalCftDen != null) 'total_cft_den': totalCftDen,
      if (taxPolicySnapshot != null) 'tax_policy_snapshot': taxPolicySnapshot,
      if (loadingPolicySnapshot != null)
        'loading_policy_snapshot': loadingPolicySnapshot,
      if (businessProfileSnapshot != null)
        'business_profile_snapshot': businessProfileSnapshot,
      if (finalizedAt != null) 'finalized_at': finalizedAt,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    });
  }

  InvoicesCompanion copyWith({
    Value<int>? id,
    Value<String>? invoiceNumber,
    Value<InvoiceStatus>? status,
    Value<String?>? customerName,
    Value<String?>? customerPhone,
    Value<int>? goodsSubtotalPaise,
    Value<int>? taxPaise,
    Value<int>? loadingPaise,
    Value<int>? payablePaise,
    Value<int>? totalCftNum,
    Value<int>? totalCftDen,
    Value<String>? taxPolicySnapshot,
    Value<String>? loadingPolicySnapshot,
    Value<String>? businessProfileSnapshot,
    Value<DateTime>? finalizedAt,
    Value<String>? idempotencyKey,
  }) {
    return InvoicesCompanion(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      goodsSubtotalPaise: goodsSubtotalPaise ?? this.goodsSubtotalPaise,
      taxPaise: taxPaise ?? this.taxPaise,
      loadingPaise: loadingPaise ?? this.loadingPaise,
      payablePaise: payablePaise ?? this.payablePaise,
      totalCftNum: totalCftNum ?? this.totalCftNum,
      totalCftDen: totalCftDen ?? this.totalCftDen,
      taxPolicySnapshot: taxPolicySnapshot ?? this.taxPolicySnapshot,
      loadingPolicySnapshot:
          loadingPolicySnapshot ?? this.loadingPolicySnapshot,
      businessProfileSnapshot:
          businessProfileSnapshot ?? this.businessProfileSnapshot,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (invoiceNumber.present) {
      map['invoice_number'] = Variable<String>(invoiceNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $InvoicesTable.$converterstatus.toSql(status.value),
      );
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (goodsSubtotalPaise.present) {
      map['goods_subtotal_paise'] = Variable<int>(goodsSubtotalPaise.value);
    }
    if (taxPaise.present) {
      map['tax_paise'] = Variable<int>(taxPaise.value);
    }
    if (loadingPaise.present) {
      map['loading_paise'] = Variable<int>(loadingPaise.value);
    }
    if (payablePaise.present) {
      map['payable_paise'] = Variable<int>(payablePaise.value);
    }
    if (totalCftNum.present) {
      map['total_cft_num'] = Variable<int>(totalCftNum.value);
    }
    if (totalCftDen.present) {
      map['total_cft_den'] = Variable<int>(totalCftDen.value);
    }
    if (taxPolicySnapshot.present) {
      map['tax_policy_snapshot'] = Variable<String>(taxPolicySnapshot.value);
    }
    if (loadingPolicySnapshot.present) {
      map['loading_policy_snapshot'] = Variable<String>(
        loadingPolicySnapshot.value,
      );
    }
    if (businessProfileSnapshot.present) {
      map['business_profile_snapshot'] = Variable<String>(
        businessProfileSnapshot.value,
      );
    }
    if (finalizedAt.present) {
      map['finalized_at'] = Variable<DateTime>(finalizedAt.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoicesCompanion(')
          ..write('id: $id, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('status: $status, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('goodsSubtotalPaise: $goodsSubtotalPaise, ')
          ..write('taxPaise: $taxPaise, ')
          ..write('loadingPaise: $loadingPaise, ')
          ..write('payablePaise: $payablePaise, ')
          ..write('totalCftNum: $totalCftNum, ')
          ..write('totalCftDen: $totalCftDen, ')
          ..write('taxPolicySnapshot: $taxPolicySnapshot, ')
          ..write('loadingPolicySnapshot: $loadingPolicySnapshot, ')
          ..write('businessProfileSnapshot: $businessProfileSnapshot, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('idempotencyKey: $idempotencyKey')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _stockItemIdMeta = const VerificationMeta(
    'stockItemId',
  );
  @override
  late final GeneratedColumn<int> stockItemId = GeneratedColumn<int>(
    'stock_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_items (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MovementType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MovementType>($StockMovementsTable.$convertertype);
  static const VerificationMeta _deltaPiecesMeta = const VerificationMeta(
    'deltaPieces',
  );
  @override
  late final GeneratedColumn<int> deltaPieces = GeneratedColumn<int>(
    'delta_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptEntryIdMeta = const VerificationMeta(
    'receiptEntryId',
  );
  @override
  late final GeneratedColumn<int> receiptEntryId = GeneratedColumn<int>(
    'receipt_entry_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipt_entries (id)',
    ),
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<int> invoiceId = GeneratedColumn<int>(
    'invoice_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id)',
    ),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncState, int> syncState =
      GeneratedColumn<int>(
        'sync_state',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SyncState>($StockMovementsTable.$convertersyncState);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stockItemId,
    type,
    deltaPieces,
    occurredAt,
    receiptEntryId,
    invoiceId,
    reason,
    idempotencyKey,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMovementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('stock_item_id')) {
      context.handle(
        _stockItemIdMeta,
        stockItemId.isAcceptableOrUnknown(
          data['stock_item_id']!,
          _stockItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stockItemIdMeta);
    }
    if (data.containsKey('delta_pieces')) {
      context.handle(
        _deltaPiecesMeta,
        deltaPieces.isAcceptableOrUnknown(
          data['delta_pieces']!,
          _deltaPiecesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deltaPiecesMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('receipt_entry_id')) {
      context.handle(
        _receiptEntryIdMeta,
        receiptEntryId.isAcceptableOrUnknown(
          data['receipt_entry_id']!,
          _receiptEntryIdMeta,
        ),
      );
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      stockItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_item_id'],
      )!,
      type: $StockMovementsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      deltaPieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta_pieces'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      receiptEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_entry_id'],
      ),
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invoice_id'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      syncState: $StockMovementsTable.$convertersyncState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sync_state'],
        )!,
      ),
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MovementType, int, int> $convertertype =
      const EnumIndexConverter<MovementType>(MovementType.values);
  static JsonTypeConverter2<SyncState, int, int> $convertersyncState =
      const EnumIndexConverter<SyncState>(SyncState.values);
}

class StockMovementRow extends DataClass
    implements Insertable<StockMovementRow> {
  /// Primary key.
  final int id;

  /// The stock item this movement applies to.
  final int stockItemId;

  /// Movement kind.
  final MovementType type;

  /// Signed whole-piece delta.
  final int deltaPieces;

  /// When the movement occurred (UTC).
  final DateTime occurredAt;

  /// Optional originating receipt entry.
  final int? receiptEntryId;

  /// Optional originating invoice (for Sale / Void).
  final int? invoiceId;

  /// Reason text; required for Adjust / Reverse (enforced in task 3.2/5.4).
  final String? reason;

  /// Stable idempotency key; unique so retries apply exactly once.
  final String idempotencyKey;

  /// Pending / Confirmed / Failed.
  final SyncState syncState;
  const StockMovementRow({
    required this.id,
    required this.stockItemId,
    required this.type,
    required this.deltaPieces,
    required this.occurredAt,
    this.receiptEntryId,
    this.invoiceId,
    this.reason,
    required this.idempotencyKey,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['stock_item_id'] = Variable<int>(stockItemId);
    {
      map['type'] = Variable<int>(
        $StockMovementsTable.$convertertype.toSql(type),
      );
    }
    map['delta_pieces'] = Variable<int>(deltaPieces);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || receiptEntryId != null) {
      map['receipt_entry_id'] = Variable<int>(receiptEntryId);
    }
    if (!nullToAbsent || invoiceId != null) {
      map['invoice_id'] = Variable<int>(invoiceId);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    {
      map['sync_state'] = Variable<int>(
        $StockMovementsTable.$convertersyncState.toSql(syncState),
      );
    }
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      stockItemId: Value(stockItemId),
      type: Value(type),
      deltaPieces: Value(deltaPieces),
      occurredAt: Value(occurredAt),
      receiptEntryId: receiptEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptEntryId),
      invoiceId: invoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceId),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      idempotencyKey: Value(idempotencyKey),
      syncState: Value(syncState),
    );
  }

  factory StockMovementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovementRow(
      id: serializer.fromJson<int>(json['id']),
      stockItemId: serializer.fromJson<int>(json['stockItemId']),
      type: $StockMovementsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      deltaPieces: serializer.fromJson<int>(json['deltaPieces']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      receiptEntryId: serializer.fromJson<int?>(json['receiptEntryId']),
      invoiceId: serializer.fromJson<int?>(json['invoiceId']),
      reason: serializer.fromJson<String?>(json['reason']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      syncState: $StockMovementsTable.$convertersyncState.fromJson(
        serializer.fromJson<int>(json['syncState']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'stockItemId': serializer.toJson<int>(stockItemId),
      'type': serializer.toJson<int>(
        $StockMovementsTable.$convertertype.toJson(type),
      ),
      'deltaPieces': serializer.toJson<int>(deltaPieces),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'receiptEntryId': serializer.toJson<int?>(receiptEntryId),
      'invoiceId': serializer.toJson<int?>(invoiceId),
      'reason': serializer.toJson<String?>(reason),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'syncState': serializer.toJson<int>(
        $StockMovementsTable.$convertersyncState.toJson(syncState),
      ),
    };
  }

  StockMovementRow copyWith({
    int? id,
    int? stockItemId,
    MovementType? type,
    int? deltaPieces,
    DateTime? occurredAt,
    Value<int?> receiptEntryId = const Value.absent(),
    Value<int?> invoiceId = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    String? idempotencyKey,
    SyncState? syncState,
  }) => StockMovementRow(
    id: id ?? this.id,
    stockItemId: stockItemId ?? this.stockItemId,
    type: type ?? this.type,
    deltaPieces: deltaPieces ?? this.deltaPieces,
    occurredAt: occurredAt ?? this.occurredAt,
    receiptEntryId: receiptEntryId.present
        ? receiptEntryId.value
        : this.receiptEntryId,
    invoiceId: invoiceId.present ? invoiceId.value : this.invoiceId,
    reason: reason.present ? reason.value : this.reason,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    syncState: syncState ?? this.syncState,
  );
  StockMovementRow copyWithCompanion(StockMovementsCompanion data) {
    return StockMovementRow(
      id: data.id.present ? data.id.value : this.id,
      stockItemId: data.stockItemId.present
          ? data.stockItemId.value
          : this.stockItemId,
      type: data.type.present ? data.type.value : this.type,
      deltaPieces: data.deltaPieces.present
          ? data.deltaPieces.value
          : this.deltaPieces,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      receiptEntryId: data.receiptEntryId.present
          ? data.receiptEntryId.value
          : this.receiptEntryId,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      reason: data.reason.present ? data.reason.value : this.reason,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementRow(')
          ..write('id: $id, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('type: $type, ')
          ..write('deltaPieces: $deltaPieces, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('receiptEntryId: $receiptEntryId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('reason: $reason, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stockItemId,
    type,
    deltaPieces,
    occurredAt,
    receiptEntryId,
    invoiceId,
    reason,
    idempotencyKey,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovementRow &&
          other.id == this.id &&
          other.stockItemId == this.stockItemId &&
          other.type == this.type &&
          other.deltaPieces == this.deltaPieces &&
          other.occurredAt == this.occurredAt &&
          other.receiptEntryId == this.receiptEntryId &&
          other.invoiceId == this.invoiceId &&
          other.reason == this.reason &&
          other.idempotencyKey == this.idempotencyKey &&
          other.syncState == this.syncState);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovementRow> {
  final Value<int> id;
  final Value<int> stockItemId;
  final Value<MovementType> type;
  final Value<int> deltaPieces;
  final Value<DateTime> occurredAt;
  final Value<int?> receiptEntryId;
  final Value<int?> invoiceId;
  final Value<String?> reason;
  final Value<String> idempotencyKey;
  final Value<SyncState> syncState;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.stockItemId = const Value.absent(),
    this.type = const Value.absent(),
    this.deltaPieces = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.receiptEntryId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.reason = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.syncState = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int stockItemId,
    required MovementType type,
    required int deltaPieces,
    required DateTime occurredAt,
    this.receiptEntryId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.reason = const Value.absent(),
    required String idempotencyKey,
    required SyncState syncState,
  }) : stockItemId = Value(stockItemId),
       type = Value(type),
       deltaPieces = Value(deltaPieces),
       occurredAt = Value(occurredAt),
       idempotencyKey = Value(idempotencyKey),
       syncState = Value(syncState);
  static Insertable<StockMovementRow> custom({
    Expression<int>? id,
    Expression<int>? stockItemId,
    Expression<int>? type,
    Expression<int>? deltaPieces,
    Expression<DateTime>? occurredAt,
    Expression<int>? receiptEntryId,
    Expression<int>? invoiceId,
    Expression<String>? reason,
    Expression<String>? idempotencyKey,
    Expression<int>? syncState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stockItemId != null) 'stock_item_id': stockItemId,
      if (type != null) 'type': type,
      if (deltaPieces != null) 'delta_pieces': deltaPieces,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (receiptEntryId != null) 'receipt_entry_id': receiptEntryId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (syncState != null) 'sync_state': syncState,
    });
  }

  StockMovementsCompanion copyWith({
    Value<int>? id,
    Value<int>? stockItemId,
    Value<MovementType>? type,
    Value<int>? deltaPieces,
    Value<DateTime>? occurredAt,
    Value<int?>? receiptEntryId,
    Value<int?>? invoiceId,
    Value<String?>? reason,
    Value<String>? idempotencyKey,
    Value<SyncState>? syncState,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      stockItemId: stockItemId ?? this.stockItemId,
      type: type ?? this.type,
      deltaPieces: deltaPieces ?? this.deltaPieces,
      occurredAt: occurredAt ?? this.occurredAt,
      receiptEntryId: receiptEntryId ?? this.receiptEntryId,
      invoiceId: invoiceId ?? this.invoiceId,
      reason: reason ?? this.reason,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      syncState: syncState ?? this.syncState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (stockItemId.present) {
      map['stock_item_id'] = Variable<int>(stockItemId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $StockMovementsTable.$convertertype.toSql(type.value),
      );
    }
    if (deltaPieces.present) {
      map['delta_pieces'] = Variable<int>(deltaPieces.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (receiptEntryId.present) {
      map['receipt_entry_id'] = Variable<int>(receiptEntryId.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<int>(invoiceId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<int>(
        $StockMovementsTable.$convertersyncState.toSql(syncState.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('type: $type, ')
          ..write('deltaPieces: $deltaPieces, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('receiptEntryId: $receiptEntryId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('reason: $reason, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }
}

class $PriceRatesTable extends PriceRates
    with TableInfo<$PriceRatesTable, PriceRateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _varietyIdMeta = const VerificationMeta(
    'varietyId',
  );
  @override
  late final GeneratedColumn<int> varietyId = GeneratedColumn<int>(
    'variety_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wood_varieties (id)',
    ),
  );
  static const VerificationMeta _crossSectionIdMeta = const VerificationMeta(
    'crossSectionId',
  );
  @override
  late final GeneratedColumn<int> crossSectionId = GeneratedColumn<int>(
    'cross_section_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cross_sections (id)',
    ),
  );
  static const VerificationMeta _rateNumMeta = const VerificationMeta(
    'rateNum',
  );
  @override
  late final GeneratedColumn<int> rateNum = GeneratedColumn<int>(
    'rate_num',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rateDenMeta = const VerificationMeta(
    'rateDen',
  );
  @override
  late final GeneratedColumn<int> rateDen = GeneratedColumn<int>(
    'rate_den',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    varietyId,
    crossSectionId,
    rateNum,
    rateDen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceRateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('variety_id')) {
      context.handle(
        _varietyIdMeta,
        varietyId.isAcceptableOrUnknown(data['variety_id']!, _varietyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_varietyIdMeta);
    }
    if (data.containsKey('cross_section_id')) {
      context.handle(
        _crossSectionIdMeta,
        crossSectionId.isAcceptableOrUnknown(
          data['cross_section_id']!,
          _crossSectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_crossSectionIdMeta);
    }
    if (data.containsKey('rate_num')) {
      context.handle(
        _rateNumMeta,
        rateNum.isAcceptableOrUnknown(data['rate_num']!, _rateNumMeta),
      );
    }
    if (data.containsKey('rate_den')) {
      context.handle(
        _rateDenMeta,
        rateDen.isAcceptableOrUnknown(data['rate_den']!, _rateDenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {varietyId, crossSectionId},
  ];
  @override
  PriceRateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceRateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      varietyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variety_id'],
      )!,
      crossSectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cross_section_id'],
      )!,
      rateNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_num'],
      ),
      rateDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_den'],
      ),
    );
  }

  @override
  $PriceRatesTable createAlias(String alias) {
    return $PriceRatesTable(attachedDatabase, alias);
  }
}

class PriceRateRow extends DataClass implements Insertable<PriceRateRow> {
  /// Primary key.
  final int id;

  /// Owning variety.
  final int varietyId;

  /// Owning cross-section.
  final int crossSectionId;

  /// Exact rational rate numerator (paise-per-CFT); null = missing rate.
  final int? rateNum;

  /// Exact rational rate denominator; null = missing rate.
  final int? rateDen;
  const PriceRateRow({
    required this.id,
    required this.varietyId,
    required this.crossSectionId,
    this.rateNum,
    this.rateDen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['variety_id'] = Variable<int>(varietyId);
    map['cross_section_id'] = Variable<int>(crossSectionId);
    if (!nullToAbsent || rateNum != null) {
      map['rate_num'] = Variable<int>(rateNum);
    }
    if (!nullToAbsent || rateDen != null) {
      map['rate_den'] = Variable<int>(rateDen);
    }
    return map;
  }

  PriceRatesCompanion toCompanion(bool nullToAbsent) {
    return PriceRatesCompanion(
      id: Value(id),
      varietyId: Value(varietyId),
      crossSectionId: Value(crossSectionId),
      rateNum: rateNum == null && nullToAbsent
          ? const Value.absent()
          : Value(rateNum),
      rateDen: rateDen == null && nullToAbsent
          ? const Value.absent()
          : Value(rateDen),
    );
  }

  factory PriceRateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceRateRow(
      id: serializer.fromJson<int>(json['id']),
      varietyId: serializer.fromJson<int>(json['varietyId']),
      crossSectionId: serializer.fromJson<int>(json['crossSectionId']),
      rateNum: serializer.fromJson<int?>(json['rateNum']),
      rateDen: serializer.fromJson<int?>(json['rateDen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'varietyId': serializer.toJson<int>(varietyId),
      'crossSectionId': serializer.toJson<int>(crossSectionId),
      'rateNum': serializer.toJson<int?>(rateNum),
      'rateDen': serializer.toJson<int?>(rateDen),
    };
  }

  PriceRateRow copyWith({
    int? id,
    int? varietyId,
    int? crossSectionId,
    Value<int?> rateNum = const Value.absent(),
    Value<int?> rateDen = const Value.absent(),
  }) => PriceRateRow(
    id: id ?? this.id,
    varietyId: varietyId ?? this.varietyId,
    crossSectionId: crossSectionId ?? this.crossSectionId,
    rateNum: rateNum.present ? rateNum.value : this.rateNum,
    rateDen: rateDen.present ? rateDen.value : this.rateDen,
  );
  PriceRateRow copyWithCompanion(PriceRatesCompanion data) {
    return PriceRateRow(
      id: data.id.present ? data.id.value : this.id,
      varietyId: data.varietyId.present ? data.varietyId.value : this.varietyId,
      crossSectionId: data.crossSectionId.present
          ? data.crossSectionId.value
          : this.crossSectionId,
      rateNum: data.rateNum.present ? data.rateNum.value : this.rateNum,
      rateDen: data.rateDen.present ? data.rateDen.value : this.rateDen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceRateRow(')
          ..write('id: $id, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, varietyId, crossSectionId, rateNum, rateDen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceRateRow &&
          other.id == this.id &&
          other.varietyId == this.varietyId &&
          other.crossSectionId == this.crossSectionId &&
          other.rateNum == this.rateNum &&
          other.rateDen == this.rateDen);
}

class PriceRatesCompanion extends UpdateCompanion<PriceRateRow> {
  final Value<int> id;
  final Value<int> varietyId;
  final Value<int> crossSectionId;
  final Value<int?> rateNum;
  final Value<int?> rateDen;
  const PriceRatesCompanion({
    this.id = const Value.absent(),
    this.varietyId = const Value.absent(),
    this.crossSectionId = const Value.absent(),
    this.rateNum = const Value.absent(),
    this.rateDen = const Value.absent(),
  });
  PriceRatesCompanion.insert({
    this.id = const Value.absent(),
    required int varietyId,
    required int crossSectionId,
    this.rateNum = const Value.absent(),
    this.rateDen = const Value.absent(),
  }) : varietyId = Value(varietyId),
       crossSectionId = Value(crossSectionId);
  static Insertable<PriceRateRow> custom({
    Expression<int>? id,
    Expression<int>? varietyId,
    Expression<int>? crossSectionId,
    Expression<int>? rateNum,
    Expression<int>? rateDen,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (varietyId != null) 'variety_id': varietyId,
      if (crossSectionId != null) 'cross_section_id': crossSectionId,
      if (rateNum != null) 'rate_num': rateNum,
      if (rateDen != null) 'rate_den': rateDen,
    });
  }

  PriceRatesCompanion copyWith({
    Value<int>? id,
    Value<int>? varietyId,
    Value<int>? crossSectionId,
    Value<int?>? rateNum,
    Value<int?>? rateDen,
  }) {
    return PriceRatesCompanion(
      id: id ?? this.id,
      varietyId: varietyId ?? this.varietyId,
      crossSectionId: crossSectionId ?? this.crossSectionId,
      rateNum: rateNum ?? this.rateNum,
      rateDen: rateDen ?? this.rateDen,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (varietyId.present) {
      map['variety_id'] = Variable<int>(varietyId.value);
    }
    if (crossSectionId.present) {
      map['cross_section_id'] = Variable<int>(crossSectionId.value);
    }
    if (rateNum.present) {
      map['rate_num'] = Variable<int>(rateNum.value);
    }
    if (rateDen.present) {
      map['rate_den'] = Variable<int>(rateDen.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceRatesCompanion(')
          ..write('id: $id, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen')
          ..write(')'))
        .toString();
  }
}

class $DraftOrdersTable extends DraftOrders
    with TableInfo<$DraftOrdersTable, DraftOrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DraftStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DraftStatus>($DraftOrdersTable.$converterstatus);
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerPhoneMeta = const VerificationMeta(
    'customerPhone',
  );
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
    'customer_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<int> invoiceId = GeneratedColumn<int>(
    'invoice_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    customerName,
    customerPhone,
    createdAt,
    title,
    updatedAt,
    invoiceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftOrderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
        _customerPhoneMeta,
        customerPhone.isAcceptableOrUnknown(
          data['customer_phone']!,
          _customerPhoneMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftOrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftOrderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      status: $DraftOrdersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      customerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_phone'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invoice_id'],
      ),
    );
  }

  @override
  $DraftOrdersTable createAlias(String alias) {
    return $DraftOrdersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DraftStatus, int, int> $converterstatus =
      const EnumIndexConverter<DraftStatus>(DraftStatus.values);
}

class DraftOrderRow extends DataClass implements Insertable<DraftOrderRow> {
  /// Primary key.
  final int id;

  /// Draft or Preview.
  final DraftStatus status;

  /// Optional customer name.
  final String? customerName;

  /// Optional customer phone.
  final String? customerPhone;

  /// Row creation time (UTC).
  final DateTime createdAt;

  /// Optional owner-facing title for a saved order (schema v2; app-ux-revamp).
  final String? title;

  /// When the draft was last touched (UTC); drives the resumable-orders sort
  /// (schema v2; app-ux-revamp). Defaults to row-creation time on upgrade.
  final DateTime updatedAt;

  /// The permanent invoice this draft produced once sold; null until then
  /// (schema v2; app-ux-revamp).
  final int? invoiceId;
  const DraftOrderRow({
    required this.id,
    required this.status,
    this.customerName,
    this.customerPhone,
    required this.createdAt,
    this.title,
    required this.updatedAt,
    this.invoiceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['status'] = Variable<int>(
        $DraftOrdersTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || invoiceId != null) {
      map['invoice_id'] = Variable<int>(invoiceId);
    }
    return map;
  }

  DraftOrdersCompanion toCompanion(bool nullToAbsent) {
    return DraftOrdersCompanion(
      id: Value(id),
      status: Value(status),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      createdAt: Value(createdAt),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      updatedAt: Value(updatedAt),
      invoiceId: invoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceId),
    );
  }

  factory DraftOrderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftOrderRow(
      id: serializer.fromJson<int>(json['id']),
      status: $DraftOrdersTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      customerName: serializer.fromJson<String?>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      title: serializer.fromJson<String?>(json['title']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      invoiceId: serializer.fromJson<int?>(json['invoiceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<int>(
        $DraftOrdersTable.$converterstatus.toJson(status),
      ),
      'customerName': serializer.toJson<String?>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'title': serializer.toJson<String?>(title),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'invoiceId': serializer.toJson<int?>(invoiceId),
    };
  }

  DraftOrderRow copyWith({
    int? id,
    DraftStatus? status,
    Value<String?> customerName = const Value.absent(),
    Value<String?> customerPhone = const Value.absent(),
    DateTime? createdAt,
    Value<String?> title = const Value.absent(),
    DateTime? updatedAt,
    Value<int?> invoiceId = const Value.absent(),
  }) => DraftOrderRow(
    id: id ?? this.id,
    status: status ?? this.status,
    customerName: customerName.present ? customerName.value : this.customerName,
    customerPhone: customerPhone.present
        ? customerPhone.value
        : this.customerPhone,
    createdAt: createdAt ?? this.createdAt,
    title: title.present ? title.value : this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    invoiceId: invoiceId.present ? invoiceId.value : this.invoiceId,
  );
  DraftOrderRow copyWithCompanion(DraftOrdersCompanion data) {
    return DraftOrderRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      title: data.title.present ? data.title.value : this.title,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftOrderRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('invoiceId: $invoiceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    customerName,
    customerPhone,
    createdAt,
    title,
    updatedAt,
    invoiceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftOrderRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.createdAt == this.createdAt &&
          other.title == this.title &&
          other.updatedAt == this.updatedAt &&
          other.invoiceId == this.invoiceId);
}

class DraftOrdersCompanion extends UpdateCompanion<DraftOrderRow> {
  final Value<int> id;
  final Value<DraftStatus> status;
  final Value<String?> customerName;
  final Value<String?> customerPhone;
  final Value<DateTime> createdAt;
  final Value<String?> title;
  final Value<DateTime> updatedAt;
  final Value<int?> invoiceId;
  const DraftOrdersCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.invoiceId = const Value.absent(),
  });
  DraftOrdersCompanion.insert({
    this.id = const Value.absent(),
    required DraftStatus status,
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    required DateTime createdAt,
    this.title = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.invoiceId = const Value.absent(),
  }) : status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DraftOrderRow> custom({
    Expression<int>? id,
    Expression<int>? status,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<DateTime>? createdAt,
    Expression<String>? title,
    Expression<DateTime>? updatedAt,
    Expression<int>? invoiceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (createdAt != null) 'created_at': createdAt,
      if (title != null) 'title': title,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (invoiceId != null) 'invoice_id': invoiceId,
    });
  }

  DraftOrdersCompanion copyWith({
    Value<int>? id,
    Value<DraftStatus>? status,
    Value<String?>? customerName,
    Value<String?>? customerPhone,
    Value<DateTime>? createdAt,
    Value<String?>? title,
    Value<DateTime>? updatedAt,
    Value<int?>? invoiceId,
  }) {
    return DraftOrdersCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      invoiceId: invoiceId ?? this.invoiceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DraftOrdersTable.$converterstatus.toSql(status.value),
      );
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<int>(invoiceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftOrdersCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('invoiceId: $invoiceId')
          ..write(')'))
        .toString();
  }
}

class $DraftOrderRequestsTable extends DraftOrderRequests
    with TableInfo<$DraftOrderRequestsTable, DraftOrderRequestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftOrderRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<int> draftId = GeneratedColumn<int>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES draft_orders (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RequestType, int> requestType =
      GeneratedColumn<int>(
        'request_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<RequestType>(
        $DraftOrderRequestsTable.$converterrequestType,
      );
  static const VerificationMeta _varietyIdMeta = const VerificationMeta(
    'varietyId',
  );
  @override
  late final GeneratedColumn<int> varietyId = GeneratedColumn<int>(
    'variety_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wood_varieties (id)',
    ),
  );
  static const VerificationMeta _crossSectionIdMeta = const VerificationMeta(
    'crossSectionId',
  );
  @override
  late final GeneratedColumn<int> crossSectionId = GeneratedColumn<int>(
    'cross_section_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cross_sections (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind?, int> category =
      GeneratedColumn<int>(
        'category',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<CategoryKind?>(
        $DraftOrderRequestsTable.$convertercategoryn,
      );
  static const VerificationMeta _lengthFtMeta = const VerificationMeta(
    'lengthFt',
  );
  @override
  late final GeneratedColumn<int> lengthFt = GeneratedColumn<int>(
    'length_ft',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetCftNumMeta = const VerificationMeta(
    'targetCftNum',
  );
  @override
  late final GeneratedColumn<int> targetCftNum = GeneratedColumn<int>(
    'target_cft_num',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetCftDenMeta = const VerificationMeta(
    'targetCftDen',
  );
  @override
  late final GeneratedColumn<int> targetCftDen = GeneratedColumn<int>(
    'target_cft_den',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftId,
    requestType,
    varietyId,
    crossSectionId,
    category,
    lengthFt,
    targetCftNum,
    targetCftDen,
    qty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_order_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftOrderRequestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('variety_id')) {
      context.handle(
        _varietyIdMeta,
        varietyId.isAcceptableOrUnknown(data['variety_id']!, _varietyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_varietyIdMeta);
    }
    if (data.containsKey('cross_section_id')) {
      context.handle(
        _crossSectionIdMeta,
        crossSectionId.isAcceptableOrUnknown(
          data['cross_section_id']!,
          _crossSectionIdMeta,
        ),
      );
    }
    if (data.containsKey('length_ft')) {
      context.handle(
        _lengthFtMeta,
        lengthFt.isAcceptableOrUnknown(data['length_ft']!, _lengthFtMeta),
      );
    }
    if (data.containsKey('target_cft_num')) {
      context.handle(
        _targetCftNumMeta,
        targetCftNum.isAcceptableOrUnknown(
          data['target_cft_num']!,
          _targetCftNumMeta,
        ),
      );
    }
    if (data.containsKey('target_cft_den')) {
      context.handle(
        _targetCftDenMeta,
        targetCftDen.isAcceptableOrUnknown(
          data['target_cft_den']!,
          _targetCftDenMeta,
        ),
      );
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftOrderRequestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftOrderRequestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}draft_id'],
      )!,
      requestType: $DraftOrderRequestsTable.$converterrequestType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}request_type'],
        )!,
      ),
      varietyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variety_id'],
      )!,
      crossSectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cross_section_id'],
      ),
      category: $DraftOrderRequestsTable.$convertercategoryn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}category'],
        ),
      ),
      lengthFt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length_ft'],
      ),
      targetCftNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_cft_num'],
      ),
      targetCftDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_cft_den'],
      ),
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      ),
    );
  }

  @override
  $DraftOrderRequestsTable createAlias(String alias) {
    return $DraftOrderRequestsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RequestType, int, int> $converterrequestType =
      const EnumIndexConverter<RequestType>(RequestType.values);
  static JsonTypeConverter2<CategoryKind, int, int> $convertercategory =
      const EnumIndexConverter<CategoryKind>(CategoryKind.values);
  static JsonTypeConverter2<CategoryKind?, int?, int?> $convertercategoryn =
      JsonTypeConverter2.asNullable($convertercategory);
}

class DraftOrderRequestRow extends DataClass
    implements Insertable<DraftOrderRequestRow> {
  /// Primary key.
  final int id;

  /// Owning draft.
  final int draftId;

  /// Which of the four structured request types this is.
  final RequestType requestType;

  /// Target variety.
  final int varietyId;

  /// Optional fixed cross-section.
  final int? crossSectionId;

  /// Optional category constraint (for flexible-category requests).
  final CategoryKind? category;

  /// Optional fixed length in feet.
  final int? lengthFt;

  /// Optional target-CFT numerator.
  final int? targetCftNum;

  /// Optional target-CFT denominator.
  final int? targetCftDen;

  /// Optional exact quantity (for exact-qty requests).
  final int? qty;
  const DraftOrderRequestRow({
    required this.id,
    required this.draftId,
    required this.requestType,
    required this.varietyId,
    this.crossSectionId,
    this.category,
    this.lengthFt,
    this.targetCftNum,
    this.targetCftDen,
    this.qty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['draft_id'] = Variable<int>(draftId);
    {
      map['request_type'] = Variable<int>(
        $DraftOrderRequestsTable.$converterrequestType.toSql(requestType),
      );
    }
    map['variety_id'] = Variable<int>(varietyId);
    if (!nullToAbsent || crossSectionId != null) {
      map['cross_section_id'] = Variable<int>(crossSectionId);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<int>(
        $DraftOrderRequestsTable.$convertercategoryn.toSql(category),
      );
    }
    if (!nullToAbsent || lengthFt != null) {
      map['length_ft'] = Variable<int>(lengthFt);
    }
    if (!nullToAbsent || targetCftNum != null) {
      map['target_cft_num'] = Variable<int>(targetCftNum);
    }
    if (!nullToAbsent || targetCftDen != null) {
      map['target_cft_den'] = Variable<int>(targetCftDen);
    }
    if (!nullToAbsent || qty != null) {
      map['qty'] = Variable<int>(qty);
    }
    return map;
  }

  DraftOrderRequestsCompanion toCompanion(bool nullToAbsent) {
    return DraftOrderRequestsCompanion(
      id: Value(id),
      draftId: Value(draftId),
      requestType: Value(requestType),
      varietyId: Value(varietyId),
      crossSectionId: crossSectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(crossSectionId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      lengthFt: lengthFt == null && nullToAbsent
          ? const Value.absent()
          : Value(lengthFt),
      targetCftNum: targetCftNum == null && nullToAbsent
          ? const Value.absent()
          : Value(targetCftNum),
      targetCftDen: targetCftDen == null && nullToAbsent
          ? const Value.absent()
          : Value(targetCftDen),
      qty: qty == null && nullToAbsent ? const Value.absent() : Value(qty),
    );
  }

  factory DraftOrderRequestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftOrderRequestRow(
      id: serializer.fromJson<int>(json['id']),
      draftId: serializer.fromJson<int>(json['draftId']),
      requestType: $DraftOrderRequestsTable.$converterrequestType.fromJson(
        serializer.fromJson<int>(json['requestType']),
      ),
      varietyId: serializer.fromJson<int>(json['varietyId']),
      crossSectionId: serializer.fromJson<int?>(json['crossSectionId']),
      category: $DraftOrderRequestsTable.$convertercategoryn.fromJson(
        serializer.fromJson<int?>(json['category']),
      ),
      lengthFt: serializer.fromJson<int?>(json['lengthFt']),
      targetCftNum: serializer.fromJson<int?>(json['targetCftNum']),
      targetCftDen: serializer.fromJson<int?>(json['targetCftDen']),
      qty: serializer.fromJson<int?>(json['qty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'draftId': serializer.toJson<int>(draftId),
      'requestType': serializer.toJson<int>(
        $DraftOrderRequestsTable.$converterrequestType.toJson(requestType),
      ),
      'varietyId': serializer.toJson<int>(varietyId),
      'crossSectionId': serializer.toJson<int?>(crossSectionId),
      'category': serializer.toJson<int?>(
        $DraftOrderRequestsTable.$convertercategoryn.toJson(category),
      ),
      'lengthFt': serializer.toJson<int?>(lengthFt),
      'targetCftNum': serializer.toJson<int?>(targetCftNum),
      'targetCftDen': serializer.toJson<int?>(targetCftDen),
      'qty': serializer.toJson<int?>(qty),
    };
  }

  DraftOrderRequestRow copyWith({
    int? id,
    int? draftId,
    RequestType? requestType,
    int? varietyId,
    Value<int?> crossSectionId = const Value.absent(),
    Value<CategoryKind?> category = const Value.absent(),
    Value<int?> lengthFt = const Value.absent(),
    Value<int?> targetCftNum = const Value.absent(),
    Value<int?> targetCftDen = const Value.absent(),
    Value<int?> qty = const Value.absent(),
  }) => DraftOrderRequestRow(
    id: id ?? this.id,
    draftId: draftId ?? this.draftId,
    requestType: requestType ?? this.requestType,
    varietyId: varietyId ?? this.varietyId,
    crossSectionId: crossSectionId.present
        ? crossSectionId.value
        : this.crossSectionId,
    category: category.present ? category.value : this.category,
    lengthFt: lengthFt.present ? lengthFt.value : this.lengthFt,
    targetCftNum: targetCftNum.present ? targetCftNum.value : this.targetCftNum,
    targetCftDen: targetCftDen.present ? targetCftDen.value : this.targetCftDen,
    qty: qty.present ? qty.value : this.qty,
  );
  DraftOrderRequestRow copyWithCompanion(DraftOrderRequestsCompanion data) {
    return DraftOrderRequestRow(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      requestType: data.requestType.present
          ? data.requestType.value
          : this.requestType,
      varietyId: data.varietyId.present ? data.varietyId.value : this.varietyId,
      crossSectionId: data.crossSectionId.present
          ? data.crossSectionId.value
          : this.crossSectionId,
      category: data.category.present ? data.category.value : this.category,
      lengthFt: data.lengthFt.present ? data.lengthFt.value : this.lengthFt,
      targetCftNum: data.targetCftNum.present
          ? data.targetCftNum.value
          : this.targetCftNum,
      targetCftDen: data.targetCftDen.present
          ? data.targetCftDen.value
          : this.targetCftDen,
      qty: data.qty.present ? data.qty.value : this.qty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftOrderRequestRow(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('requestType: $requestType, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('category: $category, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('targetCftNum: $targetCftNum, ')
          ..write('targetCftDen: $targetCftDen, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    draftId,
    requestType,
    varietyId,
    crossSectionId,
    category,
    lengthFt,
    targetCftNum,
    targetCftDen,
    qty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftOrderRequestRow &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.requestType == this.requestType &&
          other.varietyId == this.varietyId &&
          other.crossSectionId == this.crossSectionId &&
          other.category == this.category &&
          other.lengthFt == this.lengthFt &&
          other.targetCftNum == this.targetCftNum &&
          other.targetCftDen == this.targetCftDen &&
          other.qty == this.qty);
}

class DraftOrderRequestsCompanion
    extends UpdateCompanion<DraftOrderRequestRow> {
  final Value<int> id;
  final Value<int> draftId;
  final Value<RequestType> requestType;
  final Value<int> varietyId;
  final Value<int?> crossSectionId;
  final Value<CategoryKind?> category;
  final Value<int?> lengthFt;
  final Value<int?> targetCftNum;
  final Value<int?> targetCftDen;
  final Value<int?> qty;
  const DraftOrderRequestsCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.requestType = const Value.absent(),
    this.varietyId = const Value.absent(),
    this.crossSectionId = const Value.absent(),
    this.category = const Value.absent(),
    this.lengthFt = const Value.absent(),
    this.targetCftNum = const Value.absent(),
    this.targetCftDen = const Value.absent(),
    this.qty = const Value.absent(),
  });
  DraftOrderRequestsCompanion.insert({
    this.id = const Value.absent(),
    required int draftId,
    required RequestType requestType,
    required int varietyId,
    this.crossSectionId = const Value.absent(),
    this.category = const Value.absent(),
    this.lengthFt = const Value.absent(),
    this.targetCftNum = const Value.absent(),
    this.targetCftDen = const Value.absent(),
    this.qty = const Value.absent(),
  }) : draftId = Value(draftId),
       requestType = Value(requestType),
       varietyId = Value(varietyId);
  static Insertable<DraftOrderRequestRow> custom({
    Expression<int>? id,
    Expression<int>? draftId,
    Expression<int>? requestType,
    Expression<int>? varietyId,
    Expression<int>? crossSectionId,
    Expression<int>? category,
    Expression<int>? lengthFt,
    Expression<int>? targetCftNum,
    Expression<int>? targetCftDen,
    Expression<int>? qty,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (requestType != null) 'request_type': requestType,
      if (varietyId != null) 'variety_id': varietyId,
      if (crossSectionId != null) 'cross_section_id': crossSectionId,
      if (category != null) 'category': category,
      if (lengthFt != null) 'length_ft': lengthFt,
      if (targetCftNum != null) 'target_cft_num': targetCftNum,
      if (targetCftDen != null) 'target_cft_den': targetCftDen,
      if (qty != null) 'qty': qty,
    });
  }

  DraftOrderRequestsCompanion copyWith({
    Value<int>? id,
    Value<int>? draftId,
    Value<RequestType>? requestType,
    Value<int>? varietyId,
    Value<int?>? crossSectionId,
    Value<CategoryKind?>? category,
    Value<int?>? lengthFt,
    Value<int?>? targetCftNum,
    Value<int?>? targetCftDen,
    Value<int?>? qty,
  }) {
    return DraftOrderRequestsCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      requestType: requestType ?? this.requestType,
      varietyId: varietyId ?? this.varietyId,
      crossSectionId: crossSectionId ?? this.crossSectionId,
      category: category ?? this.category,
      lengthFt: lengthFt ?? this.lengthFt,
      targetCftNum: targetCftNum ?? this.targetCftNum,
      targetCftDen: targetCftDen ?? this.targetCftDen,
      qty: qty ?? this.qty,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<int>(draftId.value);
    }
    if (requestType.present) {
      map['request_type'] = Variable<int>(
        $DraftOrderRequestsTable.$converterrequestType.toSql(requestType.value),
      );
    }
    if (varietyId.present) {
      map['variety_id'] = Variable<int>(varietyId.value);
    }
    if (crossSectionId.present) {
      map['cross_section_id'] = Variable<int>(crossSectionId.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(
        $DraftOrderRequestsTable.$convertercategoryn.toSql(category.value),
      );
    }
    if (lengthFt.present) {
      map['length_ft'] = Variable<int>(lengthFt.value);
    }
    if (targetCftNum.present) {
      map['target_cft_num'] = Variable<int>(targetCftNum.value);
    }
    if (targetCftDen.present) {
      map['target_cft_den'] = Variable<int>(targetCftDen.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftOrderRequestsCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('requestType: $requestType, ')
          ..write('varietyId: $varietyId, ')
          ..write('crossSectionId: $crossSectionId, ')
          ..write('category: $category, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('targetCftNum: $targetCftNum, ')
          ..write('targetCftDen: $targetCftDen, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }
}

class $AllocationLinesTable extends AllocationLines
    with TableInfo<$AllocationLinesTable, AllocationLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllocationLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<int> draftId = GeneratedColumn<int>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES draft_orders (id)',
    ),
  );
  static const VerificationMeta _stockItemIdMeta = const VerificationMeta(
    'stockItemId',
  );
  @override
  late final GeneratedColumn<int> stockItemId = GeneratedColumn<int>(
    'stock_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_items (id)',
    ),
  );
  static const VerificationMeta _qtyUnitsMeta = const VerificationMeta(
    'qtyUnits',
  );
  @override
  late final GeneratedColumn<int> qtyUnits = GeneratedColumn<int>(
    'qty_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InputUnit, int> unit =
      GeneratedColumn<int>(
        'unit',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<InputUnit>($AllocationLinesTable.$converterunit);
  static const VerificationMeta _piecesMeta = const VerificationMeta('pieces');
  @override
  late final GeneratedColumn<int> pieces = GeneratedColumn<int>(
    'pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exactCftNumMeta = const VerificationMeta(
    'exactCftNum',
  );
  @override
  late final GeneratedColumn<int> exactCftNum = GeneratedColumn<int>(
    'exact_cft_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exactCftDenMeta = const VerificationMeta(
    'exactCftDen',
  );
  @override
  late final GeneratedColumn<int> exactCftDen = GeneratedColumn<int>(
    'exact_cft_den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPartialMeta = const VerificationMeta(
    'isPartial',
  );
  @override
  late final GeneratedColumn<bool> isPartial = GeneratedColumn<bool>(
    'is_partial',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_partial" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _shortagePiecesMeta = const VerificationMeta(
    'shortagePieces',
  );
  @override
  late final GeneratedColumn<int> shortagePieces = GeneratedColumn<int>(
    'shortage_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftId,
    stockItemId,
    qtyUnits,
    unit,
    pieces,
    exactCftNum,
    exactCftDen,
    isPartial,
    shortagePieces,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('stock_item_id')) {
      context.handle(
        _stockItemIdMeta,
        stockItemId.isAcceptableOrUnknown(
          data['stock_item_id']!,
          _stockItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stockItemIdMeta);
    }
    if (data.containsKey('qty_units')) {
      context.handle(
        _qtyUnitsMeta,
        qtyUnits.isAcceptableOrUnknown(data['qty_units']!, _qtyUnitsMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyUnitsMeta);
    }
    if (data.containsKey('pieces')) {
      context.handle(
        _piecesMeta,
        pieces.isAcceptableOrUnknown(data['pieces']!, _piecesMeta),
      );
    } else if (isInserting) {
      context.missing(_piecesMeta);
    }
    if (data.containsKey('exact_cft_num')) {
      context.handle(
        _exactCftNumMeta,
        exactCftNum.isAcceptableOrUnknown(
          data['exact_cft_num']!,
          _exactCftNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exactCftNumMeta);
    }
    if (data.containsKey('exact_cft_den')) {
      context.handle(
        _exactCftDenMeta,
        exactCftDen.isAcceptableOrUnknown(
          data['exact_cft_den']!,
          _exactCftDenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exactCftDenMeta);
    }
    if (data.containsKey('is_partial')) {
      context.handle(
        _isPartialMeta,
        isPartial.isAcceptableOrUnknown(data['is_partial']!, _isPartialMeta),
      );
    }
    if (data.containsKey('shortage_pieces')) {
      context.handle(
        _shortagePiecesMeta,
        shortagePieces.isAcceptableOrUnknown(
          data['shortage_pieces']!,
          _shortagePiecesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AllocationLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}draft_id'],
      )!,
      stockItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_item_id'],
      )!,
      qtyUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty_units'],
      )!,
      unit: $AllocationLinesTable.$converterunit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}unit'],
        )!,
      ),
      pieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pieces'],
      )!,
      exactCftNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exact_cft_num'],
      )!,
      exactCftDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exact_cft_den'],
      )!,
      isPartial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_partial'],
      )!,
      shortagePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shortage_pieces'],
      )!,
    );
  }

  @override
  $AllocationLinesTable createAlias(String alias) {
    return $AllocationLinesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InputUnit, int, int> $converterunit =
      const EnumIndexConverter<InputUnit>(InputUnit.values);
}

class AllocationLineRow extends DataClass
    implements Insertable<AllocationLineRow> {
  /// Primary key.
  final int id;

  /// Owning draft.
  final int draftId;

  /// Source stock item.
  final int stockItemId;

  /// Allocated whole-unit count.
  final int qtyUnits;

  /// Bunch or piece.
  final InputUnit unit;

  /// Allocated pieces.
  final int pieces;

  /// Exact allocated CFT numerator.
  final int exactCftNum;

  /// Exact allocated CFT denominator.
  final int exactCftDen;

  /// Whether this line is a labelled partial.
  final bool isPartial;

  /// Shortage pieces when partial.
  final int shortagePieces;
  const AllocationLineRow({
    required this.id,
    required this.draftId,
    required this.stockItemId,
    required this.qtyUnits,
    required this.unit,
    required this.pieces,
    required this.exactCftNum,
    required this.exactCftDen,
    required this.isPartial,
    required this.shortagePieces,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['draft_id'] = Variable<int>(draftId);
    map['stock_item_id'] = Variable<int>(stockItemId);
    map['qty_units'] = Variable<int>(qtyUnits);
    {
      map['unit'] = Variable<int>(
        $AllocationLinesTable.$converterunit.toSql(unit),
      );
    }
    map['pieces'] = Variable<int>(pieces);
    map['exact_cft_num'] = Variable<int>(exactCftNum);
    map['exact_cft_den'] = Variable<int>(exactCftDen);
    map['is_partial'] = Variable<bool>(isPartial);
    map['shortage_pieces'] = Variable<int>(shortagePieces);
    return map;
  }

  AllocationLinesCompanion toCompanion(bool nullToAbsent) {
    return AllocationLinesCompanion(
      id: Value(id),
      draftId: Value(draftId),
      stockItemId: Value(stockItemId),
      qtyUnits: Value(qtyUnits),
      unit: Value(unit),
      pieces: Value(pieces),
      exactCftNum: Value(exactCftNum),
      exactCftDen: Value(exactCftDen),
      isPartial: Value(isPartial),
      shortagePieces: Value(shortagePieces),
    );
  }

  factory AllocationLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationLineRow(
      id: serializer.fromJson<int>(json['id']),
      draftId: serializer.fromJson<int>(json['draftId']),
      stockItemId: serializer.fromJson<int>(json['stockItemId']),
      qtyUnits: serializer.fromJson<int>(json['qtyUnits']),
      unit: $AllocationLinesTable.$converterunit.fromJson(
        serializer.fromJson<int>(json['unit']),
      ),
      pieces: serializer.fromJson<int>(json['pieces']),
      exactCftNum: serializer.fromJson<int>(json['exactCftNum']),
      exactCftDen: serializer.fromJson<int>(json['exactCftDen']),
      isPartial: serializer.fromJson<bool>(json['isPartial']),
      shortagePieces: serializer.fromJson<int>(json['shortagePieces']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'draftId': serializer.toJson<int>(draftId),
      'stockItemId': serializer.toJson<int>(stockItemId),
      'qtyUnits': serializer.toJson<int>(qtyUnits),
      'unit': serializer.toJson<int>(
        $AllocationLinesTable.$converterunit.toJson(unit),
      ),
      'pieces': serializer.toJson<int>(pieces),
      'exactCftNum': serializer.toJson<int>(exactCftNum),
      'exactCftDen': serializer.toJson<int>(exactCftDen),
      'isPartial': serializer.toJson<bool>(isPartial),
      'shortagePieces': serializer.toJson<int>(shortagePieces),
    };
  }

  AllocationLineRow copyWith({
    int? id,
    int? draftId,
    int? stockItemId,
    int? qtyUnits,
    InputUnit? unit,
    int? pieces,
    int? exactCftNum,
    int? exactCftDen,
    bool? isPartial,
    int? shortagePieces,
  }) => AllocationLineRow(
    id: id ?? this.id,
    draftId: draftId ?? this.draftId,
    stockItemId: stockItemId ?? this.stockItemId,
    qtyUnits: qtyUnits ?? this.qtyUnits,
    unit: unit ?? this.unit,
    pieces: pieces ?? this.pieces,
    exactCftNum: exactCftNum ?? this.exactCftNum,
    exactCftDen: exactCftDen ?? this.exactCftDen,
    isPartial: isPartial ?? this.isPartial,
    shortagePieces: shortagePieces ?? this.shortagePieces,
  );
  AllocationLineRow copyWithCompanion(AllocationLinesCompanion data) {
    return AllocationLineRow(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      stockItemId: data.stockItemId.present
          ? data.stockItemId.value
          : this.stockItemId,
      qtyUnits: data.qtyUnits.present ? data.qtyUnits.value : this.qtyUnits,
      unit: data.unit.present ? data.unit.value : this.unit,
      pieces: data.pieces.present ? data.pieces.value : this.pieces,
      exactCftNum: data.exactCftNum.present
          ? data.exactCftNum.value
          : this.exactCftNum,
      exactCftDen: data.exactCftDen.present
          ? data.exactCftDen.value
          : this.exactCftDen,
      isPartial: data.isPartial.present ? data.isPartial.value : this.isPartial,
      shortagePieces: data.shortagePieces.present
          ? data.shortagePieces.value
          : this.shortagePieces,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationLineRow(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('qtyUnits: $qtyUnits, ')
          ..write('unit: $unit, ')
          ..write('pieces: $pieces, ')
          ..write('exactCftNum: $exactCftNum, ')
          ..write('exactCftDen: $exactCftDen, ')
          ..write('isPartial: $isPartial, ')
          ..write('shortagePieces: $shortagePieces')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    draftId,
    stockItemId,
    qtyUnits,
    unit,
    pieces,
    exactCftNum,
    exactCftDen,
    isPartial,
    shortagePieces,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationLineRow &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.stockItemId == this.stockItemId &&
          other.qtyUnits == this.qtyUnits &&
          other.unit == this.unit &&
          other.pieces == this.pieces &&
          other.exactCftNum == this.exactCftNum &&
          other.exactCftDen == this.exactCftDen &&
          other.isPartial == this.isPartial &&
          other.shortagePieces == this.shortagePieces);
}

class AllocationLinesCompanion extends UpdateCompanion<AllocationLineRow> {
  final Value<int> id;
  final Value<int> draftId;
  final Value<int> stockItemId;
  final Value<int> qtyUnits;
  final Value<InputUnit> unit;
  final Value<int> pieces;
  final Value<int> exactCftNum;
  final Value<int> exactCftDen;
  final Value<bool> isPartial;
  final Value<int> shortagePieces;
  const AllocationLinesCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.stockItemId = const Value.absent(),
    this.qtyUnits = const Value.absent(),
    this.unit = const Value.absent(),
    this.pieces = const Value.absent(),
    this.exactCftNum = const Value.absent(),
    this.exactCftDen = const Value.absent(),
    this.isPartial = const Value.absent(),
    this.shortagePieces = const Value.absent(),
  });
  AllocationLinesCompanion.insert({
    this.id = const Value.absent(),
    required int draftId,
    required int stockItemId,
    required int qtyUnits,
    required InputUnit unit,
    required int pieces,
    required int exactCftNum,
    required int exactCftDen,
    this.isPartial = const Value.absent(),
    this.shortagePieces = const Value.absent(),
  }) : draftId = Value(draftId),
       stockItemId = Value(stockItemId),
       qtyUnits = Value(qtyUnits),
       unit = Value(unit),
       pieces = Value(pieces),
       exactCftNum = Value(exactCftNum),
       exactCftDen = Value(exactCftDen);
  static Insertable<AllocationLineRow> custom({
    Expression<int>? id,
    Expression<int>? draftId,
    Expression<int>? stockItemId,
    Expression<int>? qtyUnits,
    Expression<int>? unit,
    Expression<int>? pieces,
    Expression<int>? exactCftNum,
    Expression<int>? exactCftDen,
    Expression<bool>? isPartial,
    Expression<int>? shortagePieces,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (stockItemId != null) 'stock_item_id': stockItemId,
      if (qtyUnits != null) 'qty_units': qtyUnits,
      if (unit != null) 'unit': unit,
      if (pieces != null) 'pieces': pieces,
      if (exactCftNum != null) 'exact_cft_num': exactCftNum,
      if (exactCftDen != null) 'exact_cft_den': exactCftDen,
      if (isPartial != null) 'is_partial': isPartial,
      if (shortagePieces != null) 'shortage_pieces': shortagePieces,
    });
  }

  AllocationLinesCompanion copyWith({
    Value<int>? id,
    Value<int>? draftId,
    Value<int>? stockItemId,
    Value<int>? qtyUnits,
    Value<InputUnit>? unit,
    Value<int>? pieces,
    Value<int>? exactCftNum,
    Value<int>? exactCftDen,
    Value<bool>? isPartial,
    Value<int>? shortagePieces,
  }) {
    return AllocationLinesCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      stockItemId: stockItemId ?? this.stockItemId,
      qtyUnits: qtyUnits ?? this.qtyUnits,
      unit: unit ?? this.unit,
      pieces: pieces ?? this.pieces,
      exactCftNum: exactCftNum ?? this.exactCftNum,
      exactCftDen: exactCftDen ?? this.exactCftDen,
      isPartial: isPartial ?? this.isPartial,
      shortagePieces: shortagePieces ?? this.shortagePieces,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<int>(draftId.value);
    }
    if (stockItemId.present) {
      map['stock_item_id'] = Variable<int>(stockItemId.value);
    }
    if (qtyUnits.present) {
      map['qty_units'] = Variable<int>(qtyUnits.value);
    }
    if (unit.present) {
      map['unit'] = Variable<int>(
        $AllocationLinesTable.$converterunit.toSql(unit.value),
      );
    }
    if (pieces.present) {
      map['pieces'] = Variable<int>(pieces.value);
    }
    if (exactCftNum.present) {
      map['exact_cft_num'] = Variable<int>(exactCftNum.value);
    }
    if (exactCftDen.present) {
      map['exact_cft_den'] = Variable<int>(exactCftDen.value);
    }
    if (isPartial.present) {
      map['is_partial'] = Variable<bool>(isPartial.value);
    }
    if (shortagePieces.present) {
      map['shortage_pieces'] = Variable<int>(shortagePieces.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationLinesCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('qtyUnits: $qtyUnits, ')
          ..write('unit: $unit, ')
          ..write('pieces: $pieces, ')
          ..write('exactCftNum: $exactCftNum, ')
          ..write('exactCftDen: $exactCftDen, ')
          ..write('isPartial: $isPartial, ')
          ..write('shortagePieces: $shortagePieces')
          ..write(')'))
        .toString();
  }
}

class $InvoiceLinesTable extends InvoiceLines
    with TableInfo<$InvoiceLinesTable, InvoiceLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<int> invoiceId = GeneratedColumn<int>(
    'invoice_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id)',
    ),
  );
  static const VerificationMeta _varietyNameMeta = const VerificationMeta(
    'varietyName',
  );
  @override
  late final GeneratedColumn<String> varietyName = GeneratedColumn<String>(
    'variety_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _crossSectionLabelMeta = const VerificationMeta(
    'crossSectionLabel',
  );
  @override
  late final GeneratedColumn<String> crossSectionLabel =
      GeneratedColumn<String>(
        'cross_section_label',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lengthFtMeta = const VerificationMeta(
    'lengthFt',
  );
  @override
  late final GeneratedColumn<int> lengthFt = GeneratedColumn<int>(
    'length_ft',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _piecesMeta = const VerificationMeta('pieces');
  @override
  late final GeneratedColumn<int> pieces = GeneratedColumn<int>(
    'pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exactCftNumMeta = const VerificationMeta(
    'exactCftNum',
  );
  @override
  late final GeneratedColumn<int> exactCftNum = GeneratedColumn<int>(
    'exact_cft_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exactCftDenMeta = const VerificationMeta(
    'exactCftDen',
  );
  @override
  late final GeneratedColumn<int> exactCftDen = GeneratedColumn<int>(
    'exact_cft_den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateNumMeta = const VerificationMeta(
    'rateNum',
  );
  @override
  late final GeneratedColumn<int> rateNum = GeneratedColumn<int>(
    'rate_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateDenMeta = const VerificationMeta(
    'rateDen',
  );
  @override
  late final GeneratedColumn<int> rateDen = GeneratedColumn<int>(
    'rate_den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineAmountPaiseMeta = const VerificationMeta(
    'lineAmountPaise',
  );
  @override
  late final GeneratedColumn<int> lineAmountPaise = GeneratedColumn<int>(
    'line_amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    invoiceId,
    varietyName,
    crossSectionLabel,
    lengthFt,
    pieces,
    exactCftNum,
    exactCftDen,
    rateNum,
    rateDen,
    lineAmountPaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoice_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('variety_name')) {
      context.handle(
        _varietyNameMeta,
        varietyName.isAcceptableOrUnknown(
          data['variety_name']!,
          _varietyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_varietyNameMeta);
    }
    if (data.containsKey('cross_section_label')) {
      context.handle(
        _crossSectionLabelMeta,
        crossSectionLabel.isAcceptableOrUnknown(
          data['cross_section_label']!,
          _crossSectionLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_crossSectionLabelMeta);
    }
    if (data.containsKey('length_ft')) {
      context.handle(
        _lengthFtMeta,
        lengthFt.isAcceptableOrUnknown(data['length_ft']!, _lengthFtMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthFtMeta);
    }
    if (data.containsKey('pieces')) {
      context.handle(
        _piecesMeta,
        pieces.isAcceptableOrUnknown(data['pieces']!, _piecesMeta),
      );
    } else if (isInserting) {
      context.missing(_piecesMeta);
    }
    if (data.containsKey('exact_cft_num')) {
      context.handle(
        _exactCftNumMeta,
        exactCftNum.isAcceptableOrUnknown(
          data['exact_cft_num']!,
          _exactCftNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exactCftNumMeta);
    }
    if (data.containsKey('exact_cft_den')) {
      context.handle(
        _exactCftDenMeta,
        exactCftDen.isAcceptableOrUnknown(
          data['exact_cft_den']!,
          _exactCftDenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exactCftDenMeta);
    }
    if (data.containsKey('rate_num')) {
      context.handle(
        _rateNumMeta,
        rateNum.isAcceptableOrUnknown(data['rate_num']!, _rateNumMeta),
      );
    } else if (isInserting) {
      context.missing(_rateNumMeta);
    }
    if (data.containsKey('rate_den')) {
      context.handle(
        _rateDenMeta,
        rateDen.isAcceptableOrUnknown(data['rate_den']!, _rateDenMeta),
      );
    } else if (isInserting) {
      context.missing(_rateDenMeta);
    }
    if (data.containsKey('line_amount_paise')) {
      context.handle(
        _lineAmountPaiseMeta,
        lineAmountPaise.isAcceptableOrUnknown(
          data['line_amount_paise']!,
          _lineAmountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lineAmountPaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invoice_id'],
      )!,
      varietyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variety_name'],
      )!,
      crossSectionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cross_section_label'],
      )!,
      lengthFt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length_ft'],
      )!,
      pieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pieces'],
      )!,
      exactCftNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exact_cft_num'],
      )!,
      exactCftDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exact_cft_den'],
      )!,
      rateNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_num'],
      )!,
      rateDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_den'],
      )!,
      lineAmountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_amount_paise'],
      )!,
    );
  }

  @override
  $InvoiceLinesTable createAlias(String alias) {
    return $InvoiceLinesTable(attachedDatabase, alias);
  }
}

class InvoiceLineRow extends DataClass implements Insertable<InvoiceLineRow> {
  /// Primary key.
  final int id;

  /// Owning invoice — NOT NULL foreign key (no orphan lines).
  final int invoiceId;

  /// Variety name snapshot (as issued).
  final String varietyName;

  /// Cross-section label snapshot.
  final String crossSectionLabel;

  /// Length in feet.
  final int lengthFt;

  /// Pieces billed.
  final int pieces;

  /// Exact CFT numerator.
  final int exactCftNum;

  /// Exact CFT denominator.
  final int exactCftDen;

  /// Rate numerator snapshot.
  final int rateNum;

  /// Rate denominator snapshot.
  final int rateDen;

  /// Line amount in paise, rounded half-up.
  final int lineAmountPaise;
  const InvoiceLineRow({
    required this.id,
    required this.invoiceId,
    required this.varietyName,
    required this.crossSectionLabel,
    required this.lengthFt,
    required this.pieces,
    required this.exactCftNum,
    required this.exactCftDen,
    required this.rateNum,
    required this.rateDen,
    required this.lineAmountPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['invoice_id'] = Variable<int>(invoiceId);
    map['variety_name'] = Variable<String>(varietyName);
    map['cross_section_label'] = Variable<String>(crossSectionLabel);
    map['length_ft'] = Variable<int>(lengthFt);
    map['pieces'] = Variable<int>(pieces);
    map['exact_cft_num'] = Variable<int>(exactCftNum);
    map['exact_cft_den'] = Variable<int>(exactCftDen);
    map['rate_num'] = Variable<int>(rateNum);
    map['rate_den'] = Variable<int>(rateDen);
    map['line_amount_paise'] = Variable<int>(lineAmountPaise);
    return map;
  }

  InvoiceLinesCompanion toCompanion(bool nullToAbsent) {
    return InvoiceLinesCompanion(
      id: Value(id),
      invoiceId: Value(invoiceId),
      varietyName: Value(varietyName),
      crossSectionLabel: Value(crossSectionLabel),
      lengthFt: Value(lengthFt),
      pieces: Value(pieces),
      exactCftNum: Value(exactCftNum),
      exactCftDen: Value(exactCftDen),
      rateNum: Value(rateNum),
      rateDen: Value(rateDen),
      lineAmountPaise: Value(lineAmountPaise),
    );
  }

  factory InvoiceLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceLineRow(
      id: serializer.fromJson<int>(json['id']),
      invoiceId: serializer.fromJson<int>(json['invoiceId']),
      varietyName: serializer.fromJson<String>(json['varietyName']),
      crossSectionLabel: serializer.fromJson<String>(json['crossSectionLabel']),
      lengthFt: serializer.fromJson<int>(json['lengthFt']),
      pieces: serializer.fromJson<int>(json['pieces']),
      exactCftNum: serializer.fromJson<int>(json['exactCftNum']),
      exactCftDen: serializer.fromJson<int>(json['exactCftDen']),
      rateNum: serializer.fromJson<int>(json['rateNum']),
      rateDen: serializer.fromJson<int>(json['rateDen']),
      lineAmountPaise: serializer.fromJson<int>(json['lineAmountPaise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'invoiceId': serializer.toJson<int>(invoiceId),
      'varietyName': serializer.toJson<String>(varietyName),
      'crossSectionLabel': serializer.toJson<String>(crossSectionLabel),
      'lengthFt': serializer.toJson<int>(lengthFt),
      'pieces': serializer.toJson<int>(pieces),
      'exactCftNum': serializer.toJson<int>(exactCftNum),
      'exactCftDen': serializer.toJson<int>(exactCftDen),
      'rateNum': serializer.toJson<int>(rateNum),
      'rateDen': serializer.toJson<int>(rateDen),
      'lineAmountPaise': serializer.toJson<int>(lineAmountPaise),
    };
  }

  InvoiceLineRow copyWith({
    int? id,
    int? invoiceId,
    String? varietyName,
    String? crossSectionLabel,
    int? lengthFt,
    int? pieces,
    int? exactCftNum,
    int? exactCftDen,
    int? rateNum,
    int? rateDen,
    int? lineAmountPaise,
  }) => InvoiceLineRow(
    id: id ?? this.id,
    invoiceId: invoiceId ?? this.invoiceId,
    varietyName: varietyName ?? this.varietyName,
    crossSectionLabel: crossSectionLabel ?? this.crossSectionLabel,
    lengthFt: lengthFt ?? this.lengthFt,
    pieces: pieces ?? this.pieces,
    exactCftNum: exactCftNum ?? this.exactCftNum,
    exactCftDen: exactCftDen ?? this.exactCftDen,
    rateNum: rateNum ?? this.rateNum,
    rateDen: rateDen ?? this.rateDen,
    lineAmountPaise: lineAmountPaise ?? this.lineAmountPaise,
  );
  InvoiceLineRow copyWithCompanion(InvoiceLinesCompanion data) {
    return InvoiceLineRow(
      id: data.id.present ? data.id.value : this.id,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      varietyName: data.varietyName.present
          ? data.varietyName.value
          : this.varietyName,
      crossSectionLabel: data.crossSectionLabel.present
          ? data.crossSectionLabel.value
          : this.crossSectionLabel,
      lengthFt: data.lengthFt.present ? data.lengthFt.value : this.lengthFt,
      pieces: data.pieces.present ? data.pieces.value : this.pieces,
      exactCftNum: data.exactCftNum.present
          ? data.exactCftNum.value
          : this.exactCftNum,
      exactCftDen: data.exactCftDen.present
          ? data.exactCftDen.value
          : this.exactCftDen,
      rateNum: data.rateNum.present ? data.rateNum.value : this.rateNum,
      rateDen: data.rateDen.present ? data.rateDen.value : this.rateDen,
      lineAmountPaise: data.lineAmountPaise.present
          ? data.lineAmountPaise.value
          : this.lineAmountPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceLineRow(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('varietyName: $varietyName, ')
          ..write('crossSectionLabel: $crossSectionLabel, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('pieces: $pieces, ')
          ..write('exactCftNum: $exactCftNum, ')
          ..write('exactCftDen: $exactCftDen, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen, ')
          ..write('lineAmountPaise: $lineAmountPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    invoiceId,
    varietyName,
    crossSectionLabel,
    lengthFt,
    pieces,
    exactCftNum,
    exactCftDen,
    rateNum,
    rateDen,
    lineAmountPaise,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceLineRow &&
          other.id == this.id &&
          other.invoiceId == this.invoiceId &&
          other.varietyName == this.varietyName &&
          other.crossSectionLabel == this.crossSectionLabel &&
          other.lengthFt == this.lengthFt &&
          other.pieces == this.pieces &&
          other.exactCftNum == this.exactCftNum &&
          other.exactCftDen == this.exactCftDen &&
          other.rateNum == this.rateNum &&
          other.rateDen == this.rateDen &&
          other.lineAmountPaise == this.lineAmountPaise);
}

class InvoiceLinesCompanion extends UpdateCompanion<InvoiceLineRow> {
  final Value<int> id;
  final Value<int> invoiceId;
  final Value<String> varietyName;
  final Value<String> crossSectionLabel;
  final Value<int> lengthFt;
  final Value<int> pieces;
  final Value<int> exactCftNum;
  final Value<int> exactCftDen;
  final Value<int> rateNum;
  final Value<int> rateDen;
  final Value<int> lineAmountPaise;
  const InvoiceLinesCompanion({
    this.id = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.varietyName = const Value.absent(),
    this.crossSectionLabel = const Value.absent(),
    this.lengthFt = const Value.absent(),
    this.pieces = const Value.absent(),
    this.exactCftNum = const Value.absent(),
    this.exactCftDen = const Value.absent(),
    this.rateNum = const Value.absent(),
    this.rateDen = const Value.absent(),
    this.lineAmountPaise = const Value.absent(),
  });
  InvoiceLinesCompanion.insert({
    this.id = const Value.absent(),
    required int invoiceId,
    required String varietyName,
    required String crossSectionLabel,
    required int lengthFt,
    required int pieces,
    required int exactCftNum,
    required int exactCftDen,
    required int rateNum,
    required int rateDen,
    required int lineAmountPaise,
  }) : invoiceId = Value(invoiceId),
       varietyName = Value(varietyName),
       crossSectionLabel = Value(crossSectionLabel),
       lengthFt = Value(lengthFt),
       pieces = Value(pieces),
       exactCftNum = Value(exactCftNum),
       exactCftDen = Value(exactCftDen),
       rateNum = Value(rateNum),
       rateDen = Value(rateDen),
       lineAmountPaise = Value(lineAmountPaise);
  static Insertable<InvoiceLineRow> custom({
    Expression<int>? id,
    Expression<int>? invoiceId,
    Expression<String>? varietyName,
    Expression<String>? crossSectionLabel,
    Expression<int>? lengthFt,
    Expression<int>? pieces,
    Expression<int>? exactCftNum,
    Expression<int>? exactCftDen,
    Expression<int>? rateNum,
    Expression<int>? rateDen,
    Expression<int>? lineAmountPaise,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (varietyName != null) 'variety_name': varietyName,
      if (crossSectionLabel != null) 'cross_section_label': crossSectionLabel,
      if (lengthFt != null) 'length_ft': lengthFt,
      if (pieces != null) 'pieces': pieces,
      if (exactCftNum != null) 'exact_cft_num': exactCftNum,
      if (exactCftDen != null) 'exact_cft_den': exactCftDen,
      if (rateNum != null) 'rate_num': rateNum,
      if (rateDen != null) 'rate_den': rateDen,
      if (lineAmountPaise != null) 'line_amount_paise': lineAmountPaise,
    });
  }

  InvoiceLinesCompanion copyWith({
    Value<int>? id,
    Value<int>? invoiceId,
    Value<String>? varietyName,
    Value<String>? crossSectionLabel,
    Value<int>? lengthFt,
    Value<int>? pieces,
    Value<int>? exactCftNum,
    Value<int>? exactCftDen,
    Value<int>? rateNum,
    Value<int>? rateDen,
    Value<int>? lineAmountPaise,
  }) {
    return InvoiceLinesCompanion(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      varietyName: varietyName ?? this.varietyName,
      crossSectionLabel: crossSectionLabel ?? this.crossSectionLabel,
      lengthFt: lengthFt ?? this.lengthFt,
      pieces: pieces ?? this.pieces,
      exactCftNum: exactCftNum ?? this.exactCftNum,
      exactCftDen: exactCftDen ?? this.exactCftDen,
      rateNum: rateNum ?? this.rateNum,
      rateDen: rateDen ?? this.rateDen,
      lineAmountPaise: lineAmountPaise ?? this.lineAmountPaise,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<int>(invoiceId.value);
    }
    if (varietyName.present) {
      map['variety_name'] = Variable<String>(varietyName.value);
    }
    if (crossSectionLabel.present) {
      map['cross_section_label'] = Variable<String>(crossSectionLabel.value);
    }
    if (lengthFt.present) {
      map['length_ft'] = Variable<int>(lengthFt.value);
    }
    if (pieces.present) {
      map['pieces'] = Variable<int>(pieces.value);
    }
    if (exactCftNum.present) {
      map['exact_cft_num'] = Variable<int>(exactCftNum.value);
    }
    if (exactCftDen.present) {
      map['exact_cft_den'] = Variable<int>(exactCftDen.value);
    }
    if (rateNum.present) {
      map['rate_num'] = Variable<int>(rateNum.value);
    }
    if (rateDen.present) {
      map['rate_den'] = Variable<int>(rateDen.value);
    }
    if (lineAmountPaise.present) {
      map['line_amount_paise'] = Variable<int>(lineAmountPaise.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceLinesCompanion(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('varietyName: $varietyName, ')
          ..write('crossSectionLabel: $crossSectionLabel, ')
          ..write('lengthFt: $lengthFt, ')
          ..write('pieces: $pieces, ')
          ..write('exactCftNum: $exactCftNum, ')
          ..write('exactCftDen: $exactCftDen, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen, ')
          ..write('lineAmountPaise: $lineAmountPaise')
          ..write(')'))
        .toString();
  }
}

class $BusinessSettingsTable extends BusinessSettings
    with TableInfo<$BusinessSettingsTable, BusinessSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _logoMeta = const VerificationMeta('logo');
  @override
  late final GeneratedColumn<Uint8List> logo = GeneratedColumn<Uint8List>(
    'logo',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
    'gstin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoicePrefixMeta = const VerificationMeta(
    'invoicePrefix',
  );
  @override
  late final GeneratedColumn<String> invoicePrefix = GeneratedColumn<String>(
    'invoice_prefix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    address,
    phone,
    logo,
    gstin,
    invoicePrefix,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('logo')) {
      context.handle(
        _logoMeta,
        logo.isAcceptableOrUnknown(data['logo']!, _logoMeta),
      );
    }
    if (data.containsKey('gstin')) {
      context.handle(
        _gstinMeta,
        gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta),
      );
    }
    if (data.containsKey('invoice_prefix')) {
      context.handle(
        _invoicePrefixMeta,
        invoicePrefix.isAcceptableOrUnknown(
          data['invoice_prefix']!,
          _invoicePrefixMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      logo: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}logo'],
      ),
      gstin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gstin'],
      ),
      invoicePrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_prefix'],
      )!,
    );
  }

  @override
  $BusinessSettingsTable createAlias(String alias) {
    return $BusinessSettingsTable(attachedDatabase, alias);
  }
}

class BusinessSettingsRow extends DataClass
    implements Insertable<BusinessSettingsRow> {
  /// Singleton primary key (always 1).
  final int id;

  /// Business name.
  final String name;

  /// Business address.
  final String address;

  /// Business phone.
  final String phone;

  /// Optional logo bytes.
  final Uint8List? logo;

  /// Optional GSTIN.
  final String? gstin;

  /// Invoice number prefix.
  final String invoicePrefix;
  const BusinessSettingsRow({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.logo,
    this.gstin,
    required this.invoicePrefix,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || logo != null) {
      map['logo'] = Variable<Uint8List>(logo);
    }
    if (!nullToAbsent || gstin != null) {
      map['gstin'] = Variable<String>(gstin);
    }
    map['invoice_prefix'] = Variable<String>(invoicePrefix);
    return map;
  }

  BusinessSettingsCompanion toCompanion(bool nullToAbsent) {
    return BusinessSettingsCompanion(
      id: Value(id),
      name: Value(name),
      address: Value(address),
      phone: Value(phone),
      logo: logo == null && nullToAbsent ? const Value.absent() : Value(logo),
      gstin: gstin == null && nullToAbsent
          ? const Value.absent()
          : Value(gstin),
      invoicePrefix: Value(invoicePrefix),
    );
  }

  factory BusinessSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      phone: serializer.fromJson<String>(json['phone']),
      logo: serializer.fromJson<Uint8List?>(json['logo']),
      gstin: serializer.fromJson<String?>(json['gstin']),
      invoicePrefix: serializer.fromJson<String>(json['invoicePrefix']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'phone': serializer.toJson<String>(phone),
      'logo': serializer.toJson<Uint8List?>(logo),
      'gstin': serializer.toJson<String?>(gstin),
      'invoicePrefix': serializer.toJson<String>(invoicePrefix),
    };
  }

  BusinessSettingsRow copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    Value<Uint8List?> logo = const Value.absent(),
    Value<String?> gstin = const Value.absent(),
    String? invoicePrefix,
  }) => BusinessSettingsRow(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    logo: logo.present ? logo.value : this.logo,
    gstin: gstin.present ? gstin.value : this.gstin,
    invoicePrefix: invoicePrefix ?? this.invoicePrefix,
  );
  BusinessSettingsRow copyWithCompanion(BusinessSettingsCompanion data) {
    return BusinessSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      logo: data.logo.present ? data.logo.value : this.logo,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      invoicePrefix: data.invoicePrefix.present
          ? data.invoicePrefix.value
          : this.invoicePrefix,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSettingsRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('logo: $logo, ')
          ..write('gstin: $gstin, ')
          ..write('invoicePrefix: $invoicePrefix')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    address,
    phone,
    $driftBlobEquality.hash(logo),
    gstin,
    invoicePrefix,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessSettingsRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.phone == this.phone &&
          $driftBlobEquality.equals(other.logo, this.logo) &&
          other.gstin == this.gstin &&
          other.invoicePrefix == this.invoicePrefix);
}

class BusinessSettingsCompanion extends UpdateCompanion<BusinessSettingsRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> address;
  final Value<String> phone;
  final Value<Uint8List?> logo;
  final Value<String?> gstin;
  final Value<String> invoicePrefix;
  const BusinessSettingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.logo = const Value.absent(),
    this.gstin = const Value.absent(),
    this.invoicePrefix = const Value.absent(),
  });
  BusinessSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.logo = const Value.absent(),
    this.gstin = const Value.absent(),
    this.invoicePrefix = const Value.absent(),
  });
  static Insertable<BusinessSettingsRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<Uint8List>? logo,
    Expression<String>? gstin,
    Expression<String>? invoicePrefix,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (logo != null) 'logo': logo,
      if (gstin != null) 'gstin': gstin,
      if (invoicePrefix != null) 'invoice_prefix': invoicePrefix,
    });
  }

  BusinessSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? address,
    Value<String>? phone,
    Value<Uint8List?>? logo,
    Value<String?>? gstin,
    Value<String>? invoicePrefix,
  }) {
    return BusinessSettingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logo: logo ?? this.logo,
      gstin: gstin ?? this.gstin,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
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
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (logo.present) {
      map['logo'] = Variable<Uint8List>(logo.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (invoicePrefix.present) {
      map['invoice_prefix'] = Variable<String>(invoicePrefix.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSettingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('logo: $logo, ')
          ..write('gstin: $gstin, ')
          ..write('invoicePrefix: $invoicePrefix')
          ..write(')'))
        .toString();
  }
}

class $AllocationPoliciesTable extends AllocationPolicies
    with TableInfo<$AllocationPoliciesTable, AllocationPolicyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllocationPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _allow89ftFallbackMeta = const VerificationMeta(
    'allow89ftFallback',
  );
  @override
  late final GeneratedColumn<bool> allow89ftFallback = GeneratedColumn<bool>(
    'allow89ft_fallback',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow89ft_fallback" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reaperSharePreferredMeta =
      const VerificationMeta('reaperSharePreferred');
  @override
  late final GeneratedColumn<int> reaperSharePreferred = GeneratedColumn<int>(
    'reaper_share_preferred',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _reaperShareMidMeta = const VerificationMeta(
    'reaperShareMid',
  );
  @override
  late final GeneratedColumn<int> reaperShareMid = GeneratedColumn<int>(
    'reaper_share_mid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _reaperShareLowMeta = const VerificationMeta(
    'reaperShareLow',
  );
  @override
  late final GeneratedColumn<int> reaperShareLow = GeneratedColumn<int>(
    'reaper_share_low',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    allow89ftFallback,
    reaperSharePreferred,
    reaperShareMid,
    reaperShareLow,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationPolicyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('allow89ft_fallback')) {
      context.handle(
        _allow89ftFallbackMeta,
        allow89ftFallback.isAcceptableOrUnknown(
          data['allow89ft_fallback']!,
          _allow89ftFallbackMeta,
        ),
      );
    }
    if (data.containsKey('reaper_share_preferred')) {
      context.handle(
        _reaperSharePreferredMeta,
        reaperSharePreferred.isAcceptableOrUnknown(
          data['reaper_share_preferred']!,
          _reaperSharePreferredMeta,
        ),
      );
    }
    if (data.containsKey('reaper_share_mid')) {
      context.handle(
        _reaperShareMidMeta,
        reaperShareMid.isAcceptableOrUnknown(
          data['reaper_share_mid']!,
          _reaperShareMidMeta,
        ),
      );
    }
    if (data.containsKey('reaper_share_low')) {
      context.handle(
        _reaperShareLowMeta,
        reaperShareLow.isAcceptableOrUnknown(
          data['reaper_share_low']!,
          _reaperShareLowMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AllocationPolicyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationPolicyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      allow89ftFallback: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow89ft_fallback'],
      )!,
      reaperSharePreferred: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reaper_share_preferred'],
      )!,
      reaperShareMid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reaper_share_mid'],
      )!,
      reaperShareLow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reaper_share_low'],
      )!,
    );
  }

  @override
  $AllocationPoliciesTable createAlias(String alias) {
    return $AllocationPoliciesTable(attachedDatabase, alias);
  }
}

class AllocationPolicyRow extends DataClass
    implements Insertable<AllocationPolicyRow> {
  /// Singleton primary key (always 1).
  final int id;

  /// Whether 8-9 ft fallback is allowed in flexible allocation.
  final bool allow89ftFallback;

  /// Reaper preferred-group share percent ({6,7}).
  final int reaperSharePreferred;

  /// Reaper mid-group share percent ({3,4,5}).
  final int reaperShareMid;

  /// Reaper low-group share percent ({2}).
  final int reaperShareLow;
  const AllocationPolicyRow({
    required this.id,
    required this.allow89ftFallback,
    required this.reaperSharePreferred,
    required this.reaperShareMid,
    required this.reaperShareLow,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['allow89ft_fallback'] = Variable<bool>(allow89ftFallback);
    map['reaper_share_preferred'] = Variable<int>(reaperSharePreferred);
    map['reaper_share_mid'] = Variable<int>(reaperShareMid);
    map['reaper_share_low'] = Variable<int>(reaperShareLow);
    return map;
  }

  AllocationPoliciesCompanion toCompanion(bool nullToAbsent) {
    return AllocationPoliciesCompanion(
      id: Value(id),
      allow89ftFallback: Value(allow89ftFallback),
      reaperSharePreferred: Value(reaperSharePreferred),
      reaperShareMid: Value(reaperShareMid),
      reaperShareLow: Value(reaperShareLow),
    );
  }

  factory AllocationPolicyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationPolicyRow(
      id: serializer.fromJson<int>(json['id']),
      allow89ftFallback: serializer.fromJson<bool>(json['allow89ftFallback']),
      reaperSharePreferred: serializer.fromJson<int>(
        json['reaperSharePreferred'],
      ),
      reaperShareMid: serializer.fromJson<int>(json['reaperShareMid']),
      reaperShareLow: serializer.fromJson<int>(json['reaperShareLow']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'allow89ftFallback': serializer.toJson<bool>(allow89ftFallback),
      'reaperSharePreferred': serializer.toJson<int>(reaperSharePreferred),
      'reaperShareMid': serializer.toJson<int>(reaperShareMid),
      'reaperShareLow': serializer.toJson<int>(reaperShareLow),
    };
  }

  AllocationPolicyRow copyWith({
    int? id,
    bool? allow89ftFallback,
    int? reaperSharePreferred,
    int? reaperShareMid,
    int? reaperShareLow,
  }) => AllocationPolicyRow(
    id: id ?? this.id,
    allow89ftFallback: allow89ftFallback ?? this.allow89ftFallback,
    reaperSharePreferred: reaperSharePreferred ?? this.reaperSharePreferred,
    reaperShareMid: reaperShareMid ?? this.reaperShareMid,
    reaperShareLow: reaperShareLow ?? this.reaperShareLow,
  );
  AllocationPolicyRow copyWithCompanion(AllocationPoliciesCompanion data) {
    return AllocationPolicyRow(
      id: data.id.present ? data.id.value : this.id,
      allow89ftFallback: data.allow89ftFallback.present
          ? data.allow89ftFallback.value
          : this.allow89ftFallback,
      reaperSharePreferred: data.reaperSharePreferred.present
          ? data.reaperSharePreferred.value
          : this.reaperSharePreferred,
      reaperShareMid: data.reaperShareMid.present
          ? data.reaperShareMid.value
          : this.reaperShareMid,
      reaperShareLow: data.reaperShareLow.present
          ? data.reaperShareLow.value
          : this.reaperShareLow,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationPolicyRow(')
          ..write('id: $id, ')
          ..write('allow89ftFallback: $allow89ftFallback, ')
          ..write('reaperSharePreferred: $reaperSharePreferred, ')
          ..write('reaperShareMid: $reaperShareMid, ')
          ..write('reaperShareLow: $reaperShareLow')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    allow89ftFallback,
    reaperSharePreferred,
    reaperShareMid,
    reaperShareLow,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationPolicyRow &&
          other.id == this.id &&
          other.allow89ftFallback == this.allow89ftFallback &&
          other.reaperSharePreferred == this.reaperSharePreferred &&
          other.reaperShareMid == this.reaperShareMid &&
          other.reaperShareLow == this.reaperShareLow);
}

class AllocationPoliciesCompanion extends UpdateCompanion<AllocationPolicyRow> {
  final Value<int> id;
  final Value<bool> allow89ftFallback;
  final Value<int> reaperSharePreferred;
  final Value<int> reaperShareMid;
  final Value<int> reaperShareLow;
  const AllocationPoliciesCompanion({
    this.id = const Value.absent(),
    this.allow89ftFallback = const Value.absent(),
    this.reaperSharePreferred = const Value.absent(),
    this.reaperShareMid = const Value.absent(),
    this.reaperShareLow = const Value.absent(),
  });
  AllocationPoliciesCompanion.insert({
    this.id = const Value.absent(),
    this.allow89ftFallback = const Value.absent(),
    this.reaperSharePreferred = const Value.absent(),
    this.reaperShareMid = const Value.absent(),
    this.reaperShareLow = const Value.absent(),
  });
  static Insertable<AllocationPolicyRow> custom({
    Expression<int>? id,
    Expression<bool>? allow89ftFallback,
    Expression<int>? reaperSharePreferred,
    Expression<int>? reaperShareMid,
    Expression<int>? reaperShareLow,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (allow89ftFallback != null) 'allow89ft_fallback': allow89ftFallback,
      if (reaperSharePreferred != null)
        'reaper_share_preferred': reaperSharePreferred,
      if (reaperShareMid != null) 'reaper_share_mid': reaperShareMid,
      if (reaperShareLow != null) 'reaper_share_low': reaperShareLow,
    });
  }

  AllocationPoliciesCompanion copyWith({
    Value<int>? id,
    Value<bool>? allow89ftFallback,
    Value<int>? reaperSharePreferred,
    Value<int>? reaperShareMid,
    Value<int>? reaperShareLow,
  }) {
    return AllocationPoliciesCompanion(
      id: id ?? this.id,
      allow89ftFallback: allow89ftFallback ?? this.allow89ftFallback,
      reaperSharePreferred: reaperSharePreferred ?? this.reaperSharePreferred,
      reaperShareMid: reaperShareMid ?? this.reaperShareMid,
      reaperShareLow: reaperShareLow ?? this.reaperShareLow,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (allow89ftFallback.present) {
      map['allow89ft_fallback'] = Variable<bool>(allow89ftFallback.value);
    }
    if (reaperSharePreferred.present) {
      map['reaper_share_preferred'] = Variable<int>(reaperSharePreferred.value);
    }
    if (reaperShareMid.present) {
      map['reaper_share_mid'] = Variable<int>(reaperShareMid.value);
    }
    if (reaperShareLow.present) {
      map['reaper_share_low'] = Variable<int>(reaperShareLow.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationPoliciesCompanion(')
          ..write('id: $id, ')
          ..write('allow89ftFallback: $allow89ftFallback, ')
          ..write('reaperSharePreferred: $reaperSharePreferred, ')
          ..write('reaperShareMid: $reaperShareMid, ')
          ..write('reaperShareLow: $reaperShareLow')
          ..write(')'))
        .toString();
  }
}

class $TaxPoliciesTable extends TaxPolicies
    with TableInfo<$TaxPoliciesTable, TaxPolicyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaxPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaxMode, int> mode =
      GeneratedColumn<int>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TaxMode>($TaxPoliciesTable.$convertermode);
  static const VerificationMeta _rateNumMeta = const VerificationMeta(
    'rateNum',
  );
  @override
  late final GeneratedColumn<int> rateNum = GeneratedColumn<int>(
    'rate_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rateDenMeta = const VerificationMeta(
    'rateDen',
  );
  @override
  late final GeneratedColumn<int> rateDen = GeneratedColumn<int>(
    'rate_den',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('No GST'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, mode, rateNum, rateDen, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tax_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaxPolicyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rate_num')) {
      context.handle(
        _rateNumMeta,
        rateNum.isAcceptableOrUnknown(data['rate_num']!, _rateNumMeta),
      );
    }
    if (data.containsKey('rate_den')) {
      context.handle(
        _rateDenMeta,
        rateDen.isAcceptableOrUnknown(data['rate_den']!, _rateDenMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaxPolicyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaxPolicyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mode: $TaxPoliciesTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}mode'],
        )!,
      ),
      rateNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_num'],
      )!,
      rateDen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_den'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $TaxPoliciesTable createAlias(String alias) {
    return $TaxPoliciesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaxMode, int, int> $convertermode =
      const EnumIndexConverter<TaxMode>(TaxMode.values);
}

class TaxPolicyRow extends DataClass implements Insertable<TaxPolicyRow> {
  /// Singleton primary key (always 1).
  final int id;

  /// No GST / 9% / 18%.
  final TaxMode mode;

  /// Rate numerator.
  final int rateNum;

  /// Rate denominator.
  final int rateDen;

  /// Display label.
  final String label;
  const TaxPolicyRow({
    required this.id,
    required this.mode,
    required this.rateNum,
    required this.rateDen,
    required this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['mode'] = Variable<int>($TaxPoliciesTable.$convertermode.toSql(mode));
    }
    map['rate_num'] = Variable<int>(rateNum);
    map['rate_den'] = Variable<int>(rateDen);
    map['label'] = Variable<String>(label);
    return map;
  }

  TaxPoliciesCompanion toCompanion(bool nullToAbsent) {
    return TaxPoliciesCompanion(
      id: Value(id),
      mode: Value(mode),
      rateNum: Value(rateNum),
      rateDen: Value(rateDen),
      label: Value(label),
    );
  }

  factory TaxPolicyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaxPolicyRow(
      id: serializer.fromJson<int>(json['id']),
      mode: $TaxPoliciesTable.$convertermode.fromJson(
        serializer.fromJson<int>(json['mode']),
      ),
      rateNum: serializer.fromJson<int>(json['rateNum']),
      rateDen: serializer.fromJson<int>(json['rateDen']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode': serializer.toJson<int>(
        $TaxPoliciesTable.$convertermode.toJson(mode),
      ),
      'rateNum': serializer.toJson<int>(rateNum),
      'rateDen': serializer.toJson<int>(rateDen),
      'label': serializer.toJson<String>(label),
    };
  }

  TaxPolicyRow copyWith({
    int? id,
    TaxMode? mode,
    int? rateNum,
    int? rateDen,
    String? label,
  }) => TaxPolicyRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    rateNum: rateNum ?? this.rateNum,
    rateDen: rateDen ?? this.rateDen,
    label: label ?? this.label,
  );
  TaxPolicyRow copyWithCompanion(TaxPoliciesCompanion data) {
    return TaxPolicyRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      rateNum: data.rateNum.present ? data.rateNum.value : this.rateNum,
      rateDen: data.rateDen.present ? data.rateDen.value : this.rateDen,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaxPolicyRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mode, rateNum, rateDen, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaxPolicyRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.rateNum == this.rateNum &&
          other.rateDen == this.rateDen &&
          other.label == this.label);
}

class TaxPoliciesCompanion extends UpdateCompanion<TaxPolicyRow> {
  final Value<int> id;
  final Value<TaxMode> mode;
  final Value<int> rateNum;
  final Value<int> rateDen;
  final Value<String> label;
  const TaxPoliciesCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.rateNum = const Value.absent(),
    this.rateDen = const Value.absent(),
    this.label = const Value.absent(),
  });
  TaxPoliciesCompanion.insert({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.rateNum = const Value.absent(),
    this.rateDen = const Value.absent(),
    this.label = const Value.absent(),
  });
  static Insertable<TaxPolicyRow> custom({
    Expression<int>? id,
    Expression<int>? mode,
    Expression<int>? rateNum,
    Expression<int>? rateDen,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (rateNum != null) 'rate_num': rateNum,
      if (rateDen != null) 'rate_den': rateDen,
      if (label != null) 'label': label,
    });
  }

  TaxPoliciesCompanion copyWith({
    Value<int>? id,
    Value<TaxMode>? mode,
    Value<int>? rateNum,
    Value<int>? rateDen,
    Value<String>? label,
  }) {
    return TaxPoliciesCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      rateNum: rateNum ?? this.rateNum,
      rateDen: rateDen ?? this.rateDen,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(
        $TaxPoliciesTable.$convertermode.toSql(mode.value),
      );
    }
    if (rateNum.present) {
      map['rate_num'] = Variable<int>(rateNum.value);
    }
    if (rateDen.present) {
      map['rate_den'] = Variable<int>(rateDen.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaxPoliciesCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('rateNum: $rateNum, ')
          ..write('rateDen: $rateDen, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $LoadingPoliciesTable extends LoadingPolicies
    with TableInfo<$LoadingPoliciesTable, LoadingPolicyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoadingPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lowPaiseMeta = const VerificationMeta(
    'lowPaise',
  );
  @override
  late final GeneratedColumn<int> lowPaise = GeneratedColumn<int>(
    'low_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10000),
  );
  static const VerificationMeta _highPaiseMeta = const VerificationMeta(
    'highPaise',
  );
  @override
  late final GeneratedColumn<int> highPaise = GeneratedColumn<int>(
    'high_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(15000),
  );
  static const VerificationMeta _thresholdCftMeta = const VerificationMeta(
    'thresholdCft',
  );
  @override
  late final GeneratedColumn<int> thresholdCft = GeneratedColumn<int>(
    'threshold_cft',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _thresholdInclusiveMeta =
      const VerificationMeta('thresholdInclusive');
  @override
  late final GeneratedColumn<bool> thresholdInclusive = GeneratedColumn<bool>(
    'threshold_inclusive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("threshold_inclusive" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lowPaise,
    highPaise,
    thresholdCft,
    thresholdInclusive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loading_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoadingPolicyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('low_paise')) {
      context.handle(
        _lowPaiseMeta,
        lowPaise.isAcceptableOrUnknown(data['low_paise']!, _lowPaiseMeta),
      );
    }
    if (data.containsKey('high_paise')) {
      context.handle(
        _highPaiseMeta,
        highPaise.isAcceptableOrUnknown(data['high_paise']!, _highPaiseMeta),
      );
    }
    if (data.containsKey('threshold_cft')) {
      context.handle(
        _thresholdCftMeta,
        thresholdCft.isAcceptableOrUnknown(
          data['threshold_cft']!,
          _thresholdCftMeta,
        ),
      );
    }
    if (data.containsKey('threshold_inclusive')) {
      context.handle(
        _thresholdInclusiveMeta,
        thresholdInclusive.isAcceptableOrUnknown(
          data['threshold_inclusive']!,
          _thresholdInclusiveMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoadingPolicyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoadingPolicyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lowPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}low_paise'],
      )!,
      highPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}high_paise'],
      )!,
      thresholdCft: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threshold_cft'],
      )!,
      thresholdInclusive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}threshold_inclusive'],
      )!,
    );
  }

  @override
  $LoadingPoliciesTable createAlias(String alias) {
    return $LoadingPoliciesTable(attachedDatabase, alias);
  }
}

class LoadingPolicyRow extends DataClass
    implements Insertable<LoadingPolicyRow> {
  /// Singleton primary key (always 1).
  final int id;

  /// Low-tier loading charge in paise (default 10000 = Rs 100).
  final int lowPaise;

  /// High-tier loading charge in paise (default 15000 = Rs 150).
  final int highPaise;

  /// CFT threshold between tiers (default 20).
  final int thresholdCft;

  /// Whether the threshold itself counts as high tier (default true).
  final bool thresholdInclusive;
  const LoadingPolicyRow({
    required this.id,
    required this.lowPaise,
    required this.highPaise,
    required this.thresholdCft,
    required this.thresholdInclusive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['low_paise'] = Variable<int>(lowPaise);
    map['high_paise'] = Variable<int>(highPaise);
    map['threshold_cft'] = Variable<int>(thresholdCft);
    map['threshold_inclusive'] = Variable<bool>(thresholdInclusive);
    return map;
  }

  LoadingPoliciesCompanion toCompanion(bool nullToAbsent) {
    return LoadingPoliciesCompanion(
      id: Value(id),
      lowPaise: Value(lowPaise),
      highPaise: Value(highPaise),
      thresholdCft: Value(thresholdCft),
      thresholdInclusive: Value(thresholdInclusive),
    );
  }

  factory LoadingPolicyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoadingPolicyRow(
      id: serializer.fromJson<int>(json['id']),
      lowPaise: serializer.fromJson<int>(json['lowPaise']),
      highPaise: serializer.fromJson<int>(json['highPaise']),
      thresholdCft: serializer.fromJson<int>(json['thresholdCft']),
      thresholdInclusive: serializer.fromJson<bool>(json['thresholdInclusive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lowPaise': serializer.toJson<int>(lowPaise),
      'highPaise': serializer.toJson<int>(highPaise),
      'thresholdCft': serializer.toJson<int>(thresholdCft),
      'thresholdInclusive': serializer.toJson<bool>(thresholdInclusive),
    };
  }

  LoadingPolicyRow copyWith({
    int? id,
    int? lowPaise,
    int? highPaise,
    int? thresholdCft,
    bool? thresholdInclusive,
  }) => LoadingPolicyRow(
    id: id ?? this.id,
    lowPaise: lowPaise ?? this.lowPaise,
    highPaise: highPaise ?? this.highPaise,
    thresholdCft: thresholdCft ?? this.thresholdCft,
    thresholdInclusive: thresholdInclusive ?? this.thresholdInclusive,
  );
  LoadingPolicyRow copyWithCompanion(LoadingPoliciesCompanion data) {
    return LoadingPolicyRow(
      id: data.id.present ? data.id.value : this.id,
      lowPaise: data.lowPaise.present ? data.lowPaise.value : this.lowPaise,
      highPaise: data.highPaise.present ? data.highPaise.value : this.highPaise,
      thresholdCft: data.thresholdCft.present
          ? data.thresholdCft.value
          : this.thresholdCft,
      thresholdInclusive: data.thresholdInclusive.present
          ? data.thresholdInclusive.value
          : this.thresholdInclusive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoadingPolicyRow(')
          ..write('id: $id, ')
          ..write('lowPaise: $lowPaise, ')
          ..write('highPaise: $highPaise, ')
          ..write('thresholdCft: $thresholdCft, ')
          ..write('thresholdInclusive: $thresholdInclusive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lowPaise, highPaise, thresholdCft, thresholdInclusive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoadingPolicyRow &&
          other.id == this.id &&
          other.lowPaise == this.lowPaise &&
          other.highPaise == this.highPaise &&
          other.thresholdCft == this.thresholdCft &&
          other.thresholdInclusive == this.thresholdInclusive);
}

class LoadingPoliciesCompanion extends UpdateCompanion<LoadingPolicyRow> {
  final Value<int> id;
  final Value<int> lowPaise;
  final Value<int> highPaise;
  final Value<int> thresholdCft;
  final Value<bool> thresholdInclusive;
  const LoadingPoliciesCompanion({
    this.id = const Value.absent(),
    this.lowPaise = const Value.absent(),
    this.highPaise = const Value.absent(),
    this.thresholdCft = const Value.absent(),
    this.thresholdInclusive = const Value.absent(),
  });
  LoadingPoliciesCompanion.insert({
    this.id = const Value.absent(),
    this.lowPaise = const Value.absent(),
    this.highPaise = const Value.absent(),
    this.thresholdCft = const Value.absent(),
    this.thresholdInclusive = const Value.absent(),
  });
  static Insertable<LoadingPolicyRow> custom({
    Expression<int>? id,
    Expression<int>? lowPaise,
    Expression<int>? highPaise,
    Expression<int>? thresholdCft,
    Expression<bool>? thresholdInclusive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lowPaise != null) 'low_paise': lowPaise,
      if (highPaise != null) 'high_paise': highPaise,
      if (thresholdCft != null) 'threshold_cft': thresholdCft,
      if (thresholdInclusive != null) 'threshold_inclusive': thresholdInclusive,
    });
  }

  LoadingPoliciesCompanion copyWith({
    Value<int>? id,
    Value<int>? lowPaise,
    Value<int>? highPaise,
    Value<int>? thresholdCft,
    Value<bool>? thresholdInclusive,
  }) {
    return LoadingPoliciesCompanion(
      id: id ?? this.id,
      lowPaise: lowPaise ?? this.lowPaise,
      highPaise: highPaise ?? this.highPaise,
      thresholdCft: thresholdCft ?? this.thresholdCft,
      thresholdInclusive: thresholdInclusive ?? this.thresholdInclusive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lowPaise.present) {
      map['low_paise'] = Variable<int>(lowPaise.value);
    }
    if (highPaise.present) {
      map['high_paise'] = Variable<int>(highPaise.value);
    }
    if (thresholdCft.present) {
      map['threshold_cft'] = Variable<int>(thresholdCft.value);
    }
    if (thresholdInclusive.present) {
      map['threshold_inclusive'] = Variable<bool>(thresholdInclusive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoadingPoliciesCompanion(')
          ..write('id: $id, ')
          ..write('lowPaise: $lowPaise, ')
          ..write('highPaise: $highPaise, ')
          ..write('thresholdCft: $thresholdCft, ')
          ..write('thresholdInclusive: $thresholdInclusive')
          ..write(')'))
        .toString();
  }
}

class $PendingOperationsTable extends PendingOperations
    with TableInfo<$PendingOperationsTable, PendingOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OpType, int> opType =
      GeneratedColumn<int>(
        'op_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<OpType>($PendingOperationsTable.$converteropType);
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enqueuedAt = GeneratedColumn<DateTime>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncState, int> syncState =
      GeneratedColumn<int>(
        'sync_state',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SyncState>($PendingOperationsTable.$convertersyncState);
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    opType,
    payload,
    idempotencyKey,
    enqueuedAt,
    attempts,
    syncState,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOperationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      opType: $PendingOperationsTable.$converteropType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}op_type'],
        )!,
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enqueued_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      syncState: $PendingOperationsTable.$convertersyncState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sync_state'],
        )!,
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingOperationsTable createAlias(String alias) {
    return $PendingOperationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OpType, int, int> $converteropType =
      const EnumIndexConverter<OpType>(OpType.values);
  static JsonTypeConverter2<SyncState, int, int> $convertersyncState =
      const EnumIndexConverter<SyncState>(SyncState.values);
}

class PendingOperationRow extends DataClass
    implements Insertable<PendingOperationRow> {
  /// Primary key (enqueue order follows ascending id).
  final int id;

  /// Which operation this row represents.
  final OpType opType;

  /// Serialized payload.
  final String payload;

  /// Stable idempotency key; unique so duplicate enqueues are rejected.
  final String idempotencyKey;

  /// When enqueued (UTC).
  final DateTime enqueuedAt;

  /// Number of apply attempts so far.
  final int attempts;

  /// Pending / Confirmed / Failed.
  final SyncState syncState;

  /// Last error message on failure.
  final String? lastError;
  const PendingOperationRow({
    required this.id,
    required this.opType,
    required this.payload,
    required this.idempotencyKey,
    required this.enqueuedAt,
    required this.attempts,
    required this.syncState,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['op_type'] = Variable<int>(
        $PendingOperationsTable.$converteropType.toSql(opType),
      );
    }
    map['payload'] = Variable<String>(payload);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['enqueued_at'] = Variable<DateTime>(enqueuedAt);
    map['attempts'] = Variable<int>(attempts);
    {
      map['sync_state'] = Variable<int>(
        $PendingOperationsTable.$convertersyncState.toSql(syncState),
      );
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingOperationsCompanion(
      id: Value(id),
      opType: Value(opType),
      payload: Value(payload),
      idempotencyKey: Value(idempotencyKey),
      enqueuedAt: Value(enqueuedAt),
      attempts: Value(attempts),
      syncState: Value(syncState),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOperationRow(
      id: serializer.fromJson<int>(json['id']),
      opType: $PendingOperationsTable.$converteropType.fromJson(
        serializer.fromJson<int>(json['opType']),
      ),
      payload: serializer.fromJson<String>(json['payload']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      enqueuedAt: serializer.fromJson<DateTime>(json['enqueuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      syncState: $PendingOperationsTable.$convertersyncState.fromJson(
        serializer.fromJson<int>(json['syncState']),
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'opType': serializer.toJson<int>(
        $PendingOperationsTable.$converteropType.toJson(opType),
      ),
      'payload': serializer.toJson<String>(payload),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'enqueuedAt': serializer.toJson<DateTime>(enqueuedAt),
      'attempts': serializer.toJson<int>(attempts),
      'syncState': serializer.toJson<int>(
        $PendingOperationsTable.$convertersyncState.toJson(syncState),
      ),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingOperationRow copyWith({
    int? id,
    OpType? opType,
    String? payload,
    String? idempotencyKey,
    DateTime? enqueuedAt,
    int? attempts,
    SyncState? syncState,
    Value<String?> lastError = const Value.absent(),
  }) => PendingOperationRow(
    id: id ?? this.id,
    opType: opType ?? this.opType,
    payload: payload ?? this.payload,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    attempts: attempts ?? this.attempts,
    syncState: syncState ?? this.syncState,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingOperationRow copyWithCompanion(PendingOperationsCompanion data) {
    return PendingOperationRow(
      id: data.id.present ? data.id.value : this.id,
      opType: data.opType.present ? data.opType.value : this.opType,
      payload: data.payload.present ? data.payload.value : this.payload,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationRow(')
          ..write('id: $id, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('syncState: $syncState, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    opType,
    payload,
    idempotencyKey,
    enqueuedAt,
    attempts,
    syncState,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOperationRow &&
          other.id == this.id &&
          other.opType == this.opType &&
          other.payload == this.payload &&
          other.idempotencyKey == this.idempotencyKey &&
          other.enqueuedAt == this.enqueuedAt &&
          other.attempts == this.attempts &&
          other.syncState == this.syncState &&
          other.lastError == this.lastError);
}

class PendingOperationsCompanion extends UpdateCompanion<PendingOperationRow> {
  final Value<int> id;
  final Value<OpType> opType;
  final Value<String> payload;
  final Value<String> idempotencyKey;
  final Value<DateTime> enqueuedAt;
  final Value<int> attempts;
  final Value<SyncState> syncState;
  final Value<String?> lastError;
  const PendingOperationsCompanion({
    this.id = const Value.absent(),
    this.opType = const Value.absent(),
    this.payload = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.syncState = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingOperationsCompanion.insert({
    this.id = const Value.absent(),
    required OpType opType,
    required String payload,
    required String idempotencyKey,
    required DateTime enqueuedAt,
    this.attempts = const Value.absent(),
    required SyncState syncState,
    this.lastError = const Value.absent(),
  }) : opType = Value(opType),
       payload = Value(payload),
       idempotencyKey = Value(idempotencyKey),
       enqueuedAt = Value(enqueuedAt),
       syncState = Value(syncState);
  static Insertable<PendingOperationRow> custom({
    Expression<int>? id,
    Expression<int>? opType,
    Expression<String>? payload,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? enqueuedAt,
    Expression<int>? attempts,
    Expression<int>? syncState,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opType != null) 'op_type': opType,
      if (payload != null) 'payload': payload,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
      if (attempts != null) 'attempts': attempts,
      if (syncState != null) 'sync_state': syncState,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingOperationsCompanion copyWith({
    Value<int>? id,
    Value<OpType>? opType,
    Value<String>? payload,
    Value<String>? idempotencyKey,
    Value<DateTime>? enqueuedAt,
    Value<int>? attempts,
    Value<SyncState>? syncState,
    Value<String?>? lastError,
  }) {
    return PendingOperationsCompanion(
      id: id ?? this.id,
      opType: opType ?? this.opType,
      payload: payload ?? this.payload,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      attempts: attempts ?? this.attempts,
      syncState: syncState ?? this.syncState,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (opType.present) {
      map['op_type'] = Variable<int>(
        $PendingOperationsTable.$converteropType.toSql(opType.value),
      );
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<DateTime>(enqueuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<int>(
        $PendingOperationsTable.$convertersyncState.toSql(syncState.value),
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationsCompanion(')
          ..write('id: $id, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('syncState: $syncState, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $BackupMetasTable extends BackupMetas
    with TableInfo<$BackupMetasTable, BackupMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupMetasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportedAtMeta = const VerificationMeta(
    'exportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> exportedAt = GeneratedColumn<DateTime>(
    'exported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schemaVersion,
    appVersion,
    exportedAt,
    checksum,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_metas';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    if (data.containsKey('exported_at')) {
      context.handle(
        _exportedAtMeta,
        exportedAt.isAcceptableOrUnknown(data['exported_at']!, _exportedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_exportedAtMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      )!,
      exportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exported_at'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
    );
  }

  @override
  $BackupMetasTable createAlias(String alias) {
    return $BackupMetasTable(attachedDatabase, alias);
  }
}

class BackupMetaRow extends DataClass implements Insertable<BackupMetaRow> {
  /// Primary key.
  final int id;

  /// Schema version the backup was produced against.
  final int schemaVersion;

  /// Producing app version.
  final String appVersion;

  /// When the backup was exported (UTC).
  final DateTime exportedAt;

  /// Integrity checksum.
  final String checksum;
  const BackupMetaRow({
    required this.id,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['app_version'] = Variable<String>(appVersion);
    map['exported_at'] = Variable<DateTime>(exportedAt);
    map['checksum'] = Variable<String>(checksum);
    return map;
  }

  BackupMetasCompanion toCompanion(bool nullToAbsent) {
    return BackupMetasCompanion(
      id: Value(id),
      schemaVersion: Value(schemaVersion),
      appVersion: Value(appVersion),
      exportedAt: Value(exportedAt),
      checksum: Value(checksum),
    );
  }

  factory BackupMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupMetaRow(
      id: serializer.fromJson<int>(json['id']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      exportedAt: serializer.fromJson<DateTime>(json['exportedAt']),
      checksum: serializer.fromJson<String>(json['checksum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'appVersion': serializer.toJson<String>(appVersion),
      'exportedAt': serializer.toJson<DateTime>(exportedAt),
      'checksum': serializer.toJson<String>(checksum),
    };
  }

  BackupMetaRow copyWith({
    int? id,
    int? schemaVersion,
    String? appVersion,
    DateTime? exportedAt,
    String? checksum,
  }) => BackupMetaRow(
    id: id ?? this.id,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    appVersion: appVersion ?? this.appVersion,
    exportedAt: exportedAt ?? this.exportedAt,
    checksum: checksum ?? this.checksum,
  );
  BackupMetaRow copyWithCompanion(BackupMetasCompanion data) {
    return BackupMetaRow(
      id: data.id.present ? data.id.value : this.id,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      exportedAt: data.exportedAt.present
          ? data.exportedAt.value
          : this.exportedAt,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupMetaRow(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('appVersion: $appVersion, ')
          ..write('exportedAt: $exportedAt, ')
          ..write('checksum: $checksum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, schemaVersion, appVersion, exportedAt, checksum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupMetaRow &&
          other.id == this.id &&
          other.schemaVersion == this.schemaVersion &&
          other.appVersion == this.appVersion &&
          other.exportedAt == this.exportedAt &&
          other.checksum == this.checksum);
}

class BackupMetasCompanion extends UpdateCompanion<BackupMetaRow> {
  final Value<int> id;
  final Value<int> schemaVersion;
  final Value<String> appVersion;
  final Value<DateTime> exportedAt;
  final Value<String> checksum;
  const BackupMetasCompanion({
    this.id = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.exportedAt = const Value.absent(),
    this.checksum = const Value.absent(),
  });
  BackupMetasCompanion.insert({
    this.id = const Value.absent(),
    required int schemaVersion,
    required String appVersion,
    required DateTime exportedAt,
    required String checksum,
  }) : schemaVersion = Value(schemaVersion),
       appVersion = Value(appVersion),
       exportedAt = Value(exportedAt),
       checksum = Value(checksum);
  static Insertable<BackupMetaRow> custom({
    Expression<int>? id,
    Expression<int>? schemaVersion,
    Expression<String>? appVersion,
    Expression<DateTime>? exportedAt,
    Expression<String>? checksum,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (appVersion != null) 'app_version': appVersion,
      if (exportedAt != null) 'exported_at': exportedAt,
      if (checksum != null) 'checksum': checksum,
    });
  }

  BackupMetasCompanion copyWith({
    Value<int>? id,
    Value<int>? schemaVersion,
    Value<String>? appVersion,
    Value<DateTime>? exportedAt,
    Value<String>? checksum,
  }) {
    return BackupMetasCompanion(
      id: id ?? this.id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      appVersion: appVersion ?? this.appVersion,
      exportedAt: exportedAt ?? this.exportedAt,
      checksum: checksum ?? this.checksum,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (exportedAt.present) {
      map['exported_at'] = Variable<DateTime>(exportedAt.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupMetasCompanion(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('appVersion: $appVersion, ')
          ..write('exportedAt: $exportedAt, ')
          ..write('checksum: $checksum')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WoodVarietiesTable woodVarieties = $WoodVarietiesTable(this);
  late final $CrossSectionsTable crossSections = $CrossSectionsTable(this);
  late final $StockItemsTable stockItems = $StockItemsTable(this);
  late final $ReceiptSessionsTable receiptSessions = $ReceiptSessionsTable(
    this,
  );
  late final $ReceiptEntriesTable receiptEntries = $ReceiptEntriesTable(this);
  late final $InvoicesTable invoices = $InvoicesTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  late final $PriceRatesTable priceRates = $PriceRatesTable(this);
  late final $DraftOrdersTable draftOrders = $DraftOrdersTable(this);
  late final $DraftOrderRequestsTable draftOrderRequests =
      $DraftOrderRequestsTable(this);
  late final $AllocationLinesTable allocationLines = $AllocationLinesTable(
    this,
  );
  late final $InvoiceLinesTable invoiceLines = $InvoiceLinesTable(this);
  late final $BusinessSettingsTable businessSettings = $BusinessSettingsTable(
    this,
  );
  late final $AllocationPoliciesTable allocationPolicies =
      $AllocationPoliciesTable(this);
  late final $TaxPoliciesTable taxPolicies = $TaxPoliciesTable(this);
  late final $LoadingPoliciesTable loadingPolicies = $LoadingPoliciesTable(
    this,
  );
  late final $PendingOperationsTable pendingOperations =
      $PendingOperationsTable(this);
  late final $BackupMetasTable backupMetas = $BackupMetasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    woodVarieties,
    crossSections,
    stockItems,
    receiptSessions,
    receiptEntries,
    invoices,
    stockMovements,
    priceRates,
    draftOrders,
    draftOrderRequests,
    allocationLines,
    invoiceLines,
    businessSettings,
    allocationPolicies,
    taxPolicies,
    loadingPolicies,
    pendingOperations,
    backupMetas,
  ];
}

typedef $$WoodVarietiesTableCreateCompanionBuilder =
    WoodVarietiesCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> active,
      required DateTime createdAt,
    });
typedef $$WoodVarietiesTableUpdateCompanionBuilder =
    WoodVarietiesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> active,
      Value<DateTime> createdAt,
    });

final class $$WoodVarietiesTableReferences
    extends BaseReferences<_$AppDatabase, $WoodVarietiesTable, WoodVarietyRow> {
  $$WoodVarietiesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$StockItemsTable, List<StockItemRow>>
  _stockItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockItems,
    aliasName: 'wood_varieties__id__stock_items__variety_id',
  );

  $$StockItemsTableProcessedTableManager get stockItemsRefs {
    final manager = $$StockItemsTableTableManager(
      $_db,
      $_db.stockItems,
    ).filter((f) => f.varietyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PriceRatesTable, List<PriceRateRow>>
  _priceRatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.priceRates,
    aliasName: 'wood_varieties__id__price_rates__variety_id',
  );

  $$PriceRatesTableProcessedTableManager get priceRatesRefs {
    final manager = $$PriceRatesTableTableManager(
      $_db,
      $_db.priceRates,
    ).filter((f) => f.varietyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_priceRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DraftOrderRequestsTable,
    List<DraftOrderRequestRow>
  >
  _draftOrderRequestsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.draftOrderRequests,
        aliasName: 'wood_varieties__id__draft_order_requests__variety_id',
      );

  $$DraftOrderRequestsTableProcessedTableManager get draftOrderRequestsRefs {
    final manager = $$DraftOrderRequestsTableTableManager(
      $_db,
      $_db.draftOrderRequests,
    ).filter((f) => f.varietyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _draftOrderRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WoodVarietiesTableFilterComposer
    extends Composer<_$AppDatabase, $WoodVarietiesTable> {
  $$WoodVarietiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stockItemsRefs(
    Expression<bool> Function($$StockItemsTableFilterComposer f) f,
  ) {
    final $$StockItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.varietyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableFilterComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priceRatesRefs(
    Expression<bool> Function($$PriceRatesTableFilterComposer f) f,
  ) {
    final $$PriceRatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.priceRates,
      getReferencedColumn: (t) => t.varietyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceRatesTableFilterComposer(
            $db: $db,
            $table: $db.priceRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> draftOrderRequestsRefs(
    Expression<bool> Function($$DraftOrderRequestsTableFilterComposer f) f,
  ) {
    final $$DraftOrderRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftOrderRequests,
      getReferencedColumn: (t) => t.varietyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrderRequestsTableFilterComposer(
            $db: $db,
            $table: $db.draftOrderRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WoodVarietiesTableOrderingComposer
    extends Composer<_$AppDatabase, $WoodVarietiesTable> {
  $$WoodVarietiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WoodVarietiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WoodVarietiesTable> {
  $$WoodVarietiesTableAnnotationComposer({
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

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> stockItemsRefs<T extends Object>(
    Expression<T> Function($$StockItemsTableAnnotationComposer a) f,
  ) {
    final $$StockItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.varietyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priceRatesRefs<T extends Object>(
    Expression<T> Function($$PriceRatesTableAnnotationComposer a) f,
  ) {
    final $$PriceRatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.priceRates,
      getReferencedColumn: (t) => t.varietyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceRatesTableAnnotationComposer(
            $db: $db,
            $table: $db.priceRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> draftOrderRequestsRefs<T extends Object>(
    Expression<T> Function($$DraftOrderRequestsTableAnnotationComposer a) f,
  ) {
    final $$DraftOrderRequestsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.draftOrderRequests,
          getReferencedColumn: (t) => t.varietyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DraftOrderRequestsTableAnnotationComposer(
                $db: $db,
                $table: $db.draftOrderRequests,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WoodVarietiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WoodVarietiesTable,
          WoodVarietyRow,
          $$WoodVarietiesTableFilterComposer,
          $$WoodVarietiesTableOrderingComposer,
          $$WoodVarietiesTableAnnotationComposer,
          $$WoodVarietiesTableCreateCompanionBuilder,
          $$WoodVarietiesTableUpdateCompanionBuilder,
          (WoodVarietyRow, $$WoodVarietiesTableReferences),
          WoodVarietyRow,
          PrefetchHooks Function({
            bool stockItemsRefs,
            bool priceRatesRefs,
            bool draftOrderRequestsRefs,
          })
        > {
  $$WoodVarietiesTableTableManager(_$AppDatabase db, $WoodVarietiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WoodVarietiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WoodVarietiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WoodVarietiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WoodVarietiesCompanion(
                id: id,
                name: name,
                active: active,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
              }) => WoodVarietiesCompanion.insert(
                id: id,
                name: name,
                active: active,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WoodVarietiesTable, WoodVarietyRow>(table),
                  $$WoodVarietiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                stockItemsRefs = false,
                priceRatesRefs = false,
                draftOrderRequestsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockItemsRefs) db.stockItems,
                    if (priceRatesRefs) db.priceRates,
                    if (draftOrderRequestsRefs) db.draftOrderRequests,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockItemsRefs)
                        await $_getPrefetchedData<
                          WoodVarietyRow,
                          $WoodVarietiesTable,
                          StockItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$WoodVarietiesTableReferences
                              ._stockItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WoodVarietiesTableReferences(
                                db,
                                table,
                                p0,
                              ).stockItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.varietyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (priceRatesRefs)
                        await $_getPrefetchedData<
                          WoodVarietyRow,
                          $WoodVarietiesTable,
                          PriceRateRow
                        >(
                          currentTable: table,
                          referencedTable: $$WoodVarietiesTableReferences
                              ._priceRatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WoodVarietiesTableReferences(
                                db,
                                table,
                                p0,
                              ).priceRatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.varietyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (draftOrderRequestsRefs)
                        await $_getPrefetchedData<
                          WoodVarietyRow,
                          $WoodVarietiesTable,
                          DraftOrderRequestRow
                        >(
                          currentTable: table,
                          referencedTable: $$WoodVarietiesTableReferences
                              ._draftOrderRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WoodVarietiesTableReferences(
                                db,
                                table,
                                p0,
                              ).draftOrderRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.varietyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WoodVarietiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WoodVarietiesTable,
      WoodVarietyRow,
      $$WoodVarietiesTableFilterComposer,
      $$WoodVarietiesTableOrderingComposer,
      $$WoodVarietiesTableAnnotationComposer,
      $$WoodVarietiesTableCreateCompanionBuilder,
      $$WoodVarietiesTableUpdateCompanionBuilder,
      (WoodVarietyRow, $$WoodVarietiesTableReferences),
      WoodVarietyRow,
      PrefetchHooks Function({
        bool stockItemsRefs,
        bool priceRatesRefs,
        bool draftOrderRequestsRefs,
      })
    >;
typedef $$CrossSectionsTableCreateCompanionBuilder =
    CrossSectionsCompanion Function({
      Value<int> id,
      required int widthIn,
      required int thicknessIn,
      required CategoryKind category,
      required int bunchSize,
      Value<bool> active,
    });
typedef $$CrossSectionsTableUpdateCompanionBuilder =
    CrossSectionsCompanion Function({
      Value<int> id,
      Value<int> widthIn,
      Value<int> thicknessIn,
      Value<CategoryKind> category,
      Value<int> bunchSize,
      Value<bool> active,
    });

final class $$CrossSectionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CrossSectionsTable, CrossSectionRow> {
  $$CrossSectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$StockItemsTable, List<StockItemRow>>
  _stockItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockItems,
    aliasName: 'cross_sections__id__stock_items__cross_section_id',
  );

  $$StockItemsTableProcessedTableManager get stockItemsRefs {
    final manager = $$StockItemsTableTableManager(
      $_db,
      $_db.stockItems,
    ).filter((f) => f.crossSectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PriceRatesTable, List<PriceRateRow>>
  _priceRatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.priceRates,
    aliasName: 'cross_sections__id__price_rates__cross_section_id',
  );

  $$PriceRatesTableProcessedTableManager get priceRatesRefs {
    final manager = $$PriceRatesTableTableManager(
      $_db,
      $_db.priceRates,
    ).filter((f) => f.crossSectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_priceRatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DraftOrderRequestsTable,
    List<DraftOrderRequestRow>
  >
  _draftOrderRequestsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.draftOrderRequests,
        aliasName: 'cross_sections__id__draft_order_requests__cross_section_id',
      );

  $$DraftOrderRequestsTableProcessedTableManager get draftOrderRequestsRefs {
    final manager = $$DraftOrderRequestsTableTableManager(
      $_db,
      $_db.draftOrderRequests,
    ).filter((f) => f.crossSectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _draftOrderRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CrossSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CrossSectionsTable> {
  $$CrossSectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthIn => $composableBuilder(
    column: $table.widthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thicknessIn => $composableBuilder(
    column: $table.thicknessIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, int>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get bunchSize => $composableBuilder(
    column: $table.bunchSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stockItemsRefs(
    Expression<bool> Function($$StockItemsTableFilterComposer f) f,
  ) {
    final $$StockItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.crossSectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableFilterComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priceRatesRefs(
    Expression<bool> Function($$PriceRatesTableFilterComposer f) f,
  ) {
    final $$PriceRatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.priceRates,
      getReferencedColumn: (t) => t.crossSectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceRatesTableFilterComposer(
            $db: $db,
            $table: $db.priceRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> draftOrderRequestsRefs(
    Expression<bool> Function($$DraftOrderRequestsTableFilterComposer f) f,
  ) {
    final $$DraftOrderRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftOrderRequests,
      getReferencedColumn: (t) => t.crossSectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrderRequestsTableFilterComposer(
            $db: $db,
            $table: $db.draftOrderRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CrossSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CrossSectionsTable> {
  $$CrossSectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthIn => $composableBuilder(
    column: $table.widthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thicknessIn => $composableBuilder(
    column: $table.thicknessIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bunchSize => $composableBuilder(
    column: $table.bunchSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrossSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CrossSectionsTable> {
  $$CrossSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get widthIn =>
      $composableBuilder(column: $table.widthIn, builder: (column) => column);

  GeneratedColumn<int> get thicknessIn => $composableBuilder(
    column: $table.thicknessIn,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CategoryKind, int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get bunchSize =>
      $composableBuilder(column: $table.bunchSize, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  Expression<T> stockItemsRefs<T extends Object>(
    Expression<T> Function($$StockItemsTableAnnotationComposer a) f,
  ) {
    final $$StockItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.crossSectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priceRatesRefs<T extends Object>(
    Expression<T> Function($$PriceRatesTableAnnotationComposer a) f,
  ) {
    final $$PriceRatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.priceRates,
      getReferencedColumn: (t) => t.crossSectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceRatesTableAnnotationComposer(
            $db: $db,
            $table: $db.priceRates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> draftOrderRequestsRefs<T extends Object>(
    Expression<T> Function($$DraftOrderRequestsTableAnnotationComposer a) f,
  ) {
    final $$DraftOrderRequestsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.draftOrderRequests,
          getReferencedColumn: (t) => t.crossSectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DraftOrderRequestsTableAnnotationComposer(
                $db: $db,
                $table: $db.draftOrderRequests,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CrossSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CrossSectionsTable,
          CrossSectionRow,
          $$CrossSectionsTableFilterComposer,
          $$CrossSectionsTableOrderingComposer,
          $$CrossSectionsTableAnnotationComposer,
          $$CrossSectionsTableCreateCompanionBuilder,
          $$CrossSectionsTableUpdateCompanionBuilder,
          (CrossSectionRow, $$CrossSectionsTableReferences),
          CrossSectionRow,
          PrefetchHooks Function({
            bool stockItemsRefs,
            bool priceRatesRefs,
            bool draftOrderRequestsRefs,
          })
        > {
  $$CrossSectionsTableTableManager(_$AppDatabase db, $CrossSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrossSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrossSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrossSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> widthIn = const Value.absent(),
                Value<int> thicknessIn = const Value.absent(),
                Value<CategoryKind> category = const Value.absent(),
                Value<int> bunchSize = const Value.absent(),
                Value<bool> active = const Value.absent(),
              }) => CrossSectionsCompanion(
                id: id,
                widthIn: widthIn,
                thicknessIn: thicknessIn,
                category: category,
                bunchSize: bunchSize,
                active: active,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int widthIn,
                required int thicknessIn,
                required CategoryKind category,
                required int bunchSize,
                Value<bool> active = const Value.absent(),
              }) => CrossSectionsCompanion.insert(
                id: id,
                widthIn: widthIn,
                thicknessIn: thicknessIn,
                category: category,
                bunchSize: bunchSize,
                active: active,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CrossSectionsTable, CrossSectionRow>(table),
                  $$CrossSectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                stockItemsRefs = false,
                priceRatesRefs = false,
                draftOrderRequestsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockItemsRefs) db.stockItems,
                    if (priceRatesRefs) db.priceRates,
                    if (draftOrderRequestsRefs) db.draftOrderRequests,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockItemsRefs)
                        await $_getPrefetchedData<
                          CrossSectionRow,
                          $CrossSectionsTable,
                          StockItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$CrossSectionsTableReferences
                              ._stockItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CrossSectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).stockItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.crossSectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (priceRatesRefs)
                        await $_getPrefetchedData<
                          CrossSectionRow,
                          $CrossSectionsTable,
                          PriceRateRow
                        >(
                          currentTable: table,
                          referencedTable: $$CrossSectionsTableReferences
                              ._priceRatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CrossSectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).priceRatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.crossSectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (draftOrderRequestsRefs)
                        await $_getPrefetchedData<
                          CrossSectionRow,
                          $CrossSectionsTable,
                          DraftOrderRequestRow
                        >(
                          currentTable: table,
                          referencedTable: $$CrossSectionsTableReferences
                              ._draftOrderRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CrossSectionsTableReferences(
                                db,
                                table,
                                p0,
                              ).draftOrderRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.crossSectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CrossSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CrossSectionsTable,
      CrossSectionRow,
      $$CrossSectionsTableFilterComposer,
      $$CrossSectionsTableOrderingComposer,
      $$CrossSectionsTableAnnotationComposer,
      $$CrossSectionsTableCreateCompanionBuilder,
      $$CrossSectionsTableUpdateCompanionBuilder,
      (CrossSectionRow, $$CrossSectionsTableReferences),
      CrossSectionRow,
      PrefetchHooks Function({
        bool stockItemsRefs,
        bool priceRatesRefs,
        bool draftOrderRequestsRefs,
      })
    >;
typedef $$StockItemsTableCreateCompanionBuilder = StockItemsCompanion Function({
  Value<int> id,
  required int varietyId,
  required int crossSectionId,
  required int lengthFt,
  Value<int> confirmedBalancePieces,
  Value<int> pendingBalancePieces,
});
typedef $$StockItemsTableUpdateCompanionBuilder = StockItemsCompanion Function({
  Value<int> id,
  Value<int> varietyId,
  Value<int> crossSectionId,
  Value<int> lengthFt,
  Value<int> confirmedBalancePieces,
  Value<int> pendingBalancePieces,
});

final class $$StockItemsTableReferences
    extends BaseReferences<_$AppDatabase, $StockItemsTable, StockItemRow> {
  $$StockItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WoodVarietiesTable _varietyIdTable(_$AppDatabase db) => db
      .woodVarieties
      .createAlias('stock_items__variety_id__wood_varieties__id');

  $$WoodVarietiesTableProcessedTableManager get varietyId {
    final $_column = $_itemColumn<int>('variety_id')!;

    final manager = $$WoodVarietiesTableTableManager(
      $_db,
      $_db.woodVarieties,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_varietyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CrossSectionsTable _crossSectionIdTable(_$AppDatabase db) => db
      .crossSections
      .createAlias('stock_items__cross_section_id__cross_sections__id');

  $$CrossSectionsTableProcessedTableManager get crossSectionId {
    final $_column = $_itemColumn<int>('cross_section_id')!;

    final manager = $$CrossSectionsTableTableManager(
      $_db,
      $_db.crossSections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_crossSectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReceiptEntriesTable, List<ReceiptEntryRow>>
  _receiptEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.receiptEntries,
    aliasName: 'stock_items__id__receipt_entries__stock_item_id',
  );

  $$ReceiptEntriesTableProcessedTableManager get receiptEntriesRefs {
    final manager = $$ReceiptEntriesTableTableManager(
      $_db,
      $_db.receiptEntries,
    ).filter((f) => f.stockItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovementRow>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'stock_items__id__stock_movements__stock_item_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.stockItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AllocationLinesTable, List<AllocationLineRow>>
  _allocationLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.allocationLines,
    aliasName: 'stock_items__id__allocation_lines__stock_item_id',
  );

  $$AllocationLinesTableProcessedTableManager get allocationLinesRefs {
    final manager = $$AllocationLinesTableTableManager(
      $_db,
      $_db.allocationLines,
    ).filter((f) => f.stockItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _allocationLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StockItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmedBalancePieces => $composableBuilder(
    column: $table.confirmedBalancePieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingBalancePieces => $composableBuilder(
    column: $table.pendingBalancePieces,
    builder: (column) => ColumnFilters(column),
  );

  $$WoodVarietiesTableFilterComposer get varietyId {
    final $$WoodVarietiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableFilterComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableFilterComposer get crossSectionId {
    final $$CrossSectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableFilterComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> receiptEntriesRefs(
    Expression<bool> Function($$ReceiptEntriesTableFilterComposer f) f,
  ) {
    final $$ReceiptEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableFilterComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> allocationLinesRefs(
    Expression<bool> Function($$AllocationLinesTableFilterComposer f) f,
  ) {
    final $$AllocationLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationLines,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationLinesTableFilterComposer(
            $db: $db,
            $table: $db.allocationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StockItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedBalancePieces => $composableBuilder(
    column: $table.confirmedBalancePieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingBalancePieces => $composableBuilder(
    column: $table.pendingBalancePieces,
    builder: (column) => ColumnOrderings(column),
  );

  $$WoodVarietiesTableOrderingComposer get varietyId {
    final $$WoodVarietiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableOrderingComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableOrderingComposer get crossSectionId {
    final $$CrossSectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableOrderingComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lengthFt =>
      $composableBuilder(column: $table.lengthFt, builder: (column) => column);

  GeneratedColumn<int> get confirmedBalancePieces => $composableBuilder(
    column: $table.confirmedBalancePieces,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pendingBalancePieces => $composableBuilder(
    column: $table.pendingBalancePieces,
    builder: (column) => column,
  );

  $$WoodVarietiesTableAnnotationComposer get varietyId {
    final $$WoodVarietiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableAnnotationComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableAnnotationComposer get crossSectionId {
    final $$CrossSectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> receiptEntriesRefs<T extends Object>(
    Expression<T> Function($$ReceiptEntriesTableAnnotationComposer a) f,
  ) {
    final $$ReceiptEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> allocationLinesRefs<T extends Object>(
    Expression<T> Function($$AllocationLinesTableAnnotationComposer a) f,
  ) {
    final $$AllocationLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationLines,
      getReferencedColumn: (t) => t.stockItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.allocationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StockItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockItemsTable,
          StockItemRow,
          $$StockItemsTableFilterComposer,
          $$StockItemsTableOrderingComposer,
          $$StockItemsTableAnnotationComposer,
          $$StockItemsTableCreateCompanionBuilder,
          $$StockItemsTableUpdateCompanionBuilder,
          (StockItemRow, $$StockItemsTableReferences),
          StockItemRow,
          PrefetchHooks Function({
            bool varietyId,
            bool crossSectionId,
            bool receiptEntriesRefs,
            bool stockMovementsRefs,
            bool allocationLinesRefs,
          })
        > {
  $$StockItemsTableTableManager(_$AppDatabase db, $StockItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> varietyId = const Value.absent(),
                Value<int> crossSectionId = const Value.absent(),
                Value<int> lengthFt = const Value.absent(),
                Value<int> confirmedBalancePieces = const Value.absent(),
                Value<int> pendingBalancePieces = const Value.absent(),
              }) => StockItemsCompanion(
                id: id,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                lengthFt: lengthFt,
                confirmedBalancePieces: confirmedBalancePieces,
                pendingBalancePieces: pendingBalancePieces,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int varietyId,
                required int crossSectionId,
                required int lengthFt,
                Value<int> confirmedBalancePieces = const Value.absent(),
                Value<int> pendingBalancePieces = const Value.absent(),
              }) => StockItemsCompanion.insert(
                id: id,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                lengthFt: lengthFt,
                confirmedBalancePieces: confirmedBalancePieces,
                pendingBalancePieces: pendingBalancePieces,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StockItemsTable, StockItemRow>(table),
                  $$StockItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                varietyId = false,
                crossSectionId = false,
                receiptEntriesRefs = false,
                stockMovementsRefs = false,
                allocationLinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (receiptEntriesRefs) db.receiptEntries,
                    if (stockMovementsRefs) db.stockMovements,
                    if (allocationLinesRefs) db.allocationLines,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (varietyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.varietyId,
                            referencedTable: $$StockItemsTableReferences
                                ._varietyIdTable(db),
                            referencedColumn: $$StockItemsTableReferences
                                ._varietyIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (crossSectionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.crossSectionId,
                            referencedTable: $$StockItemsTableReferences
                                ._crossSectionIdTable(db),
                            referencedColumn: $$StockItemsTableReferences
                                ._crossSectionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (receiptEntriesRefs)
                        await $_getPrefetchedData<
                          StockItemRow,
                          $StockItemsTable,
                          ReceiptEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$StockItemsTableReferences
                              ._receiptEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stockItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          StockItemRow,
                          $StockItemsTable,
                          StockMovementRow
                        >(
                          currentTable: table,
                          referencedTable: $$StockItemsTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stockItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (allocationLinesRefs)
                        await $_getPrefetchedData<
                          StockItemRow,
                          $StockItemsTable,
                          AllocationLineRow
                        >(
                          currentTable: table,
                          referencedTable: $$StockItemsTableReferences
                              ._allocationLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StockItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).allocationLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stockItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StockItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockItemsTable,
      StockItemRow,
      $$StockItemsTableFilterComposer,
      $$StockItemsTableOrderingComposer,
      $$StockItemsTableAnnotationComposer,
      $$StockItemsTableCreateCompanionBuilder,
      $$StockItemsTableUpdateCompanionBuilder,
      (StockItemRow, $$StockItemsTableReferences),
      StockItemRow,
      PrefetchHooks Function({
        bool varietyId,
        bool crossSectionId,
        bool receiptEntriesRefs,
        bool stockMovementsRefs,
        bool allocationLinesRefs,
      })
    >;
typedef $$ReceiptSessionsTableCreateCompanionBuilder =
    ReceiptSessionsCompanion Function({
      Value<int> id,
      required ReceiptStatus status,
      required DateTime startedAt,
      Value<DateTime?> finishedAt,
    });
typedef $$ReceiptSessionsTableUpdateCompanionBuilder =
    ReceiptSessionsCompanion Function({
      Value<int> id,
      Value<ReceiptStatus> status,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
    });

final class $$ReceiptSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReceiptSessionsTable,
          ReceiptSessionRow
        > {
  $$ReceiptSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ReceiptEntriesTable, List<ReceiptEntryRow>>
  _receiptEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.receiptEntries,
    aliasName: 'receipt_sessions__id__receipt_entries__receipt_id',
  );

  $$ReceiptEntriesTableProcessedTableManager get receiptEntriesRefs {
    final manager = $$ReceiptEntriesTableTableManager(
      $_db,
      $_db.receiptEntries,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReceiptSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptSessionsTable> {
  $$ReceiptSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReceiptStatus, ReceiptStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> receiptEntriesRefs(
    Expression<bool> Function($$ReceiptEntriesTableFilterComposer f) f,
  ) {
    final $$ReceiptEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableFilterComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptSessionsTable> {
  $$ReceiptSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptSessionsTable> {
  $$ReceiptSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReceiptStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  Expression<T> receiptEntriesRefs<T extends Object>(
    Expression<T> Function($$ReceiptEntriesTableAnnotationComposer a) f,
  ) {
    final $$ReceiptEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptSessionsTable,
          ReceiptSessionRow,
          $$ReceiptSessionsTableFilterComposer,
          $$ReceiptSessionsTableOrderingComposer,
          $$ReceiptSessionsTableAnnotationComposer,
          $$ReceiptSessionsTableCreateCompanionBuilder,
          $$ReceiptSessionsTableUpdateCompanionBuilder,
          (ReceiptSessionRow, $$ReceiptSessionsTableReferences),
          ReceiptSessionRow,
          PrefetchHooks Function({bool receiptEntriesRefs})
        > {
  $$ReceiptSessionsTableTableManager(
    _$AppDatabase db,
    $ReceiptSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ReceiptStatus> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
              }) => ReceiptSessionsCompanion(
                id: id,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required ReceiptStatus status,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
              }) => ReceiptSessionsCompanion.insert(
                id: id,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptSessionsTable, ReceiptSessionRow>(table),
                  $$ReceiptSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (receiptEntriesRefs) db.receiptEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (receiptEntriesRefs)
                    await $_getPrefetchedData<
                      ReceiptSessionRow,
                      $ReceiptSessionsTable,
                      ReceiptEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$ReceiptSessionsTableReferences
                          ._receiptEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ReceiptSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).receiptEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.receiptId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ReceiptSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptSessionsTable,
      ReceiptSessionRow,
      $$ReceiptSessionsTableFilterComposer,
      $$ReceiptSessionsTableOrderingComposer,
      $$ReceiptSessionsTableAnnotationComposer,
      $$ReceiptSessionsTableCreateCompanionBuilder,
      $$ReceiptSessionsTableUpdateCompanionBuilder,
      (ReceiptSessionRow, $$ReceiptSessionsTableReferences),
      ReceiptSessionRow,
      PrefetchHooks Function({bool receiptEntriesRefs})
    >;
typedef $$ReceiptEntriesTableCreateCompanionBuilder =
    ReceiptEntriesCompanion Function({
      Value<int> id,
      required int receiptId,
      required int stockItemId,
      required int qtyInput,
      required InputUnit unit,
      required int piecesDelta,
      required String idempotencyKey,
      required DateTime createdAt,
    });
typedef $$ReceiptEntriesTableUpdateCompanionBuilder =
    ReceiptEntriesCompanion Function({
      Value<int> id,
      Value<int> receiptId,
      Value<int> stockItemId,
      Value<int> qtyInput,
      Value<InputUnit> unit,
      Value<int> piecesDelta,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
    });

final class $$ReceiptEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReceiptEntriesTable, ReceiptEntryRow> {
  $$ReceiptEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReceiptSessionsTable _receiptIdTable(_$AppDatabase db) => db
      .receiptSessions
      .createAlias('receipt_entries__receipt_id__receipt_sessions__id');

  $$ReceiptSessionsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<int>('receipt_id')!;

    final manager = $$ReceiptSessionsTableTableManager(
      $_db,
      $_db.receiptSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StockItemsTable _stockItemIdTable(_$AppDatabase db) => db.stockItems
      .createAlias('receipt_entries__stock_item_id__stock_items__id');

  $$StockItemsTableProcessedTableManager get stockItemId {
    final $_column = $_itemColumn<int>('stock_item_id')!;

    final manager = $$StockItemsTableTableManager(
      $_db,
      $_db.stockItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stockItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovementRow>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'receipt_entries__id__stock_movements__receipt_entry_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.receiptEntryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReceiptEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptEntriesTable> {
  $$ReceiptEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyInput => $composableBuilder(
    column: $table.qtyInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InputUnit, InputUnit, int> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get piecesDelta => $composableBuilder(
    column: $table.piecesDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptSessionsTableFilterComposer get receiptId {
    final $$ReceiptSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptSessionsTableFilterComposer(
            $db: $db,
            $table: $db.receiptSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableFilterComposer get stockItemId {
    final $$StockItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableFilterComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.receiptEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptEntriesTable> {
  $$ReceiptEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyInput => $composableBuilder(
    column: $table.qtyInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get piecesDelta => $composableBuilder(
    column: $table.piecesDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptSessionsTableOrderingComposer get receiptId {
    final $$ReceiptSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.receiptSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableOrderingComposer get stockItemId {
    final $$StockItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableOrderingComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptEntriesTable> {
  $$ReceiptEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qtyInput =>
      $composableBuilder(column: $table.qtyInput, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InputUnit, int> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get piecesDelta => $composableBuilder(
    column: $table.piecesDelta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ReceiptSessionsTableAnnotationComposer get receiptId {
    final $$ReceiptSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableAnnotationComposer get stockItemId {
    final $$StockItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.receiptEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptEntriesTable,
          ReceiptEntryRow,
          $$ReceiptEntriesTableFilterComposer,
          $$ReceiptEntriesTableOrderingComposer,
          $$ReceiptEntriesTableAnnotationComposer,
          $$ReceiptEntriesTableCreateCompanionBuilder,
          $$ReceiptEntriesTableUpdateCompanionBuilder,
          (ReceiptEntryRow, $$ReceiptEntriesTableReferences),
          ReceiptEntryRow,
          PrefetchHooks Function({
            bool receiptId,
            bool stockItemId,
            bool stockMovementsRefs,
          })
        > {
  $$ReceiptEntriesTableTableManager(
    _$AppDatabase db,
    $ReceiptEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> receiptId = const Value.absent(),
                Value<int> stockItemId = const Value.absent(),
                Value<int> qtyInput = const Value.absent(),
                Value<InputUnit> unit = const Value.absent(),
                Value<int> piecesDelta = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReceiptEntriesCompanion(
                id: id,
                receiptId: receiptId,
                stockItemId: stockItemId,
                qtyInput: qtyInput,
                unit: unit,
                piecesDelta: piecesDelta,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int receiptId,
                required int stockItemId,
                required int qtyInput,
                required InputUnit unit,
                required int piecesDelta,
                required String idempotencyKey,
                required DateTime createdAt,
              }) => ReceiptEntriesCompanion.insert(
                id: id,
                receiptId: receiptId,
                stockItemId: stockItemId,
                qtyInput: qtyInput,
                unit: unit,
                piecesDelta: piecesDelta,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptEntriesTable, ReceiptEntryRow>(table),
                  $$ReceiptEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                receiptId = false,
                stockItemId = false,
                stockMovementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockMovementsRefs) db.stockMovements,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (receiptId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.receiptId,
                            referencedTable: $$ReceiptEntriesTableReferences
                                ._receiptIdTable(db),
                            referencedColumn: $$ReceiptEntriesTableReferences
                                ._receiptIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (stockItemId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.stockItemId,
                            referencedTable: $$ReceiptEntriesTableReferences
                                ._stockItemIdTable(db),
                            referencedColumn: $$ReceiptEntriesTableReferences
                                ._stockItemIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          ReceiptEntryRow,
                          $ReceiptEntriesTable,
                          StockMovementRow
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptEntriesTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.receiptEntryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReceiptEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptEntriesTable,
      ReceiptEntryRow,
      $$ReceiptEntriesTableFilterComposer,
      $$ReceiptEntriesTableOrderingComposer,
      $$ReceiptEntriesTableAnnotationComposer,
      $$ReceiptEntriesTableCreateCompanionBuilder,
      $$ReceiptEntriesTableUpdateCompanionBuilder,
      (ReceiptEntryRow, $$ReceiptEntriesTableReferences),
      ReceiptEntryRow,
      PrefetchHooks Function({
        bool receiptId,
        bool stockItemId,
        bool stockMovementsRefs,
      })
    >;
typedef $$InvoicesTableCreateCompanionBuilder = InvoicesCompanion Function({
  Value<int> id,
  required String invoiceNumber,
  required InvoiceStatus status,
  Value<String?> customerName,
  Value<String?> customerPhone,
  required int goodsSubtotalPaise,
  required int taxPaise,
  required int loadingPaise,
  required int payablePaise,
  required int totalCftNum,
  required int totalCftDen,
  required String taxPolicySnapshot,
  required String loadingPolicySnapshot,
  required String businessProfileSnapshot,
  required DateTime finalizedAt,
  required String idempotencyKey,
});
typedef $$InvoicesTableUpdateCompanionBuilder = InvoicesCompanion Function({
  Value<int> id,
  Value<String> invoiceNumber,
  Value<InvoiceStatus> status,
  Value<String?> customerName,
  Value<String?> customerPhone,
  Value<int> goodsSubtotalPaise,
  Value<int> taxPaise,
  Value<int> loadingPaise,
  Value<int> payablePaise,
  Value<int> totalCftNum,
  Value<int> totalCftDen,
  Value<String> taxPolicySnapshot,
  Value<String> loadingPolicySnapshot,
  Value<String> businessProfileSnapshot,
  Value<DateTime> finalizedAt,
  Value<String> idempotencyKey,
});

final class $$InvoicesTableReferences
    extends BaseReferences<_$AppDatabase, $InvoicesTable, InvoiceRow> {
  $$InvoicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovementRow>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'invoices__id__stock_movements__invoice_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.invoiceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DraftOrdersTable, List<DraftOrderRow>>
  _draftOrdersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.draftOrders,
    aliasName: 'invoices__id__draft_orders__invoice_id',
  );

  $$DraftOrdersTableProcessedTableManager get draftOrdersRefs {
    final manager = $$DraftOrdersTableTableManager(
      $_db,
      $_db.draftOrders,
    ).filter((f) => f.invoiceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_draftOrdersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InvoiceLinesTable, List<InvoiceLineRow>>
  _invoiceLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.invoiceLines,
    aliasName: 'invoices__id__invoice_lines__invoice_id',
  );

  $$InvoiceLinesTableProcessedTableManager get invoiceLinesRefs {
    final manager = $$InvoiceLinesTableTableManager(
      $_db,
      $_db.invoiceLines,
    ).filter((f) => f.invoiceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoiceLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InvoiceStatus, InvoiceStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goodsSubtotalPaise => $composableBuilder(
    column: $table.goodsSubtotalPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loadingPaise => $composableBuilder(
    column: $table.loadingPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payablePaise => $composableBuilder(
    column: $table.payablePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCftNum => $composableBuilder(
    column: $table.totalCftNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCftDen => $composableBuilder(
    column: $table.totalCftDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxPolicySnapshot => $composableBuilder(
    column: $table.taxPolicySnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loadingPolicySnapshot => $composableBuilder(
    column: $table.loadingPolicySnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessProfileSnapshot => $composableBuilder(
    column: $table.businessProfileSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> draftOrdersRefs(
    Expression<bool> Function($$DraftOrdersTableFilterComposer f) f,
  ) {
    final $$DraftOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableFilterComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> invoiceLinesRefs(
    Expression<bool> Function($$InvoiceLinesTableFilterComposer f) f,
  ) {
    final $$InvoiceLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceLines,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceLinesTableFilterComposer(
            $db: $db,
            $table: $db.invoiceLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goodsSubtotalPaise => $composableBuilder(
    column: $table.goodsSubtotalPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxPaise => $composableBuilder(
    column: $table.taxPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loadingPaise => $composableBuilder(
    column: $table.loadingPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payablePaise => $composableBuilder(
    column: $table.payablePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCftNum => $composableBuilder(
    column: $table.totalCftNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCftDen => $composableBuilder(
    column: $table.totalCftDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxPolicySnapshot => $composableBuilder(
    column: $table.taxPolicySnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loadingPolicySnapshot => $composableBuilder(
    column: $table.loadingPolicySnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessProfileSnapshot => $composableBuilder(
    column: $table.businessProfileSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InvoiceStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goodsSubtotalPaise => $composableBuilder(
    column: $table.goodsSubtotalPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxPaise =>
      $composableBuilder(column: $table.taxPaise, builder: (column) => column);

  GeneratedColumn<int> get loadingPaise => $composableBuilder(
    column: $table.loadingPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payablePaise => $composableBuilder(
    column: $table.payablePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCftNum => $composableBuilder(
    column: $table.totalCftNum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCftDen => $composableBuilder(
    column: $table.totalCftDen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taxPolicySnapshot => $composableBuilder(
    column: $table.taxPolicySnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loadingPolicySnapshot => $composableBuilder(
    column: $table.loadingPolicySnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessProfileSnapshot => $composableBuilder(
    column: $table.businessProfileSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> draftOrdersRefs<T extends Object>(
    Expression<T> Function($$DraftOrdersTableAnnotationComposer a) f,
  ) {
    final $$DraftOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> invoiceLinesRefs<T extends Object>(
    Expression<T> Function($$InvoiceLinesTableAnnotationComposer a) f,
  ) {
    final $$InvoiceLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceLines,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoiceLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InvoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoicesTable,
          InvoiceRow,
          $$InvoicesTableFilterComposer,
          $$InvoicesTableOrderingComposer,
          $$InvoicesTableAnnotationComposer,
          $$InvoicesTableCreateCompanionBuilder,
          $$InvoicesTableUpdateCompanionBuilder,
          (InvoiceRow, $$InvoicesTableReferences),
          InvoiceRow,
          PrefetchHooks Function({
            bool stockMovementsRefs,
            bool draftOrdersRefs,
            bool invoiceLinesRefs,
          })
        > {
  $$InvoicesTableTableManager(_$AppDatabase db, $InvoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> invoiceNumber = const Value.absent(),
                Value<InvoiceStatus> status = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<int> goodsSubtotalPaise = const Value.absent(),
                Value<int> taxPaise = const Value.absent(),
                Value<int> loadingPaise = const Value.absent(),
                Value<int> payablePaise = const Value.absent(),
                Value<int> totalCftNum = const Value.absent(),
                Value<int> totalCftDen = const Value.absent(),
                Value<String> taxPolicySnapshot = const Value.absent(),
                Value<String> loadingPolicySnapshot = const Value.absent(),
                Value<String> businessProfileSnapshot = const Value.absent(),
                Value<DateTime> finalizedAt = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
              }) => InvoicesCompanion(
                id: id,
                invoiceNumber: invoiceNumber,
                status: status,
                customerName: customerName,
                customerPhone: customerPhone,
                goodsSubtotalPaise: goodsSubtotalPaise,
                taxPaise: taxPaise,
                loadingPaise: loadingPaise,
                payablePaise: payablePaise,
                totalCftNum: totalCftNum,
                totalCftDen: totalCftDen,
                taxPolicySnapshot: taxPolicySnapshot,
                loadingPolicySnapshot: loadingPolicySnapshot,
                businessProfileSnapshot: businessProfileSnapshot,
                finalizedAt: finalizedAt,
                idempotencyKey: idempotencyKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String invoiceNumber,
                required InvoiceStatus status,
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                required int goodsSubtotalPaise,
                required int taxPaise,
                required int loadingPaise,
                required int payablePaise,
                required int totalCftNum,
                required int totalCftDen,
                required String taxPolicySnapshot,
                required String loadingPolicySnapshot,
                required String businessProfileSnapshot,
                required DateTime finalizedAt,
                required String idempotencyKey,
              }) => InvoicesCompanion.insert(
                id: id,
                invoiceNumber: invoiceNumber,
                status: status,
                customerName: customerName,
                customerPhone: customerPhone,
                goodsSubtotalPaise: goodsSubtotalPaise,
                taxPaise: taxPaise,
                loadingPaise: loadingPaise,
                payablePaise: payablePaise,
                totalCftNum: totalCftNum,
                totalCftDen: totalCftDen,
                taxPolicySnapshot: taxPolicySnapshot,
                loadingPolicySnapshot: loadingPolicySnapshot,
                businessProfileSnapshot: businessProfileSnapshot,
                finalizedAt: finalizedAt,
                idempotencyKey: idempotencyKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvoicesTable, InvoiceRow>(table),
                  $$InvoicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                stockMovementsRefs = false,
                draftOrdersRefs = false,
                invoiceLinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockMovementsRefs) db.stockMovements,
                    if (draftOrdersRefs) db.draftOrders,
                    if (invoiceLinesRefs) db.invoiceLines,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          InvoiceRow,
                          $InvoicesTable,
                          StockMovementRow
                        >(
                          currentTable: table,
                          referencedTable: $$InvoicesTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InvoicesTableReferences(
                                db,
                                table,
                                p0,
                              ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.invoiceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (draftOrdersRefs)
                        await $_getPrefetchedData<
                          InvoiceRow,
                          $InvoicesTable,
                          DraftOrderRow
                        >(
                          currentTable: table,
                          referencedTable: $$InvoicesTableReferences
                              ._draftOrdersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InvoicesTableReferences(
                                db,
                                table,
                                p0,
                              ).draftOrdersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.invoiceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (invoiceLinesRefs)
                        await $_getPrefetchedData<
                          InvoiceRow,
                          $InvoicesTable,
                          InvoiceLineRow
                        >(
                          currentTable: table,
                          referencedTable: $$InvoicesTableReferences
                              ._invoiceLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InvoicesTableReferences(
                                db,
                                table,
                                p0,
                              ).invoiceLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.invoiceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$InvoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoicesTable,
      InvoiceRow,
      $$InvoicesTableFilterComposer,
      $$InvoicesTableOrderingComposer,
      $$InvoicesTableAnnotationComposer,
      $$InvoicesTableCreateCompanionBuilder,
      $$InvoicesTableUpdateCompanionBuilder,
      (InvoiceRow, $$InvoicesTableReferences),
      InvoiceRow,
      PrefetchHooks Function({
        bool stockMovementsRefs,
        bool draftOrdersRefs,
        bool invoiceLinesRefs,
      })
    >;
typedef $$StockMovementsTableCreateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      required int stockItemId,
      required MovementType type,
      required int deltaPieces,
      required DateTime occurredAt,
      Value<int?> receiptEntryId,
      Value<int?> invoiceId,
      Value<String?> reason,
      required String idempotencyKey,
      required SyncState syncState,
    });
typedef $$StockMovementsTableUpdateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      Value<int> stockItemId,
      Value<MovementType> type,
      Value<int> deltaPieces,
      Value<DateTime> occurredAt,
      Value<int?> receiptEntryId,
      Value<int?> invoiceId,
      Value<String?> reason,
      Value<String> idempotencyKey,
      Value<SyncState> syncState,
    });

final class $$StockMovementsTableReferences
    extends
        BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovementRow> {
  $$StockMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockItemsTable _stockItemIdTable(_$AppDatabase db) => db.stockItems
      .createAlias('stock_movements__stock_item_id__stock_items__id');

  $$StockItemsTableProcessedTableManager get stockItemId {
    final $_column = $_itemColumn<int>('stock_item_id')!;

    final manager = $$StockItemsTableTableManager(
      $_db,
      $_db.stockItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stockItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReceiptEntriesTable _receiptEntryIdTable(_$AppDatabase db) => db
      .receiptEntries
      .createAlias('stock_movements__receipt_entry_id__receipt_entries__id');

  $$ReceiptEntriesTableProcessedTableManager? get receiptEntryId {
    final $_column = $_itemColumn<int>('receipt_entry_id');
    if ($_column == null) return null;
    final manager = $$ReceiptEntriesTableTableManager(
      $_db,
      $_db.receiptEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $InvoicesTable _invoiceIdTable(_$AppDatabase db) =>
      db.invoices.createAlias('stock_movements__invoice_id__invoices__id');

  $$InvoicesTableProcessedTableManager? get invoiceId {
    final $_column = $_itemColumn<int>('invoice_id');
    if ($_column == null) return null;
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_invoiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MovementType, MovementType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get deltaPieces => $composableBuilder(
    column: $table.deltaPieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncState, SyncState, int> get syncState =>
      $composableBuilder(
        column: $table.syncState,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$StockItemsTableFilterComposer get stockItemId {
    final $$StockItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableFilterComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptEntriesTableFilterComposer get receiptEntryId {
    final $$ReceiptEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptEntryId,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableFilterComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableFilterComposer get invoiceId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deltaPieces => $composableBuilder(
    column: $table.deltaPieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockItemsTableOrderingComposer get stockItemId {
    final $$StockItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableOrderingComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptEntriesTableOrderingComposer get receiptEntryId {
    final $$ReceiptEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptEntryId,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableOrderingComposer get invoiceId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MovementType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get deltaPieces => $composableBuilder(
    column: $table.deltaPieces,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncState, int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  $$StockItemsTableAnnotationComposer get stockItemId {
    final $$StockItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptEntriesTableAnnotationComposer get receiptEntryId {
    final $$ReceiptEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptEntryId,
      referencedTable: $db.receiptEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableAnnotationComposer get invoiceId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockMovementsTable,
          StockMovementRow,
          $$StockMovementsTableFilterComposer,
          $$StockMovementsTableOrderingComposer,
          $$StockMovementsTableAnnotationComposer,
          $$StockMovementsTableCreateCompanionBuilder,
          $$StockMovementsTableUpdateCompanionBuilder,
          (StockMovementRow, $$StockMovementsTableReferences),
          StockMovementRow,
          PrefetchHooks Function({
            bool stockItemId,
            bool receiptEntryId,
            bool invoiceId,
          })
        > {
  $$StockMovementsTableTableManager(
    _$AppDatabase db,
    $StockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> stockItemId = const Value.absent(),
                Value<MovementType> type = const Value.absent(),
                Value<int> deltaPieces = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int?> receiptEntryId = const Value.absent(),
                Value<int?> invoiceId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<SyncState> syncState = const Value.absent(),
              }) => StockMovementsCompanion(
                id: id,
                stockItemId: stockItemId,
                type: type,
                deltaPieces: deltaPieces,
                occurredAt: occurredAt,
                receiptEntryId: receiptEntryId,
                invoiceId: invoiceId,
                reason: reason,
                idempotencyKey: idempotencyKey,
                syncState: syncState,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int stockItemId,
                required MovementType type,
                required int deltaPieces,
                required DateTime occurredAt,
                Value<int?> receiptEntryId = const Value.absent(),
                Value<int?> invoiceId = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                required String idempotencyKey,
                required SyncState syncState,
              }) => StockMovementsCompanion.insert(
                id: id,
                stockItemId: stockItemId,
                type: type,
                deltaPieces: deltaPieces,
                occurredAt: occurredAt,
                receiptEntryId: receiptEntryId,
                invoiceId: invoiceId,
                reason: reason,
                idempotencyKey: idempotencyKey,
                syncState: syncState,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StockMovementsTable, StockMovementRow>(table),
                  $$StockMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                stockItemId = false,
                receiptEntryId = false,
                invoiceId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (stockItemId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.stockItemId,
                            referencedTable: $$StockMovementsTableReferences
                                ._stockItemIdTable(db),
                            referencedColumn: $$StockMovementsTableReferences
                                ._stockItemIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (receiptEntryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.receiptEntryId,
                            referencedTable: $$StockMovementsTableReferences
                                ._receiptEntryIdTable(db),
                            referencedColumn: $$StockMovementsTableReferences
                                ._receiptEntryIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (invoiceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.invoiceId,
                            referencedTable: $$StockMovementsTableReferences
                                ._invoiceIdTable(db),
                            referencedColumn: $$StockMovementsTableReferences
                                ._invoiceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$StockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockMovementsTable,
      StockMovementRow,
      $$StockMovementsTableFilterComposer,
      $$StockMovementsTableOrderingComposer,
      $$StockMovementsTableAnnotationComposer,
      $$StockMovementsTableCreateCompanionBuilder,
      $$StockMovementsTableUpdateCompanionBuilder,
      (StockMovementRow, $$StockMovementsTableReferences),
      StockMovementRow,
      PrefetchHooks Function({
        bool stockItemId,
        bool receiptEntryId,
        bool invoiceId,
      })
    >;
typedef $$PriceRatesTableCreateCompanionBuilder = PriceRatesCompanion Function({
  Value<int> id,
  required int varietyId,
  required int crossSectionId,
  Value<int?> rateNum,
  Value<int?> rateDen,
});
typedef $$PriceRatesTableUpdateCompanionBuilder = PriceRatesCompanion Function({
  Value<int> id,
  Value<int> varietyId,
  Value<int> crossSectionId,
  Value<int?> rateNum,
  Value<int?> rateDen,
});

final class $$PriceRatesTableReferences
    extends BaseReferences<_$AppDatabase, $PriceRatesTable, PriceRateRow> {
  $$PriceRatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WoodVarietiesTable _varietyIdTable(_$AppDatabase db) => db
      .woodVarieties
      .createAlias('price_rates__variety_id__wood_varieties__id');

  $$WoodVarietiesTableProcessedTableManager get varietyId {
    final $_column = $_itemColumn<int>('variety_id')!;

    final manager = $$WoodVarietiesTableTableManager(
      $_db,
      $_db.woodVarieties,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_varietyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CrossSectionsTable _crossSectionIdTable(_$AppDatabase db) => db
      .crossSections
      .createAlias('price_rates__cross_section_id__cross_sections__id');

  $$CrossSectionsTableProcessedTableManager get crossSectionId {
    final $_column = $_itemColumn<int>('cross_section_id')!;

    final manager = $$CrossSectionsTableTableManager(
      $_db,
      $_db.crossSections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_crossSectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PriceRatesTableFilterComposer
    extends Composer<_$AppDatabase, $PriceRatesTable> {
  $$PriceRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnFilters(column),
  );

  $$WoodVarietiesTableFilterComposer get varietyId {
    final $$WoodVarietiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableFilterComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableFilterComposer get crossSectionId {
    final $$CrossSectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableFilterComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PriceRatesTable> {
  $$PriceRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnOrderings(column),
  );

  $$WoodVarietiesTableOrderingComposer get varietyId {
    final $$WoodVarietiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableOrderingComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableOrderingComposer get crossSectionId {
    final $$CrossSectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableOrderingComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PriceRatesTable> {
  $$PriceRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get rateNum =>
      $composableBuilder(column: $table.rateNum, builder: (column) => column);

  GeneratedColumn<int> get rateDen =>
      $composableBuilder(column: $table.rateDen, builder: (column) => column);

  $$WoodVarietiesTableAnnotationComposer get varietyId {
    final $$WoodVarietiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableAnnotationComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableAnnotationComposer get crossSectionId {
    final $$CrossSectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceRatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PriceRatesTable,
          PriceRateRow,
          $$PriceRatesTableFilterComposer,
          $$PriceRatesTableOrderingComposer,
          $$PriceRatesTableAnnotationComposer,
          $$PriceRatesTableCreateCompanionBuilder,
          $$PriceRatesTableUpdateCompanionBuilder,
          (PriceRateRow, $$PriceRatesTableReferences),
          PriceRateRow,
          PrefetchHooks Function({bool varietyId, bool crossSectionId})
        > {
  $$PriceRatesTableTableManager(_$AppDatabase db, $PriceRatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> varietyId = const Value.absent(),
                Value<int> crossSectionId = const Value.absent(),
                Value<int?> rateNum = const Value.absent(),
                Value<int?> rateDen = const Value.absent(),
              }) => PriceRatesCompanion(
                id: id,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                rateNum: rateNum,
                rateDen: rateDen,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int varietyId,
                required int crossSectionId,
                Value<int?> rateNum = const Value.absent(),
                Value<int?> rateDen = const Value.absent(),
              }) => PriceRatesCompanion.insert(
                id: id,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                rateNum: rateNum,
                rateDen: rateDen,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PriceRatesTable, PriceRateRow>(table),
                  $$PriceRatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({varietyId = false, crossSectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (varietyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.varietyId,
                        referencedTable: $$PriceRatesTableReferences
                            ._varietyIdTable(db),
                        referencedColumn: $$PriceRatesTableReferences
                            ._varietyIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (crossSectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.crossSectionId,
                        referencedTable: $$PriceRatesTableReferences
                            ._crossSectionIdTable(db),
                        referencedColumn: $$PriceRatesTableReferences
                            ._crossSectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PriceRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PriceRatesTable,
      PriceRateRow,
      $$PriceRatesTableFilterComposer,
      $$PriceRatesTableOrderingComposer,
      $$PriceRatesTableAnnotationComposer,
      $$PriceRatesTableCreateCompanionBuilder,
      $$PriceRatesTableUpdateCompanionBuilder,
      (PriceRateRow, $$PriceRatesTableReferences),
      PriceRateRow,
      PrefetchHooks Function({bool varietyId, bool crossSectionId})
    >;
typedef $$DraftOrdersTableCreateCompanionBuilder =
    DraftOrdersCompanion Function({
      Value<int> id,
      required DraftStatus status,
      Value<String?> customerName,
      Value<String?> customerPhone,
      required DateTime createdAt,
      Value<String?> title,
      Value<DateTime> updatedAt,
      Value<int?> invoiceId,
    });
typedef $$DraftOrdersTableUpdateCompanionBuilder =
    DraftOrdersCompanion Function({
      Value<int> id,
      Value<DraftStatus> status,
      Value<String?> customerName,
      Value<String?> customerPhone,
      Value<DateTime> createdAt,
      Value<String?> title,
      Value<DateTime> updatedAt,
      Value<int?> invoiceId,
    });

final class $$DraftOrdersTableReferences
    extends BaseReferences<_$AppDatabase, $DraftOrdersTable, DraftOrderRow> {
  $$DraftOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InvoicesTable _invoiceIdTable(_$AppDatabase db) =>
      db.invoices.createAlias('draft_orders__invoice_id__invoices__id');

  $$InvoicesTableProcessedTableManager? get invoiceId {
    final $_column = $_itemColumn<int>('invoice_id');
    if ($_column == null) return null;
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_invoiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $DraftOrderRequestsTable,
    List<DraftOrderRequestRow>
  >
  _draftOrderRequestsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.draftOrderRequests,
        aliasName: 'draft_orders__id__draft_order_requests__draft_id',
      );

  $$DraftOrderRequestsTableProcessedTableManager get draftOrderRequestsRefs {
    final manager = $$DraftOrderRequestsTableTableManager(
      $_db,
      $_db.draftOrderRequests,
    ).filter((f) => f.draftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _draftOrderRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AllocationLinesTable, List<AllocationLineRow>>
  _allocationLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.allocationLines,
    aliasName: 'draft_orders__id__allocation_lines__draft_id',
  );

  $$AllocationLinesTableProcessedTableManager get allocationLinesRefs {
    final manager = $$AllocationLinesTableTableManager(
      $_db,
      $_db.allocationLines,
    ).filter((f) => f.draftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _allocationLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DraftOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $DraftOrdersTable> {
  $$DraftOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DraftStatus, DraftStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$InvoicesTableFilterComposer get invoiceId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> draftOrderRequestsRefs(
    Expression<bool> Function($$DraftOrderRequestsTableFilterComposer f) f,
  ) {
    final $$DraftOrderRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.draftOrderRequests,
      getReferencedColumn: (t) => t.draftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrderRequestsTableFilterComposer(
            $db: $db,
            $table: $db.draftOrderRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> allocationLinesRefs(
    Expression<bool> Function($$AllocationLinesTableFilterComposer f) f,
  ) {
    final $$AllocationLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationLines,
      getReferencedColumn: (t) => t.draftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationLinesTableFilterComposer(
            $db: $db,
            $table: $db.allocationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DraftOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftOrdersTable> {
  $$DraftOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$InvoicesTableOrderingComposer get invoiceId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftOrdersTable> {
  $$DraftOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DraftStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerPhone => $composableBuilder(
    column: $table.customerPhone,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$InvoicesTableAnnotationComposer get invoiceId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> draftOrderRequestsRefs<T extends Object>(
    Expression<T> Function($$DraftOrderRequestsTableAnnotationComposer a) f,
  ) {
    final $$DraftOrderRequestsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.draftOrderRequests,
          getReferencedColumn: (t) => t.draftId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DraftOrderRequestsTableAnnotationComposer(
                $db: $db,
                $table: $db.draftOrderRequests,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> allocationLinesRefs<T extends Object>(
    Expression<T> Function($$AllocationLinesTableAnnotationComposer a) f,
  ) {
    final $$AllocationLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationLines,
      getReferencedColumn: (t) => t.draftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.allocationLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DraftOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftOrdersTable,
          DraftOrderRow,
          $$DraftOrdersTableFilterComposer,
          $$DraftOrdersTableOrderingComposer,
          $$DraftOrdersTableAnnotationComposer,
          $$DraftOrdersTableCreateCompanionBuilder,
          $$DraftOrdersTableUpdateCompanionBuilder,
          (DraftOrderRow, $$DraftOrdersTableReferences),
          DraftOrderRow,
          PrefetchHooks Function({
            bool invoiceId,
            bool draftOrderRequestsRefs,
            bool allocationLinesRefs,
          })
        > {
  $$DraftOrdersTableTableManager(_$AppDatabase db, $DraftOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DraftStatus> status = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int?> invoiceId = const Value.absent(),
              }) => DraftOrdersCompanion(
                id: id,
                status: status,
                customerName: customerName,
                customerPhone: customerPhone,
                createdAt: createdAt,
                title: title,
                updatedAt: updatedAt,
                invoiceId: invoiceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DraftStatus status,
                Value<String?> customerName = const Value.absent(),
                Value<String?> customerPhone = const Value.absent(),
                required DateTime createdAt,
                Value<String?> title = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int?> invoiceId = const Value.absent(),
              }) => DraftOrdersCompanion.insert(
                id: id,
                status: status,
                customerName: customerName,
                customerPhone: customerPhone,
                createdAt: createdAt,
                title: title,
                updatedAt: updatedAt,
                invoiceId: invoiceId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftOrdersTable, DraftOrderRow>(table),
                  $$DraftOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                invoiceId = false,
                draftOrderRequestsRefs = false,
                allocationLinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (draftOrderRequestsRefs) db.draftOrderRequests,
                    if (allocationLinesRefs) db.allocationLines,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (invoiceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.invoiceId,
                            referencedTable: $$DraftOrdersTableReferences
                                ._invoiceIdTable(db),
                            referencedColumn: $$DraftOrdersTableReferences
                                ._invoiceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (draftOrderRequestsRefs)
                        await $_getPrefetchedData<
                          DraftOrderRow,
                          $DraftOrdersTable,
                          DraftOrderRequestRow
                        >(
                          currentTable: table,
                          referencedTable: $$DraftOrdersTableReferences
                              ._draftOrderRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DraftOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).draftOrderRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.draftId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (allocationLinesRefs)
                        await $_getPrefetchedData<
                          DraftOrderRow,
                          $DraftOrdersTable,
                          AllocationLineRow
                        >(
                          currentTable: table,
                          referencedTable: $$DraftOrdersTableReferences
                              ._allocationLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DraftOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).allocationLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.draftId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DraftOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftOrdersTable,
      DraftOrderRow,
      $$DraftOrdersTableFilterComposer,
      $$DraftOrdersTableOrderingComposer,
      $$DraftOrdersTableAnnotationComposer,
      $$DraftOrdersTableCreateCompanionBuilder,
      $$DraftOrdersTableUpdateCompanionBuilder,
      (DraftOrderRow, $$DraftOrdersTableReferences),
      DraftOrderRow,
      PrefetchHooks Function({
        bool invoiceId,
        bool draftOrderRequestsRefs,
        bool allocationLinesRefs,
      })
    >;
typedef $$DraftOrderRequestsTableCreateCompanionBuilder =
    DraftOrderRequestsCompanion Function({
      Value<int> id,
      required int draftId,
      required RequestType requestType,
      required int varietyId,
      Value<int?> crossSectionId,
      Value<CategoryKind?> category,
      Value<int?> lengthFt,
      Value<int?> targetCftNum,
      Value<int?> targetCftDen,
      Value<int?> qty,
    });
typedef $$DraftOrderRequestsTableUpdateCompanionBuilder =
    DraftOrderRequestsCompanion Function({
      Value<int> id,
      Value<int> draftId,
      Value<RequestType> requestType,
      Value<int> varietyId,
      Value<int?> crossSectionId,
      Value<CategoryKind?> category,
      Value<int?> lengthFt,
      Value<int?> targetCftNum,
      Value<int?> targetCftDen,
      Value<int?> qty,
    });

final class $$DraftOrderRequestsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DraftOrderRequestsTable,
          DraftOrderRequestRow
        > {
  $$DraftOrderRequestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DraftOrdersTable _draftIdTable(_$AppDatabase db) => db.draftOrders
      .createAlias('draft_order_requests__draft_id__draft_orders__id');

  $$DraftOrdersTableProcessedTableManager get draftId {
    final $_column = $_itemColumn<int>('draft_id')!;

    final manager = $$DraftOrdersTableTableManager(
      $_db,
      $_db.draftOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_draftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WoodVarietiesTable _varietyIdTable(_$AppDatabase db) => db
      .woodVarieties
      .createAlias('draft_order_requests__variety_id__wood_varieties__id');

  $$WoodVarietiesTableProcessedTableManager get varietyId {
    final $_column = $_itemColumn<int>('variety_id')!;

    final manager = $$WoodVarietiesTableTableManager(
      $_db,
      $_db.woodVarieties,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_varietyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CrossSectionsTable _crossSectionIdTable(_$AppDatabase db) =>
      db.crossSections.createAlias(
        'draft_order_requests__cross_section_id__cross_sections__id',
      );

  $$CrossSectionsTableProcessedTableManager? get crossSectionId {
    final $_column = $_itemColumn<int>('cross_section_id');
    if ($_column == null) return null;
    final manager = $$CrossSectionsTableTableManager(
      $_db,
      $_db.crossSections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_crossSectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DraftOrderRequestsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftOrderRequestsTable> {
  $$DraftOrderRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RequestType, RequestType, int>
  get requestType => $composableBuilder(
    column: $table.requestType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind?, CategoryKind, int>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCftNum => $composableBuilder(
    column: $table.targetCftNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCftDen => $composableBuilder(
    column: $table.targetCftDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  $$DraftOrdersTableFilterComposer get draftId {
    final $$DraftOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableFilterComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WoodVarietiesTableFilterComposer get varietyId {
    final $$WoodVarietiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableFilterComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableFilterComposer get crossSectionId {
    final $$CrossSectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableFilterComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftOrderRequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftOrderRequestsTable> {
  $$DraftOrderRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestType => $composableBuilder(
    column: $table.requestType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCftNum => $composableBuilder(
    column: $table.targetCftNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCftDen => $composableBuilder(
    column: $table.targetCftDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  $$DraftOrdersTableOrderingComposer get draftId {
    final $$DraftOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WoodVarietiesTableOrderingComposer get varietyId {
    final $$WoodVarietiesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableOrderingComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableOrderingComposer get crossSectionId {
    final $$CrossSectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableOrderingComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftOrderRequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftOrderRequestsTable> {
  $$DraftOrderRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RequestType, int> get requestType =>
      $composableBuilder(
        column: $table.requestType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CategoryKind?, int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get lengthFt =>
      $composableBuilder(column: $table.lengthFt, builder: (column) => column);

  GeneratedColumn<int> get targetCftNum => $composableBuilder(
    column: $table.targetCftNum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetCftDen => $composableBuilder(
    column: $table.targetCftDen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  $$DraftOrdersTableAnnotationComposer get draftId {
    final $$DraftOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WoodVarietiesTableAnnotationComposer get varietyId {
    final $$WoodVarietiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.varietyId,
      referencedTable: $db.woodVarieties,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WoodVarietiesTableAnnotationComposer(
            $db: $db,
            $table: $db.woodVarieties,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CrossSectionsTableAnnotationComposer get crossSectionId {
    final $$CrossSectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.crossSectionId,
      referencedTable: $db.crossSections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrossSectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.crossSections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftOrderRequestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftOrderRequestsTable,
          DraftOrderRequestRow,
          $$DraftOrderRequestsTableFilterComposer,
          $$DraftOrderRequestsTableOrderingComposer,
          $$DraftOrderRequestsTableAnnotationComposer,
          $$DraftOrderRequestsTableCreateCompanionBuilder,
          $$DraftOrderRequestsTableUpdateCompanionBuilder,
          (DraftOrderRequestRow, $$DraftOrderRequestsTableReferences),
          DraftOrderRequestRow,
          PrefetchHooks Function({
            bool draftId,
            bool varietyId,
            bool crossSectionId,
          })
        > {
  $$DraftOrderRequestsTableTableManager(
    _$AppDatabase db,
    $DraftOrderRequestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftOrderRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftOrderRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftOrderRequestsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> draftId = const Value.absent(),
                Value<RequestType> requestType = const Value.absent(),
                Value<int> varietyId = const Value.absent(),
                Value<int?> crossSectionId = const Value.absent(),
                Value<CategoryKind?> category = const Value.absent(),
                Value<int?> lengthFt = const Value.absent(),
                Value<int?> targetCftNum = const Value.absent(),
                Value<int?> targetCftDen = const Value.absent(),
                Value<int?> qty = const Value.absent(),
              }) => DraftOrderRequestsCompanion(
                id: id,
                draftId: draftId,
                requestType: requestType,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                category: category,
                lengthFt: lengthFt,
                targetCftNum: targetCftNum,
                targetCftDen: targetCftDen,
                qty: qty,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int draftId,
                required RequestType requestType,
                required int varietyId,
                Value<int?> crossSectionId = const Value.absent(),
                Value<CategoryKind?> category = const Value.absent(),
                Value<int?> lengthFt = const Value.absent(),
                Value<int?> targetCftNum = const Value.absent(),
                Value<int?> targetCftDen = const Value.absent(),
                Value<int?> qty = const Value.absent(),
              }) => DraftOrderRequestsCompanion.insert(
                id: id,
                draftId: draftId,
                requestType: requestType,
                varietyId: varietyId,
                crossSectionId: crossSectionId,
                category: category,
                lengthFt: lengthFt,
                targetCftNum: targetCftNum,
                targetCftDen: targetCftDen,
                qty: qty,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftOrderRequestsTable, DraftOrderRequestRow>(
                    table,
                  ),
                  $$DraftOrderRequestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({draftId = false, varietyId = false, crossSectionId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (draftId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.draftId,
                            referencedTable: $$DraftOrderRequestsTableReferences
                                ._draftIdTable(db),
                            referencedColumn:
                                $$DraftOrderRequestsTableReferences
                                    ._draftIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (varietyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.varietyId,
                            referencedTable: $$DraftOrderRequestsTableReferences
                                ._varietyIdTable(db),
                            referencedColumn:
                                $$DraftOrderRequestsTableReferences
                                    ._varietyIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (crossSectionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.crossSectionId,
                            referencedTable: $$DraftOrderRequestsTableReferences
                                ._crossSectionIdTable(db),
                            referencedColumn:
                                $$DraftOrderRequestsTableReferences
                                    ._crossSectionIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$DraftOrderRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftOrderRequestsTable,
      DraftOrderRequestRow,
      $$DraftOrderRequestsTableFilterComposer,
      $$DraftOrderRequestsTableOrderingComposer,
      $$DraftOrderRequestsTableAnnotationComposer,
      $$DraftOrderRequestsTableCreateCompanionBuilder,
      $$DraftOrderRequestsTableUpdateCompanionBuilder,
      (DraftOrderRequestRow, $$DraftOrderRequestsTableReferences),
      DraftOrderRequestRow,
      PrefetchHooks Function({
        bool draftId,
        bool varietyId,
        bool crossSectionId,
      })
    >;
typedef $$AllocationLinesTableCreateCompanionBuilder =
    AllocationLinesCompanion Function({
      Value<int> id,
      required int draftId,
      required int stockItemId,
      required int qtyUnits,
      required InputUnit unit,
      required int pieces,
      required int exactCftNum,
      required int exactCftDen,
      Value<bool> isPartial,
      Value<int> shortagePieces,
    });
typedef $$AllocationLinesTableUpdateCompanionBuilder =
    AllocationLinesCompanion Function({
      Value<int> id,
      Value<int> draftId,
      Value<int> stockItemId,
      Value<int> qtyUnits,
      Value<InputUnit> unit,
      Value<int> pieces,
      Value<int> exactCftNum,
      Value<int> exactCftDen,
      Value<bool> isPartial,
      Value<int> shortagePieces,
    });

final class $$AllocationLinesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AllocationLinesTable,
          AllocationLineRow
        > {
  $$AllocationLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DraftOrdersTable _draftIdTable(_$AppDatabase db) => db.draftOrders
      .createAlias('allocation_lines__draft_id__draft_orders__id');

  $$DraftOrdersTableProcessedTableManager get draftId {
    final $_column = $_itemColumn<int>('draft_id')!;

    final manager = $$DraftOrdersTableTableManager(
      $_db,
      $_db.draftOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_draftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StockItemsTable _stockItemIdTable(_$AppDatabase db) => db.stockItems
      .createAlias('allocation_lines__stock_item_id__stock_items__id');

  $$StockItemsTableProcessedTableManager get stockItemId {
    final $_column = $_itemColumn<int>('stock_item_id')!;

    final manager = $$StockItemsTableTableManager(
      $_db,
      $_db.stockItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stockItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AllocationLinesTableFilterComposer
    extends Composer<_$AppDatabase, $AllocationLinesTable> {
  $$AllocationLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qtyUnits => $composableBuilder(
    column: $table.qtyUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InputUnit, InputUnit, int> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPartial => $composableBuilder(
    column: $table.isPartial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shortagePieces => $composableBuilder(
    column: $table.shortagePieces,
    builder: (column) => ColumnFilters(column),
  );

  $$DraftOrdersTableFilterComposer get draftId {
    final $$DraftOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableFilterComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableFilterComposer get stockItemId {
    final $$StockItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableFilterComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $AllocationLinesTable> {
  $$AllocationLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qtyUnits => $composableBuilder(
    column: $table.qtyUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPartial => $composableBuilder(
    column: $table.isPartial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shortagePieces => $composableBuilder(
    column: $table.shortagePieces,
    builder: (column) => ColumnOrderings(column),
  );

  $$DraftOrdersTableOrderingComposer get draftId {
    final $$DraftOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableOrderingComposer get stockItemId {
    final $$StockItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableOrderingComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllocationLinesTable> {
  $$AllocationLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qtyUnits =>
      $composableBuilder(column: $table.qtyUnits, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InputUnit, int> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get pieces =>
      $composableBuilder(column: $table.pieces, builder: (column) => column);

  GeneratedColumn<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPartial =>
      $composableBuilder(column: $table.isPartial, builder: (column) => column);

  GeneratedColumn<int> get shortagePieces => $composableBuilder(
    column: $table.shortagePieces,
    builder: (column) => column,
  );

  $$DraftOrdersTableAnnotationComposer get draftId {
    final $$DraftOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.draftOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.draftOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StockItemsTableAnnotationComposer get stockItemId {
    final $$StockItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stockItemId,
      referencedTable: $db.stockItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AllocationLinesTable,
          AllocationLineRow,
          $$AllocationLinesTableFilterComposer,
          $$AllocationLinesTableOrderingComposer,
          $$AllocationLinesTableAnnotationComposer,
          $$AllocationLinesTableCreateCompanionBuilder,
          $$AllocationLinesTableUpdateCompanionBuilder,
          (AllocationLineRow, $$AllocationLinesTableReferences),
          AllocationLineRow,
          PrefetchHooks Function({bool draftId, bool stockItemId})
        > {
  $$AllocationLinesTableTableManager(
    _$AppDatabase db,
    $AllocationLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllocationLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllocationLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AllocationLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> draftId = const Value.absent(),
                Value<int> stockItemId = const Value.absent(),
                Value<int> qtyUnits = const Value.absent(),
                Value<InputUnit> unit = const Value.absent(),
                Value<int> pieces = const Value.absent(),
                Value<int> exactCftNum = const Value.absent(),
                Value<int> exactCftDen = const Value.absent(),
                Value<bool> isPartial = const Value.absent(),
                Value<int> shortagePieces = const Value.absent(),
              }) => AllocationLinesCompanion(
                id: id,
                draftId: draftId,
                stockItemId: stockItemId,
                qtyUnits: qtyUnits,
                unit: unit,
                pieces: pieces,
                exactCftNum: exactCftNum,
                exactCftDen: exactCftDen,
                isPartial: isPartial,
                shortagePieces: shortagePieces,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int draftId,
                required int stockItemId,
                required int qtyUnits,
                required InputUnit unit,
                required int pieces,
                required int exactCftNum,
                required int exactCftDen,
                Value<bool> isPartial = const Value.absent(),
                Value<int> shortagePieces = const Value.absent(),
              }) => AllocationLinesCompanion.insert(
                id: id,
                draftId: draftId,
                stockItemId: stockItemId,
                qtyUnits: qtyUnits,
                unit: unit,
                pieces: pieces,
                exactCftNum: exactCftNum,
                exactCftDen: exactCftDen,
                isPartial: isPartial,
                shortagePieces: shortagePieces,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AllocationLinesTable, AllocationLineRow>(table),
                  $$AllocationLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({draftId = false, stockItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (draftId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.draftId,
                        referencedTable: $$AllocationLinesTableReferences
                            ._draftIdTable(db),
                        referencedColumn: $$AllocationLinesTableReferences
                            ._draftIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (stockItemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.stockItemId,
                        referencedTable: $$AllocationLinesTableReferences
                            ._stockItemIdTable(db),
                        referencedColumn: $$AllocationLinesTableReferences
                            ._stockItemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AllocationLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AllocationLinesTable,
      AllocationLineRow,
      $$AllocationLinesTableFilterComposer,
      $$AllocationLinesTableOrderingComposer,
      $$AllocationLinesTableAnnotationComposer,
      $$AllocationLinesTableCreateCompanionBuilder,
      $$AllocationLinesTableUpdateCompanionBuilder,
      (AllocationLineRow, $$AllocationLinesTableReferences),
      AllocationLineRow,
      PrefetchHooks Function({bool draftId, bool stockItemId})
    >;
typedef $$InvoiceLinesTableCreateCompanionBuilder =
    InvoiceLinesCompanion Function({
      Value<int> id,
      required int invoiceId,
      required String varietyName,
      required String crossSectionLabel,
      required int lengthFt,
      required int pieces,
      required int exactCftNum,
      required int exactCftDen,
      required int rateNum,
      required int rateDen,
      required int lineAmountPaise,
    });
typedef $$InvoiceLinesTableUpdateCompanionBuilder =
    InvoiceLinesCompanion Function({
      Value<int> id,
      Value<int> invoiceId,
      Value<String> varietyName,
      Value<String> crossSectionLabel,
      Value<int> lengthFt,
      Value<int> pieces,
      Value<int> exactCftNum,
      Value<int> exactCftDen,
      Value<int> rateNum,
      Value<int> rateDen,
      Value<int> lineAmountPaise,
    });

final class $$InvoiceLinesTableReferences
    extends BaseReferences<_$AppDatabase, $InvoiceLinesTable, InvoiceLineRow> {
  $$InvoiceLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InvoicesTable _invoiceIdTable(_$AppDatabase db) =>
      db.invoices.createAlias('invoice_lines__invoice_id__invoices__id');

  $$InvoicesTableProcessedTableManager get invoiceId {
    final $_column = $_itemColumn<int>('invoice_id')!;

    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_invoiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InvoiceLinesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get varietyName => $composableBuilder(
    column: $table.varietyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get crossSectionLabel => $composableBuilder(
    column: $table.crossSectionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineAmountPaise => $composableBuilder(
    column: $table.lineAmountPaise,
    builder: (column) => ColumnFilters(column),
  );

  $$InvoicesTableFilterComposer get invoiceId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get varietyName => $composableBuilder(
    column: $table.varietyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get crossSectionLabel => $composableBuilder(
    column: $table.crossSectionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lengthFt => $composableBuilder(
    column: $table.lengthFt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineAmountPaise => $composableBuilder(
    column: $table.lineAmountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  $$InvoicesTableOrderingComposer get invoiceId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get varietyName => $composableBuilder(
    column: $table.varietyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get crossSectionLabel => $composableBuilder(
    column: $table.crossSectionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lengthFt =>
      $composableBuilder(column: $table.lengthFt, builder: (column) => column);

  GeneratedColumn<int> get pieces =>
      $composableBuilder(column: $table.pieces, builder: (column) => column);

  GeneratedColumn<int> get exactCftNum => $composableBuilder(
    column: $table.exactCftNum,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exactCftDen => $composableBuilder(
    column: $table.exactCftDen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateNum =>
      $composableBuilder(column: $table.rateNum, builder: (column) => column);

  GeneratedColumn<int> get rateDen =>
      $composableBuilder(column: $table.rateDen, builder: (column) => column);

  GeneratedColumn<int> get lineAmountPaise => $composableBuilder(
    column: $table.lineAmountPaise,
    builder: (column) => column,
  );

  $$InvoicesTableAnnotationComposer get invoiceId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoiceLinesTable,
          InvoiceLineRow,
          $$InvoiceLinesTableFilterComposer,
          $$InvoiceLinesTableOrderingComposer,
          $$InvoiceLinesTableAnnotationComposer,
          $$InvoiceLinesTableCreateCompanionBuilder,
          $$InvoiceLinesTableUpdateCompanionBuilder,
          (InvoiceLineRow, $$InvoiceLinesTableReferences),
          InvoiceLineRow,
          PrefetchHooks Function({bool invoiceId})
        > {
  $$InvoiceLinesTableTableManager(_$AppDatabase db, $InvoiceLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> invoiceId = const Value.absent(),
                Value<String> varietyName = const Value.absent(),
                Value<String> crossSectionLabel = const Value.absent(),
                Value<int> lengthFt = const Value.absent(),
                Value<int> pieces = const Value.absent(),
                Value<int> exactCftNum = const Value.absent(),
                Value<int> exactCftDen = const Value.absent(),
                Value<int> rateNum = const Value.absent(),
                Value<int> rateDen = const Value.absent(),
                Value<int> lineAmountPaise = const Value.absent(),
              }) => InvoiceLinesCompanion(
                id: id,
                invoiceId: invoiceId,
                varietyName: varietyName,
                crossSectionLabel: crossSectionLabel,
                lengthFt: lengthFt,
                pieces: pieces,
                exactCftNum: exactCftNum,
                exactCftDen: exactCftDen,
                rateNum: rateNum,
                rateDen: rateDen,
                lineAmountPaise: lineAmountPaise,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int invoiceId,
                required String varietyName,
                required String crossSectionLabel,
                required int lengthFt,
                required int pieces,
                required int exactCftNum,
                required int exactCftDen,
                required int rateNum,
                required int rateDen,
                required int lineAmountPaise,
              }) => InvoiceLinesCompanion.insert(
                id: id,
                invoiceId: invoiceId,
                varietyName: varietyName,
                crossSectionLabel: crossSectionLabel,
                lengthFt: lengthFt,
                pieces: pieces,
                exactCftNum: exactCftNum,
                exactCftDen: exactCftDen,
                rateNum: rateNum,
                rateDen: rateDen,
                lineAmountPaise: lineAmountPaise,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvoiceLinesTable, InvoiceLineRow>(table),
                  $$InvoiceLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({invoiceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (invoiceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.invoiceId,
                        referencedTable: $$InvoiceLinesTableReferences
                            ._invoiceIdTable(db),
                        referencedColumn: $$InvoiceLinesTableReferences
                            ._invoiceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InvoiceLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoiceLinesTable,
      InvoiceLineRow,
      $$InvoiceLinesTableFilterComposer,
      $$InvoiceLinesTableOrderingComposer,
      $$InvoiceLinesTableAnnotationComposer,
      $$InvoiceLinesTableCreateCompanionBuilder,
      $$InvoiceLinesTableUpdateCompanionBuilder,
      (InvoiceLineRow, $$InvoiceLinesTableReferences),
      InvoiceLineRow,
      PrefetchHooks Function({bool invoiceId})
    >;
typedef $$BusinessSettingsTableCreateCompanionBuilder =
    BusinessSettingsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> address,
      Value<String> phone,
      Value<Uint8List?> logo,
      Value<String?> gstin,
      Value<String> invoicePrefix,
    });
typedef $$BusinessSettingsTableUpdateCompanionBuilder =
    BusinessSettingsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> address,
      Value<String> phone,
      Value<Uint8List?> logo,
      Value<String?> gstin,
      Value<String> invoicePrefix,
    });

class $$BusinessSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BusinessSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableAnnotationComposer({
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

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<Uint8List> get logo =>
      $composableBuilder(column: $table.logo, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => column,
  );
}

class $$BusinessSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BusinessSettingsTable,
          BusinessSettingsRow,
          $$BusinessSettingsTableFilterComposer,
          $$BusinessSettingsTableOrderingComposer,
          $$BusinessSettingsTableAnnotationComposer,
          $$BusinessSettingsTableCreateCompanionBuilder,
          $$BusinessSettingsTableUpdateCompanionBuilder,
          (
            BusinessSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $BusinessSettingsTable,
              BusinessSettingsRow
            >,
          ),
          BusinessSettingsRow,
          PrefetchHooks Function()
        > {
  $$BusinessSettingsTableTableManager(
    _$AppDatabase db,
    $BusinessSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<Uint8List?> logo = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String> invoicePrefix = const Value.absent(),
              }) => BusinessSettingsCompanion(
                id: id,
                name: name,
                address: address,
                phone: phone,
                logo: logo,
                gstin: gstin,
                invoicePrefix: invoicePrefix,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<Uint8List?> logo = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String> invoicePrefix = const Value.absent(),
              }) => BusinessSettingsCompanion.insert(
                id: id,
                name: name,
                address: address,
                phone: phone,
                logo: logo,
                gstin: gstin,
                invoicePrefix: invoicePrefix,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BusinessSettingsTable, BusinessSettingsRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $BusinessSettingsTable,
                    BusinessSettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BusinessSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BusinessSettingsTable,
      BusinessSettingsRow,
      $$BusinessSettingsTableFilterComposer,
      $$BusinessSettingsTableOrderingComposer,
      $$BusinessSettingsTableAnnotationComposer,
      $$BusinessSettingsTableCreateCompanionBuilder,
      $$BusinessSettingsTableUpdateCompanionBuilder,
      (
        BusinessSettingsRow,
        BaseReferences<
          _$AppDatabase,
          $BusinessSettingsTable,
          BusinessSettingsRow
        >,
      ),
      BusinessSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$AllocationPoliciesTableCreateCompanionBuilder =
    AllocationPoliciesCompanion Function({
      Value<int> id,
      Value<bool> allow89ftFallback,
      Value<int> reaperSharePreferred,
      Value<int> reaperShareMid,
      Value<int> reaperShareLow,
    });
typedef $$AllocationPoliciesTableUpdateCompanionBuilder =
    AllocationPoliciesCompanion Function({
      Value<int> id,
      Value<bool> allow89ftFallback,
      Value<int> reaperSharePreferred,
      Value<int> reaperShareMid,
      Value<int> reaperShareLow,
    });

class $$AllocationPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $AllocationPoliciesTable> {
  $$AllocationPoliciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allow89ftFallback => $composableBuilder(
    column: $table.allow89ftFallback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reaperSharePreferred => $composableBuilder(
    column: $table.reaperSharePreferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reaperShareMid => $composableBuilder(
    column: $table.reaperShareMid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reaperShareLow => $composableBuilder(
    column: $table.reaperShareLow,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AllocationPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $AllocationPoliciesTable> {
  $$AllocationPoliciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allow89ftFallback => $composableBuilder(
    column: $table.allow89ftFallback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reaperSharePreferred => $composableBuilder(
    column: $table.reaperSharePreferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reaperShareMid => $composableBuilder(
    column: $table.reaperShareMid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reaperShareLow => $composableBuilder(
    column: $table.reaperShareLow,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AllocationPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllocationPoliciesTable> {
  $$AllocationPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get allow89ftFallback => $composableBuilder(
    column: $table.allow89ftFallback,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reaperSharePreferred => $composableBuilder(
    column: $table.reaperSharePreferred,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reaperShareMid => $composableBuilder(
    column: $table.reaperShareMid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reaperShareLow => $composableBuilder(
    column: $table.reaperShareLow,
    builder: (column) => column,
  );
}

class $$AllocationPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AllocationPoliciesTable,
          AllocationPolicyRow,
          $$AllocationPoliciesTableFilterComposer,
          $$AllocationPoliciesTableOrderingComposer,
          $$AllocationPoliciesTableAnnotationComposer,
          $$AllocationPoliciesTableCreateCompanionBuilder,
          $$AllocationPoliciesTableUpdateCompanionBuilder,
          (
            AllocationPolicyRow,
            BaseReferences<
              _$AppDatabase,
              $AllocationPoliciesTable,
              AllocationPolicyRow
            >,
          ),
          AllocationPolicyRow,
          PrefetchHooks Function()
        > {
  $$AllocationPoliciesTableTableManager(
    _$AppDatabase db,
    $AllocationPoliciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllocationPoliciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllocationPoliciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AllocationPoliciesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> allow89ftFallback = const Value.absent(),
                Value<int> reaperSharePreferred = const Value.absent(),
                Value<int> reaperShareMid = const Value.absent(),
                Value<int> reaperShareLow = const Value.absent(),
              }) => AllocationPoliciesCompanion(
                id: id,
                allow89ftFallback: allow89ftFallback,
                reaperSharePreferred: reaperSharePreferred,
                reaperShareMid: reaperShareMid,
                reaperShareLow: reaperShareLow,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> allow89ftFallback = const Value.absent(),
                Value<int> reaperSharePreferred = const Value.absent(),
                Value<int> reaperShareMid = const Value.absent(),
                Value<int> reaperShareLow = const Value.absent(),
              }) => AllocationPoliciesCompanion.insert(
                id: id,
                allow89ftFallback: allow89ftFallback,
                reaperSharePreferred: reaperSharePreferred,
                reaperShareMid: reaperShareMid,
                reaperShareLow: reaperShareLow,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AllocationPoliciesTable, AllocationPolicyRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AllocationPoliciesTable,
                    AllocationPolicyRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AllocationPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AllocationPoliciesTable,
      AllocationPolicyRow,
      $$AllocationPoliciesTableFilterComposer,
      $$AllocationPoliciesTableOrderingComposer,
      $$AllocationPoliciesTableAnnotationComposer,
      $$AllocationPoliciesTableCreateCompanionBuilder,
      $$AllocationPoliciesTableUpdateCompanionBuilder,
      (
        AllocationPolicyRow,
        BaseReferences<
          _$AppDatabase,
          $AllocationPoliciesTable,
          AllocationPolicyRow
        >,
      ),
      AllocationPolicyRow,
      PrefetchHooks Function()
    >;
typedef $$TaxPoliciesTableCreateCompanionBuilder =
    TaxPoliciesCompanion Function({
      Value<int> id,
      Value<TaxMode> mode,
      Value<int> rateNum,
      Value<int> rateDen,
      Value<String> label,
    });
typedef $$TaxPoliciesTableUpdateCompanionBuilder =
    TaxPoliciesCompanion Function({
      Value<int> id,
      Value<TaxMode> mode,
      Value<int> rateNum,
      Value<int> rateDen,
      Value<String> label,
    });

class $$TaxPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $TaxPoliciesTable> {
  $$TaxPoliciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaxMode, TaxMode, int> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaxPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaxPoliciesTable> {
  $$TaxPoliciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateNum => $composableBuilder(
    column: $table.rateNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateDen => $composableBuilder(
    column: $table.rateDen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaxPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaxPoliciesTable> {
  $$TaxPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaxMode, int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get rateNum =>
      $composableBuilder(column: $table.rateNum, builder: (column) => column);

  GeneratedColumn<int> get rateDen =>
      $composableBuilder(column: $table.rateDen, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$TaxPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaxPoliciesTable,
          TaxPolicyRow,
          $$TaxPoliciesTableFilterComposer,
          $$TaxPoliciesTableOrderingComposer,
          $$TaxPoliciesTableAnnotationComposer,
          $$TaxPoliciesTableCreateCompanionBuilder,
          $$TaxPoliciesTableUpdateCompanionBuilder,
          (
            TaxPolicyRow,
            BaseReferences<_$AppDatabase, $TaxPoliciesTable, TaxPolicyRow>,
          ),
          TaxPolicyRow,
          PrefetchHooks Function()
        > {
  $$TaxPoliciesTableTableManager(_$AppDatabase db, $TaxPoliciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaxPoliciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaxPoliciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaxPoliciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TaxMode> mode = const Value.absent(),
                Value<int> rateNum = const Value.absent(),
                Value<int> rateDen = const Value.absent(),
                Value<String> label = const Value.absent(),
              }) => TaxPoliciesCompanion(
                id: id,
                mode: mode,
                rateNum: rateNum,
                rateDen: rateDen,
                label: label,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TaxMode> mode = const Value.absent(),
                Value<int> rateNum = const Value.absent(),
                Value<int> rateDen = const Value.absent(),
                Value<String> label = const Value.absent(),
              }) => TaxPoliciesCompanion.insert(
                id: id,
                mode: mode,
                rateNum: rateNum,
                rateDen: rateDen,
                label: label,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaxPoliciesTable, TaxPolicyRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TaxPoliciesTable,
                    TaxPolicyRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaxPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaxPoliciesTable,
      TaxPolicyRow,
      $$TaxPoliciesTableFilterComposer,
      $$TaxPoliciesTableOrderingComposer,
      $$TaxPoliciesTableAnnotationComposer,
      $$TaxPoliciesTableCreateCompanionBuilder,
      $$TaxPoliciesTableUpdateCompanionBuilder,
      (
        TaxPolicyRow,
        BaseReferences<_$AppDatabase, $TaxPoliciesTable, TaxPolicyRow>,
      ),
      TaxPolicyRow,
      PrefetchHooks Function()
    >;
typedef $$LoadingPoliciesTableCreateCompanionBuilder =
    LoadingPoliciesCompanion Function({
      Value<int> id,
      Value<int> lowPaise,
      Value<int> highPaise,
      Value<int> thresholdCft,
      Value<bool> thresholdInclusive,
    });
typedef $$LoadingPoliciesTableUpdateCompanionBuilder =
    LoadingPoliciesCompanion Function({
      Value<int> id,
      Value<int> lowPaise,
      Value<int> highPaise,
      Value<int> thresholdCft,
      Value<bool> thresholdInclusive,
    });

class $$LoadingPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $LoadingPoliciesTable> {
  $$LoadingPoliciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lowPaise => $composableBuilder(
    column: $table.lowPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highPaise => $composableBuilder(
    column: $table.highPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thresholdCft => $composableBuilder(
    column: $table.thresholdCft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get thresholdInclusive => $composableBuilder(
    column: $table.thresholdInclusive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LoadingPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $LoadingPoliciesTable> {
  $$LoadingPoliciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lowPaise => $composableBuilder(
    column: $table.lowPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highPaise => $composableBuilder(
    column: $table.highPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thresholdCft => $composableBuilder(
    column: $table.thresholdCft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get thresholdInclusive => $composableBuilder(
    column: $table.thresholdInclusive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LoadingPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoadingPoliciesTable> {
  $$LoadingPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lowPaise =>
      $composableBuilder(column: $table.lowPaise, builder: (column) => column);

  GeneratedColumn<int> get highPaise =>
      $composableBuilder(column: $table.highPaise, builder: (column) => column);

  GeneratedColumn<int> get thresholdCft => $composableBuilder(
    column: $table.thresholdCft,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get thresholdInclusive => $composableBuilder(
    column: $table.thresholdInclusive,
    builder: (column) => column,
  );
}

class $$LoadingPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LoadingPoliciesTable,
          LoadingPolicyRow,
          $$LoadingPoliciesTableFilterComposer,
          $$LoadingPoliciesTableOrderingComposer,
          $$LoadingPoliciesTableAnnotationComposer,
          $$LoadingPoliciesTableCreateCompanionBuilder,
          $$LoadingPoliciesTableUpdateCompanionBuilder,
          (
            LoadingPolicyRow,
            BaseReferences<
              _$AppDatabase,
              $LoadingPoliciesTable,
              LoadingPolicyRow
            >,
          ),
          LoadingPolicyRow,
          PrefetchHooks Function()
        > {
  $$LoadingPoliciesTableTableManager(
    _$AppDatabase db,
    $LoadingPoliciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoadingPoliciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoadingPoliciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoadingPoliciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lowPaise = const Value.absent(),
                Value<int> highPaise = const Value.absent(),
                Value<int> thresholdCft = const Value.absent(),
                Value<bool> thresholdInclusive = const Value.absent(),
              }) => LoadingPoliciesCompanion(
                id: id,
                lowPaise: lowPaise,
                highPaise: highPaise,
                thresholdCft: thresholdCft,
                thresholdInclusive: thresholdInclusive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lowPaise = const Value.absent(),
                Value<int> highPaise = const Value.absent(),
                Value<int> thresholdCft = const Value.absent(),
                Value<bool> thresholdInclusive = const Value.absent(),
              }) => LoadingPoliciesCompanion.insert(
                id: id,
                lowPaise: lowPaise,
                highPaise: highPaise,
                thresholdCft: thresholdCft,
                thresholdInclusive: thresholdInclusive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LoadingPoliciesTable, LoadingPolicyRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LoadingPoliciesTable,
                    LoadingPolicyRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LoadingPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LoadingPoliciesTable,
      LoadingPolicyRow,
      $$LoadingPoliciesTableFilterComposer,
      $$LoadingPoliciesTableOrderingComposer,
      $$LoadingPoliciesTableAnnotationComposer,
      $$LoadingPoliciesTableCreateCompanionBuilder,
      $$LoadingPoliciesTableUpdateCompanionBuilder,
      (
        LoadingPolicyRow,
        BaseReferences<_$AppDatabase, $LoadingPoliciesTable, LoadingPolicyRow>,
      ),
      LoadingPolicyRow,
      PrefetchHooks Function()
    >;
typedef $$PendingOperationsTableCreateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<int> id,
      required OpType opType,
      required String payload,
      required String idempotencyKey,
      required DateTime enqueuedAt,
      Value<int> attempts,
      required SyncState syncState,
      Value<String?> lastError,
    });
typedef $$PendingOperationsTableUpdateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<int> id,
      Value<OpType> opType,
      Value<String> payload,
      Value<String> idempotencyKey,
      Value<DateTime> enqueuedAt,
      Value<int> attempts,
      Value<SyncState> syncState,
      Value<String?> lastError,
    });

class $$PendingOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OpType, OpType, int> get opType =>
      $composableBuilder(
        column: $table.opType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncState, SyncState, int> get syncState =>
      $composableBuilder(
        column: $table.syncState,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get opType => $composableBuilder(
    column: $table.opType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OpType, int> get opType =>
      $composableBuilder(column: $table.opType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncState, int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperationRow,
          $$PendingOperationsTableFilterComposer,
          $$PendingOperationsTableOrderingComposer,
          $$PendingOperationsTableAnnotationComposer,
          $$PendingOperationsTableCreateCompanionBuilder,
          $$PendingOperationsTableUpdateCompanionBuilder,
          (
            PendingOperationRow,
            BaseReferences<
              _$AppDatabase,
              $PendingOperationsTable,
              PendingOperationRow
            >,
          ),
          PendingOperationRow,
          PrefetchHooks Function()
        > {
  $$PendingOperationsTableTableManager(
    _$AppDatabase db,
    $PendingOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<OpType> opType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> enqueuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<SyncState> syncState = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingOperationsCompanion(
                id: id,
                opType: opType,
                payload: payload,
                idempotencyKey: idempotencyKey,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                syncState: syncState,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required OpType opType,
                required String payload,
                required String idempotencyKey,
                required DateTime enqueuedAt,
                Value<int> attempts = const Value.absent(),
                required SyncState syncState,
                Value<String?> lastError = const Value.absent(),
              }) => PendingOperationsCompanion.insert(
                id: id,
                opType: opType,
                payload: payload,
                idempotencyKey: idempotencyKey,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                syncState: syncState,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingOperationsTable, PendingOperationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingOperationsTable,
                    PendingOperationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingOperationsTable,
      PendingOperationRow,
      $$PendingOperationsTableFilterComposer,
      $$PendingOperationsTableOrderingComposer,
      $$PendingOperationsTableAnnotationComposer,
      $$PendingOperationsTableCreateCompanionBuilder,
      $$PendingOperationsTableUpdateCompanionBuilder,
      (
        PendingOperationRow,
        BaseReferences<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperationRow
        >,
      ),
      PendingOperationRow,
      PrefetchHooks Function()
    >;
typedef $$BackupMetasTableCreateCompanionBuilder =
    BackupMetasCompanion Function({
      Value<int> id,
      required int schemaVersion,
      required String appVersion,
      required DateTime exportedAt,
      required String checksum,
    });
typedef $$BackupMetasTableUpdateCompanionBuilder =
    BackupMetasCompanion Function({
      Value<int> id,
      Value<int> schemaVersion,
      Value<String> appVersion,
      Value<DateTime> exportedAt,
      Value<String> checksum,
    });

class $$BackupMetasTableFilterComposer
    extends Composer<_$AppDatabase, $BackupMetasTable> {
  $$BackupMetasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupMetasTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupMetasTable> {
  $$BackupMetasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupMetasTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupMetasTable> {
  $$BackupMetasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);
}

class $$BackupMetasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupMetasTable,
          BackupMetaRow,
          $$BackupMetasTableFilterComposer,
          $$BackupMetasTableOrderingComposer,
          $$BackupMetasTableAnnotationComposer,
          $$BackupMetasTableCreateCompanionBuilder,
          $$BackupMetasTableUpdateCompanionBuilder,
          (
            BackupMetaRow,
            BaseReferences<_$AppDatabase, $BackupMetasTable, BackupMetaRow>,
          ),
          BackupMetaRow,
          PrefetchHooks Function()
        > {
  $$BackupMetasTableTableManager(_$AppDatabase db, $BackupMetasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupMetasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupMetasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupMetasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<DateTime> exportedAt = const Value.absent(),
                Value<String> checksum = const Value.absent(),
              }) => BackupMetasCompanion(
                id: id,
                schemaVersion: schemaVersion,
                appVersion: appVersion,
                exportedAt: exportedAt,
                checksum: checksum,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int schemaVersion,
                required String appVersion,
                required DateTime exportedAt,
                required String checksum,
              }) => BackupMetasCompanion.insert(
                id: id,
                schemaVersion: schemaVersion,
                appVersion: appVersion,
                exportedAt: exportedAt,
                checksum: checksum,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupMetasTable, BackupMetaRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupMetasTable,
                    BackupMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupMetasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupMetasTable,
      BackupMetaRow,
      $$BackupMetasTableFilterComposer,
      $$BackupMetasTableOrderingComposer,
      $$BackupMetasTableAnnotationComposer,
      $$BackupMetasTableCreateCompanionBuilder,
      $$BackupMetasTableUpdateCompanionBuilder,
      (
        BackupMetaRow,
        BaseReferences<_$AppDatabase, $BackupMetasTable, BackupMetaRow>,
      ),
      BackupMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WoodVarietiesTableTableManager get woodVarieties =>
      $$WoodVarietiesTableTableManager(_db, _db.woodVarieties);
  $$CrossSectionsTableTableManager get crossSections =>
      $$CrossSectionsTableTableManager(_db, _db.crossSections);
  $$StockItemsTableTableManager get stockItems =>
      $$StockItemsTableTableManager(_db, _db.stockItems);
  $$ReceiptSessionsTableTableManager get receiptSessions =>
      $$ReceiptSessionsTableTableManager(_db, _db.receiptSessions);
  $$ReceiptEntriesTableTableManager get receiptEntries =>
      $$ReceiptEntriesTableTableManager(_db, _db.receiptEntries);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db, _db.invoices);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(_db, _db.stockMovements);
  $$PriceRatesTableTableManager get priceRates =>
      $$PriceRatesTableTableManager(_db, _db.priceRates);
  $$DraftOrdersTableTableManager get draftOrders =>
      $$DraftOrdersTableTableManager(_db, _db.draftOrders);
  $$DraftOrderRequestsTableTableManager get draftOrderRequests =>
      $$DraftOrderRequestsTableTableManager(_db, _db.draftOrderRequests);
  $$AllocationLinesTableTableManager get allocationLines =>
      $$AllocationLinesTableTableManager(_db, _db.allocationLines);
  $$InvoiceLinesTableTableManager get invoiceLines =>
      $$InvoiceLinesTableTableManager(_db, _db.invoiceLines);
  $$BusinessSettingsTableTableManager get businessSettings =>
      $$BusinessSettingsTableTableManager(_db, _db.businessSettings);
  $$AllocationPoliciesTableTableManager get allocationPolicies =>
      $$AllocationPoliciesTableTableManager(_db, _db.allocationPolicies);
  $$TaxPoliciesTableTableManager get taxPolicies =>
      $$TaxPoliciesTableTableManager(_db, _db.taxPolicies);
  $$LoadingPoliciesTableTableManager get loadingPolicies =>
      $$LoadingPoliciesTableTableManager(_db, _db.loadingPolicies);
  $$PendingOperationsTableTableManager get pendingOperations =>
      $$PendingOperationsTableTableManager(_db, _db.pendingOperations);
  $$BackupMetasTableTableManager get backupMetas =>
      $$BackupMetasTableTableManager(_db, _db.backupMetas);
}
