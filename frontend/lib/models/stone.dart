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
  final bool freeDrawAvailable;

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
    this.freeDrawAvailable = false,
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
      freeDrawAvailable: json['free_draw_available'] as bool? ?? false,
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

// ==================== 卡牌相关模型 ====================

const ENERGY_LEVEL_NAMES = {
  1: '微光',
  2: '闪烁',
  3: '明亮',
  4: '璀璨',
  5: '耀目',
};

const CARD_TYPE_NAMES = {
  'HEALTH': '健康',
  'LOVE': '爱情',
  'WEALTH': '财富',
  'CAREER': '事业',
  'FAMILY': '家庭',
};

const RARITY_NAMES = {
  'IRON': '赤铁',
  'BRONZE': '青铜',
  'SILVER': '白银',
  'GOLD': '黄金',
  'BLACK_GOLD': '黑金',
};

const RARITY_COLORS = {
  'IRON': 0xFFB7410E,     // 铁锈红
  'BRONZE': 0xFFCD7F32,   // 青铜色
  'SILVER': 0xFFA8A9AD,   // 银灰色
  'GOLD': 0xFFFFD700,     // 黄金色
  'BLACK_GOLD': 0xFF1C1C1A, // 黑金色
};

/// 由 ApiService 初始化，用于拼接图片相对路径
String _imageBaseUrl = '';
void setImageBaseUrl(String url) { _imageBaseUrl = url; }

String? _resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  if (url.startsWith('/') && _imageBaseUrl.isNotEmpty) {
    return '$_imageBaseUrl$url';
  }
  return url;
}

const CARD_TYPE_SUB_NAMES = {
  'UNIT': '单位',
  'SPELL': '法术',
  'ITEM': '装备',
  'RELIC': '遗物',
};

class CardStats {
  final int attack;
  final int health;

  CardStats({required this.attack, required this.health});

  factory CardStats.fromJson(Map<String, dynamic> json) {
    return CardStats(
      attack: json['attack'] as int? ?? 0,
      health: json['health'] as int? ?? 0,
    );
  }
}

class CardEffect {
  final String type;
  final String target;
  final double value;
  final String? condition;
  final String? subtype;
  final int? max;
  final double? risk;

  CardEffect({
    required this.type, required this.target, required this.value,
    this.condition, this.subtype, this.max, this.risk,
  });

  factory CardEffect.fromJson(Map<String, dynamic> json) {
    return CardEffect(
      type: json['type'] as String,
      target: json['target'] as String,
      value: (json['value'] as num).toDouble(),
      condition: json['condition'] as String?,
      subtype: json['subtype'] as String?,
      max: json['max'] as int?,
      risk: json['risk'] != null ? (json['risk'] as num).toDouble() : null,
    );
  }
}

class Card {
  final int id;
  final String cardType;
  final String cardTypeName;
  final String mantra;
  final int energyLevel;
  final String energyLevelName;
  final int energyValue;
  final int energyConsumed;
  final int remainingEnergy;
  final String colorCode;
  final bool canCharge;
  final String createdAt;
  final String? imageUrl;
  // v0.6.0 new fields
  final String? cardId;
  final String? name;
  final String? faction;
  final String? rarity;
  final String? rarityName;
  final String? cardTypeSub;
  final String? cardTypeSubName;
  final int? cost;
  final CardStats? stats;
  final List<String>? tags;
  final List<CardEffect>? effects;
  final String? lore;
  // v0.7.0 卡牌布局
  final int? cardWidth;
  final int? cardHeight;
  final String? imageFit;
  final int marginTop;
  final int marginLeft;
  final int marginBottom;
  final int marginRight;

  Card({
    required this.id,
    required this.cardType,
    required this.cardTypeName,
    required this.mantra,
    required this.energyLevel,
    required this.energyLevelName,
    required this.energyValue,
    required this.energyConsumed,
    required this.remainingEnergy,
    required this.colorCode,
    required this.canCharge,
    required this.createdAt,
    this.imageUrl,
    this.cardId,
    this.name,
    this.faction,
    this.rarity,
    this.rarityName,
    this.cardTypeSub,
    this.cardTypeSubName,
    this.cost,
    this.stats,
    this.tags,
    this.effects,
    this.lore,
    this.cardWidth,
    this.cardHeight,
    this.imageFit,
    this.marginTop = 0,
    this.marginLeft = 0,
    this.marginBottom = 0,
    this.marginRight = 0,
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      id: json['id'] as int,
      cardType: json['card_type'] as String,
      cardTypeName: json['card_type_name'] as String,
      mantra: json['mantra'] as String,
      energyLevel: json['energy_level'] as int,
      energyLevelName: json['energy_level_name'] as String,
      energyValue: json['energy_value'] as int,
      energyConsumed: json['energy_consumed'] as int? ?? 0,
      remainingEnergy: json['remaining_energy'] as int,
      colorCode: json['color_code'] as String,
      canCharge: json['can_charge'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      imageUrl: _resolveImageUrl(json['image_url'] as String?),
      cardId: json['card_id'] as String?,
      name: json['name'] as String?,
      faction: json['faction'] as String?,
      rarity: json['rarity'] as String?,
      rarityName: json['rarity_name'] as String?,
      cardTypeSub: json['card_type_sub'] as String?,
      cardTypeSubName: json['card_type_sub_name'] as String?,
      cost: json['cost'] as int?,
      stats: json['stats'] != null ? CardStats.fromJson(json['stats'] as Map<String, dynamic>) : null,
      tags: (json['tags'] as List?)?.map((t) => t as String).toList(),
      effects: (json['effects'] as List?)?.map((e) => CardEffect.fromJson(e as Map<String, dynamic>)).toList(),
      lore: json['lore'] as String?,
      cardWidth: json['card_width'] as int?,
      cardHeight: json['card_height'] as int?,
      imageFit: json['image_fit'] as String? ?? 'COVER',
      marginTop: json['margin_top'] as int? ?? 0,
      marginLeft: json['margin_left'] as int? ?? 0,
      marginBottom: json['margin_bottom'] as int? ?? 0,
      marginRight: json['margin_right'] as int? ?? 0,
    );
  }
}

class DrawStatus {
  final int freeDrawsAvailable;
  final int energyDrawsUsed;
  final int energyDrawsRemaining;
  final int pityGold;
  final int pityBlackGold;

  DrawStatus({
    required this.freeDrawsAvailable,
    required this.energyDrawsUsed,
    required this.energyDrawsRemaining,
    this.pityGold = 0,
    this.pityBlackGold = 0,
  });

  factory DrawStatus.fromJson(Map<String, dynamic> json) {
    return DrawStatus(
      freeDrawsAvailable: json['free_draws_available'] as int? ?? 0,
      energyDrawsUsed: json['energy_draws_used'] as int? ?? 0,
      energyDrawsRemaining: json['energy_draws_remaining'] as int? ?? 3,
      pityGold: json['pity_gold'] as int? ?? 0,
      pityBlackGold: json['pity_black_gold'] as int? ?? 0,
    );
  }
}

class DrawCardResponse {
  final bool success;
  final Card? card;
  final String message;
  final String drawType;
  final int energyCost;

  DrawCardResponse({
    required this.success,
    this.card,
    required this.message,
    required this.drawType,
    this.energyCost = 0,
  });

  factory DrawCardResponse.fromJson(Map<String, dynamic> json) {
    return DrawCardResponse(
      success: json['success'] as bool,
      card: json['card'] != null ? Card.fromJson(json['card'] as Map<String, dynamic>) : null,
      message: json['message'] as String,
      drawType: json['draw_type'] as String,
      energyCost: json['energy_cost'] as int? ?? 0,
    );
  }
}

class ChargeCardResponse {
  final bool success;
  final int cardId;
  final int stoneId;
  final int energyCharged;
  final int stoneEnergyAfter;
  final int cardRemainingEnergy;
  final String message;

  ChargeCardResponse({
    required this.success,
    required this.cardId,
    required this.stoneId,
    required this.energyCharged,
    required this.stoneEnergyAfter,
    required this.cardRemainingEnergy,
    required this.message,
  });

  factory ChargeCardResponse.fromJson(Map<String, dynamic> json) {
    return ChargeCardResponse(
      success: json['success'] as bool,
      cardId: json['card_id'] as int,
      stoneId: json['stone_id'] as int,
      energyCharged: json['energy_charged'] as int,
      stoneEnergyAfter: json['stone_energy_after'] as int,
      cardRemainingEnergy: json['card_remaining_energy'] as int,
      message: json['message'] as String,
    );
  }
}

// ==================== 待接收卡牌模型 ====================

class PendingCard {
  final int id;
  final String cardType;
  final String cardTypeName;
  final String mantra;
  final int energyLevel;
  final String energyLevelName;
  final int energyValue;
  final int remainingEnergy;
  final String colorCode;
  final int fromUserId;
  final String? fromUserNickname;
  final String createdAt;

  PendingCard({
    required this.id,
    required this.cardType,
    required this.cardTypeName,
    required this.mantra,
    required this.energyLevel,
    required this.energyLevelName,
    required this.energyValue,
    required this.remainingEnergy,
    required this.colorCode,
    required this.fromUserId,
    this.fromUserNickname,
    required this.createdAt,
  });

  factory PendingCard.fromJson(Map<String, dynamic> json) {
    return PendingCard(
      id: json['id'] as int,
      cardType: json['card_type'] as String,
      cardTypeName: json['card_type_name'] as String,
      mantra: json['mantra'] as String,
      energyLevel: json['energy_level'] as int,
      energyLevelName: json['energy_level_name'] as String,
      energyValue: json['energy_value'] as int,
      remainingEnergy: json['remaining_energy'] as int,
      colorCode: json['color_code'] as String,
      fromUserId: json['from_user_id'] as int,
      fromUserNickname: json['from_user_nickname'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

// ==================== v0.5.0 合成相关 ====================

class SynthesizeResponse {
  final bool success;
  final Card? card;
  final String message;

  SynthesizeResponse({required this.success, this.card, required this.message});

  factory SynthesizeResponse.fromJson(Map<String, dynamic> json) {
    return SynthesizeResponse(
      success: json['success'] as bool,
      card: json['card'] != null ? Card.fromJson(json['card'] as Map<String, dynamic>) : null,
      message: json['message'] as String,
    );
  }
}

// ==================== v0.5.0 收藏相关 ====================

class CollectionProgress {
  final String cardType;
  final String cardTypeName;
  final int collected;
  final int total;

  CollectionProgress({required this.cardType, required this.cardTypeName, required this.collected, required this.total});

  factory CollectionProgress.fromJson(Map<String, dynamic> json) {
    return CollectionProgress(
      cardType: json['card_type'] as String,
      cardTypeName: json['card_type_name'] as String,
      collected: json['collected'] as int,
      total: json['total'] as int,
    );
  }
}

// ==================== v0.5.0 商店相关 ====================

class StoreItem {
  final int id;
  final String itemType;
  final String name;
  final String? stoneType;
  final int energyAmount;
  final int price;
  final bool isActive;

  StoreItem({
    required this.id, required this.itemType, required this.name,
    this.stoneType, required this.energyAmount, required this.price,
    required this.isActive,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] as int,
      itemType: json['item_type'] as String,
      name: json['name'] as String,
      stoneType: json['stone_type'] as String?,
      energyAmount: json['energy_amount'] as int? ?? 0,
      price: json['price'] as int,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class PurchaseResponse {
  final bool success;
  final String itemName;
  final int energyDeducted;
  final int userTotalEnergy;
  final String message;

  PurchaseResponse({
    required this.success, required this.itemName,
    required this.energyDeducted, required this.userTotalEnergy,
    required this.message,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      success: json['success'] as bool,
      itemName: json['item_name'] as String,
      energyDeducted: json['energy_deducted'] as int,
      userTotalEnergy: json['user_total_energy'] as int,
      message: json['message'] as String,
    );
  }
}

// ==================== v0.5.0 消息相关 ====================

class AppMessage {
  final int id;
  final String msgType;
  final String? msgSubtype;
  final String title;
  final String content;
  final int? senderId;
  final String? senderNickname;
  final bool isRead;
  final String createdAt;
  final PendingCard? cardInfo;

  AppMessage({
    required this.id, required this.msgType, this.msgSubtype,
    required this.title, required this.content,
    this.senderId, this.senderNickname,
    required this.isRead, required this.createdAt,
    this.cardInfo,
  });

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      id: json['id'] as int,
      msgType: json['msg_type'] as String,
      msgSubtype: json['msg_subtype'] as String?,
      title: json['title'] as String,
      content: json['content'] as String,
      senderId: json['sender_id'] as int?,
      senderNickname: json['sender_nickname'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      cardInfo: json['card_info'] != null
          ? PendingCard.fromJson(json['card_info'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MessageListResponse {
  final List<AppMessage> messages;
  final int total;
  final int unreadCount;

  MessageListResponse({required this.messages, required this.total, required this.unreadCount});

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    return MessageListResponse(
      messages: (json['messages'] as List?)?.map((m) => AppMessage.fromJson(m)).toList() ?? [],
      total: json['total'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

// ==================== v0.5.0 广场相关 ====================

class PlazaPost {
  final int id;
  final int? userId;
  final String? userNickname;
  final String postType;
  final String content;
  final int prayCount;
  final bool hasPrayed;
  final String createdAt;

  PlazaPost({
    required this.id, this.userId, this.userNickname,
    required this.postType, required this.content,
    required this.prayCount, required this.hasPrayed,
    required this.createdAt,
  });

  factory PlazaPost.fromJson(Map<String, dynamic> json) {
    return PlazaPost(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      userNickname: json['user_nickname'] as String?,
      postType: json['post_type'] as String,
      content: json['content'] as String,
      prayCount: json['pray_count'] as int? ?? 0,
      hasPrayed: json['has_prayed'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }

  String get postTypeLabel {
    switch (postType) {
      case 'BLESSING': return '祈福';
      case 'WISH': return '许愿';
      case 'ANNOUNCEMENT': return '公告';
      case 'ACTIVITY': return '活动';
      default: return postType;
    }
  }
}

// ==================== v0.5.0 管理员相关 ====================

class PresetCardManage {
  final int id;
  final String cardType;
  final String mantra;
  final int energyLevel;

  PresetCardManage({required this.id, required this.cardType, required this.mantra, required this.energyLevel});

  factory PresetCardManage.fromJson(Map<String, dynamic> json) {
    return PresetCardManage(
      id: json['id'] as int,
      cardType: json['card_type'] as String,
      mantra: json['mantra'] as String,
      energyLevel: json['energy_level'] as int,
    );
  }
}