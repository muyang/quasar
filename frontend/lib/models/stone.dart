class ChargeResponse {
  final int stoneId;
  final int energyBefore;
  final int energyAfter;
  final int energyGained;
  final String blessing;
  final String status;

  ChargeResponse({
    required this.stoneId,
    required this.energyBefore,
    required this.energyAfter,
    required this.energyGained,
    required this.blessing,
    required this.status,
  });

  factory ChargeResponse.fromJson(Map<String, dynamic> json) {
    return ChargeResponse(
      stoneId: json['stone_id'] as int,
      energyBefore: json['energy_before'] as int,
      energyAfter: json['energy_after'] as int,
      energyGained: json['energy_gained'] as int,
      blessing: json['blessing'] as String,
      status: json['status'] as String,
    );
  }
}

class StoneStatus {
  final int id;
  final int userId;
  final int currentEnergy;
  final int deathCount;
  final String status;
  final String? lastChargeTime;

  StoneStatus({
    required this.id,
    required this.userId,
    required this.currentEnergy,
    required this.deathCount,
    required this.status,
    this.lastChargeTime,
  });

  factory StoneStatus.fromJson(Map<String, dynamic> json) {
    return StoneStatus(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      currentEnergy: json['current_energy'] as int,
      deathCount: json['death_count'] as int,
      status: json['status'] as String,
      lastChargeTime: json['last_charge_time'] as String?,
    );
  }
}

class CheckInStatus {
  final bool canCheckIn;
  final String? message;

  CheckInStatus({
    required this.canCheckIn,
    this.message,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    return CheckInStatus(
      canCheckIn: json['can_check_in'] as bool,
      message: json['message'] as String?,
    );
  }
}

class CheckInRecord {
  final int id;
  final int stoneId;
  final String checkInDate;
  final int energyBefore;
  final int energyAfter;
  final String blessing;

  CheckInRecord({
    required this.id,
    required this.stoneId,
    required this.checkInDate,
    required this.energyBefore,
    required this.energyAfter,
    required this.blessing,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      id: json['id'] as int,
      stoneId: json['stone_id'] as int,
      checkInDate: json['check_in_date'] as String,
      energyBefore: json['energy_before'] as int,
      energyAfter: json['energy_after'] as int,
      blessing: json['blessing'] as String,
    );
  }
}