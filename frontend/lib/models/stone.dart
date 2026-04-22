enum StoneType {
  health,
  love,
  wealth,
  career,
  family,
}

class StoneTypeInfo {
  final String name;
  final String colorCode;
  final String displayName;

  const StoneTypeInfo({
    required this.name,
    required this.colorCode,
    required this.displayName,
  });
}

const STONE_TYPE_INFO = {
  StoneType.health: StoneTypeInfo(name: 'HEALTH', colorCode: '#4CAF50', displayName: '健康'),
  StoneType.love: StoneTypeInfo(name: 'LOVE', colorCode: '#E91E63', displayName: '爱情'),
  StoneType.wealth: StoneTypeInfo(name: 'WEALTH', colorCode: '#FFD700', displayName: '财富'),
  StoneType.career: StoneTypeInfo(name: 'CAREER', colorCode: '#F44336', displayName: '事业'),
  StoneType.family: StoneTypeInfo(name: 'FAMILY', colorCode: '#2196F3', displayName: '家庭'),
};

class User {
  final int id;
  final String nickname;
  final String createdAt;
  final List<StoneStatus> stones;

  User({
    required this.id,
    required this.nickname,
    required this.createdAt,
    List<StoneStatus>? stones,
  }) : stones = stones ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nickname: json['nickname'] as String,
      createdAt: json['created_at'] as String,
      stones: (json['stones'] as List?)
          ?.map((s) => StoneStatus.fromJson(s))
          .toList() ?? [],
    );
  }
}

class StoneStatus {
  final int id;
  final String uniqueCode;
  final String stoneType;
  final int? ownerId;
  final int currentEnergy;
  final int deathCount;
  final String status;
  final int consecutiveDays;
  final String? lastChargeTime;

  StoneStatus({
    required this.id,
    required this.uniqueCode,
    required this.stoneType,
    this.ownerId,
    required this.currentEnergy,
    required this.deathCount,
    required this.status,
    required this.consecutiveDays,
    this.lastChargeTime,
  });

  factory StoneStatus.fromJson(Map<String, dynamic> json) {
    return StoneStatus(
      id: json['id'] as int,
      uniqueCode: json['unique_code'] as String,
      stoneType: json['stone_type'] as String,
      ownerId: json['owner_id'] as int?,
      currentEnergy: json['current_energy'] as int,
      deathCount: json['death_count'] as int,
      status: json['status'] as String,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      lastChargeTime: json['last_charge_time'] as String?,
    );
  }

  StoneType get typeEnum {
    switch (stoneType) {
      case 'HEALTH': return StoneType.health;
      case 'LOVE': return StoneType.love;
      case 'WEALTH': return StoneType.wealth;
      case 'CAREER': return StoneType.career;
      case 'FAMILY': return StoneType.family;
      default: return StoneType.health;
    }
  }

  String get colorCode {
    return STONE_TYPE_INFO[typeEnum]?.colorCode ?? '#4CAF50';
  }

  String get displayName {
    return STONE_TYPE_INFO[typeEnum]?.displayName ?? '健康';
  }
}

class StoneDetail {
  final int id;
  final String uniqueCode;
  final String stoneType;
  final String stoneTypeName;
  final String colorCode;
  final int? ownerId;
  final String? ownerNickname;
  final int currentEnergy;
  final int energyCap;
  final int deathCount;
  final String status;
  final int consecutiveDays;
  final int nextMultiplier;
  final bool canTransfer;

  StoneDetail({
    required this.id,
    required this.uniqueCode,
    required this.stoneType,
    required this.stoneTypeName,
    required this.colorCode,
    this.ownerId,
    this.ownerNickname,
    required this.currentEnergy,
    required this.energyCap,
    required this.deathCount,
    required this.status,
    required this.consecutiveDays,
    required this.nextMultiplier,
    required this.canTransfer,
  });

  factory StoneDetail.fromJson(Map<String, dynamic> json) {
    return StoneDetail(
      id: json['id'] as int,
      uniqueCode: json['unique_code'] as String,
      stoneType: json['stone_type'] as String,
      stoneTypeName: json['stone_type_name'] as String,
      colorCode: json['color_code'] as String,
      ownerId: json['owner_id'] as int?,
      ownerNickname: json['owner_nickname'] as String?,
      currentEnergy: json['current_energy'] as int,
      energyCap: json['energy_cap'] as int,
      deathCount: json['death_count'] as int,
      status: json['status'] as String,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      nextMultiplier: json['next_multiplier'] as int? ?? 1,
      canTransfer: json['can_transfer'] as bool? ?? false,
    );
  }

  StoneType get typeEnum {
    switch (stoneType) {
      case 'HEALTH': return StoneType.health;
      case 'LOVE': return StoneType.love;
      case 'WEALTH': return StoneType.wealth;
      case 'CAREER': return StoneType.career;
      case 'FAMILY': return StoneType.family;
      default: return StoneType.health;
    }
  }
}

class ChargeResponse {
  final int stoneId;
  final int energyBefore;
  final int energyAfter;
  final int energyGained;
  final int baseGain;
  final int multiplier;
  final int consecutiveDays;
  final String blessing;
  final String status;

  ChargeResponse({
    required this.stoneId,
    required this.energyBefore,
    required this.energyAfter,
    required this.energyGained,
    required this.baseGain,
    required this.multiplier,
    required this.consecutiveDays,
    required this.blessing,
    required this.status,
  });

  factory ChargeResponse.fromJson(Map<String, dynamic> json) {
    return ChargeResponse(
      stoneId: json['stone_id'] as int,
      energyBefore: json['energy_before'] as int,
      energyAfter: json['energy_after'] as int,
      energyGained: json['energy_gained'] as int,
      baseGain: json['base_gain'] as int,
      multiplier: json['multiplier'] as int,
      consecutiveDays: json['consecutive_days'] as int,
      blessing: json['blessing'] as String,
      status: json['status'] as String,
    );
  }
}

class CheckInStatus {
  final bool canCheckIn;
  final String? message;
  final int consecutiveDays;
  final int nextMultiplier;

  CheckInStatus({
    required this.canCheckIn,
    this.message,
    this.consecutiveDays = 0,
    this.nextMultiplier = 1,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      canCheckIn: json['can_check_in'] as bool,
      message: json['message'] as String?,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      nextMultiplier: json['next_multiplier'] as int? ?? 1,
    );
  }
}

class CheckInRecord {
  final int id;
  final int stoneId;
  final String checkInDate;
  final int energyBefore;
  final int energyAfter;
  final int energyGained;
  final int baseGain;
  final int multiplier;
  final int consecutiveDays;
  final String blessing;

  CheckInRecord({
    required this.id,
    required this.stoneId,
    required this.checkInDate,
    required this.energyBefore,
    required this.energyAfter,
    required this.energyGained,
    required this.baseGain,
    required this.multiplier,
    required this.consecutiveDays,
    required this.blessing,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      id: json['id'] as int,
      stoneId: json['stone_id'] as int,
      checkInDate: json['check_in_date'] as String,
      energyBefore: json['energy_before'] as int,
      energyAfter: json['energy_after'] as int,
      energyGained: json['energy_gained'] as int,
      baseGain: json['base_gain'] as int? ?? json['energy_gained'] as int,
      multiplier: json['multiplier'] as int? ?? 1,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      blessing: json['blessing'] as String,
    );
  }
}

class TransferResponse {
  final bool success;
  final int fromStoneId;
  final int toStoneId;
  final int? toOwnerId;
  final String? toOwnerNickname;
  final int energyAmount;
  final int fromStoneEnergy;
  final int toStoneEnergy;
  final String message;

  TransferResponse({
    required this.success,
    required this.fromStoneId,
    required this.toStoneId,
    this.toOwnerId,
    this.toOwnerNickname,
    required this.energyAmount,
    required this.fromStoneEnergy,
    required this.toStoneEnergy,
    required this.message,
  });

  factory TransferResponse.fromJson(Map<String, dynamic> json) {
    return TransferResponse(
      success: json['success'] as bool,
      fromStoneId: json['from_stone_id'] as int,
      toStoneId: json['to_stone_id'] as int,
      toOwnerId: json['to_owner_id'] as int?,
      toOwnerNickname: json['to_owner_nickname'] as String?,
      energyAmount: json['energy_amount'] as int,
      fromStoneEnergy: json['from_stone_energy'] as int,
      toStoneEnergy: json['to_stone_energy'] as int,
      message: json['message'] as String,
    );
  }
}