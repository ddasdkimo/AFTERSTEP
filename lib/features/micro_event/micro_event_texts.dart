import '../../data/models/micro_event.dart';

/// 微事件文案庫
///
/// 包含所有可能顯示的微事件文案。
const List<MicroEventDefinition> microEventTexts = [
  // 存在感 (PRESENCE)
  MicroEventDefinition(
    id: 'p1',
    text: '你不是第一個走到這裡的人。',
    category: EventCategory.presence,
    weight: 10,
  ),
  MicroEventDefinition(
    id: 'p2',
    text: '這附近，有人停下來過。',
    category: EventCategory.presence,
    weight: 10,
  ),
  MicroEventDefinition(
    id: 'p3',
    text: '有人曾在這裡駐足。',
    category: EventCategory.presence,
    weight: 8,
  ),
  MicroEventDefinition(
    id: 'p4',
    text: '這裡留有痕跡。',
    category: EventCategory.presence,
    weight: 6,
  ),
  MicroEventDefinition(
    id: 'p5',
    text: '不只你經過這裡。',
    category: EventCategory.presence,
    weight: 8,
  ),

  // 時間感 (TIME)
  MicroEventDefinition(
    id: 't1',
    text: '時間在這裡流過。',
    category: EventCategory.time,
    weight: 6,
  ),
  MicroEventDefinition(
    id: 't2',
    text: '某個時刻，有人也在這。',
    category: EventCategory.time,
    weight: 8,
  ),
  MicroEventDefinition(
    id: 't3',
    text: '這一刻與另一刻重疊了。',
    category: EventCategory.time,
    weight: 5,
  ),

  // 空間感 (SPACE)
  MicroEventDefinition(
    id: 's1',
    text: '這片地方被記住了。',
    category: EventCategory.space,
    weight: 7,
  ),
  MicroEventDefinition(
    id: 's2',
    text: '有人的路徑經過這裡。',
    category: EventCategory.space,
    weight: 9,
  ),
  MicroEventDefinition(
    id: 's3',
    text: '世界在這裡被照亮過。',
    category: EventCategory.space,
    weight: 6,
  ),

  // 連結感 (CONNECTION)
  MicroEventDefinition(
    id: 'c1',
    text: '你們的軌跡交會了。',
    category: EventCategory.connection,
    weight: 5,
  ),
  MicroEventDefinition(
    id: 'c2',
    text: '某人走過同樣的路。',
    category: EventCategory.connection,
    weight: 8,
  ),
  MicroEventDefinition(
    id: 'c3',
    text: '這裡連結著另一個人。',
    category: EventCategory.connection,
    weight: 4,
  ),
];
