import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/danmaku_item.dart';

/// 弹幕状态通知器，用于优化状态管理和减少 setState 调用
/// 
/// 该类使用 ValueNotifier 替代频繁的 setState 调用，
/// 显著减少 Widget 重建次数，提升大量弹幕场景下的性能。
/// 
/// 主要优化：
/// - 使用 ValueNotifier 进行细粒度状态管理
/// - 批量更新机制，减少通知频率
/// - 智能更新策略，只在必要时触发重绘
class DanmakuStateNotifier extends ChangeNotifier {
  /// 滚动弹幕列表通知器
  final ValueNotifier<List<DanmakuItem>> _scrollDanmakuNotifier = 
      ValueNotifier<List<DanmakuItem>>(<DanmakuItem>[]);
  
  /// 顶部弹幕列表通知器
  final ValueNotifier<List<DanmakuItem>> _topDanmakuNotifier = 
      ValueNotifier<List<DanmakuItem>>(<DanmakuItem>[]);
  
  /// 底部弹幕列表通知器
  final ValueNotifier<List<DanmakuItem>> _bottomDanmakuNotifier = 
      ValueNotifier<List<DanmakuItem>>(<DanmakuItem>[]);
  
  /// 特殊弹幕列表通知器
  final ValueNotifier<List<DanmakuItem>> _specialDanmakuNotifier = 
      ValueNotifier<List<DanmakuItem>>(<DanmakuItem>[]);
  
  /// 运行状态通知器
  final ValueNotifier<bool> _runningNotifier = ValueNotifier<bool>(true);
  
  /// 批量更新定时器
  Timer? _batchUpdateTimer;
  
  /// 批量更新间隔（毫秒）
  static const int _batchUpdateInterval = 16; // 约60FPS
  
  /// 是否有待处理的更新
  bool _hasPendingUpdates = false;
  
  /// 更新计数器（用于性能监控）
  int _updateCount = 0;
  
  /// 批量更新计数器
  int _batchUpdateCount = 0;

  /// 获取滚动弹幕列表通知器
  ValueNotifier<List<DanmakuItem>> get scrollDanmakuNotifier => _scrollDanmakuNotifier;
  
  /// 获取顶部弹幕列表通知器
  ValueNotifier<List<DanmakuItem>> get topDanmakuNotifier => _topDanmakuNotifier;
  
  /// 获取底部弹幕列表通知器
  ValueNotifier<List<DanmakuItem>> get bottomDanmakuNotifier => _bottomDanmakuNotifier;
  
  /// 获取特殊弹幕列表通知器
  ValueNotifier<List<DanmakuItem>> get specialDanmakuNotifier => _specialDanmakuNotifier;
  
  /// 获取运行状态通知器
  ValueNotifier<bool> get runningNotifier => _runningNotifier;
  
  /// 获取滚动弹幕列表
  List<DanmakuItem> get scrollDanmakuItems => _scrollDanmakuNotifier.value;
  
  /// 获取顶部弹幕列表
  List<DanmakuItem> get topDanmakuItems => _topDanmakuNotifier.value;
  
  /// 获取底部弹幕列表
  List<DanmakuItem> get bottomDanmakuItems => _bottomDanmakuNotifier.value;
  
  /// 获取特殊弹幕列表
  List<DanmakuItem> get specialDanmakuItems => _specialDanmakuNotifier.value;
  
  /// 获取运行状态
  bool get isRunning => _runningNotifier.value;
  
  /// 获取更新统计信息
  Map<String, int> get updateStats => {
    'totalUpdates': _updateCount,
    'batchUpdates': _batchUpdateCount,
  };

  /// 更新滚动弹幕列表
  /// 
  /// [items] 新的弹幕列表
  /// [immediate] 是否立即更新，默认为 false（批量更新）
  void updateScrollDanmaku(List<DanmakuItem> items, {bool immediate = false}) {
    try {
      if (immediate) {
        _scrollDanmakuNotifier.value = List.from(items);
        _updateCount++;
        
        developer.log(
          'Immediate scroll danmaku update, count: ${items.length}',
          name: 'DanmakuStateNotifier',
        );
      } else {
        _scrollDanmakuNotifier.value = List.from(items);
        _scheduleBatchUpdate();
      }
    } catch (e) {
      developer.log(
        'Error updating scroll danmaku: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 更新顶部弹幕列表
  /// 
  /// [items] 新的弹幕列表
  /// [immediate] 是否立即更新，默认为 false（批量更新）
  void updateTopDanmaku(List<DanmakuItem> items, {bool immediate = false}) {
    try {
      if (immediate) {
        _topDanmakuNotifier.value = List.from(items);
        _updateCount++;
        
        developer.log(
          'Immediate top danmaku update, count: ${items.length}',
          name: 'DanmakuStateNotifier',
        );
      } else {
        _topDanmakuNotifier.value = List.from(items);
        _scheduleBatchUpdate();
      }
    } catch (e) {
      developer.log(
        'Error updating top danmaku: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 更新底部弹幕列表
  /// 
  /// [items] 新的弹幕列表
  /// [immediate] 是否立即更新，默认为 false（批量更新）
  void updateBottomDanmaku(List<DanmakuItem> items, {bool immediate = false}) {
    try {
      if (immediate) {
        _bottomDanmakuNotifier.value = List.from(items);
        _updateCount++;
        
        developer.log(
          'Immediate bottom danmaku update, count: ${items.length}',
          name: 'DanmakuStateNotifier',
        );
      } else {
        _bottomDanmakuNotifier.value = List.from(items);
        _scheduleBatchUpdate();
      }
    } catch (e) {
      developer.log(
        'Error updating bottom danmaku: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 更新特殊弹幕列表
  /// 
  /// [items] 新的弹幕列表
  /// [immediate] 是否立即更新，默认为 false（批量更新）
  void updateSpecialDanmaku(List<DanmakuItem> items, {bool immediate = false}) {
    try {
      if (immediate) {
        _specialDanmakuNotifier.value = List.from(items);
        _updateCount++;
        
        developer.log(
          'Immediate special danmaku update, count: ${items.length}',
          name: 'DanmakuStateNotifier',
        );
      } else {
        _specialDanmakuNotifier.value = List.from(items);
        _scheduleBatchUpdate();
      }
    } catch (e) {
      developer.log(
        'Error updating special danmaku: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 更新运行状态
  /// 
  /// [running] 新的运行状态
  void updateRunningState(bool running) {
    try {
      if (_runningNotifier.value != running) {
        _runningNotifier.value = running;
        _updateCount++;
        
        developer.log(
          'Updated running state: $running',
          name: 'DanmakuStateNotifier',
        );
      }
    } catch (e) {
      developer.log(
        'Error updating running state: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 批量更新所有弹幕列表
  /// 
  /// [scrollItems] 滚动弹幕列表
  /// [topItems] 顶部弹幕列表
  /// [bottomItems] 底部弹幕列表
  /// [specialItems] 特殊弹幕列表
  /// [running] 运行状态（可选）
  void batchUpdate({
    List<DanmakuItem>? scrollItems,
    List<DanmakuItem>? topItems,
    List<DanmakuItem>? bottomItems,
    List<DanmakuItem>? specialItems,
    bool? running,
  }) {
    try {
      bool hasChanges = false;
      
      if (scrollItems != null) {
        _scrollDanmakuNotifier.value = List.from(scrollItems);
        hasChanges = true;
      }
      
      if (topItems != null) {
        _topDanmakuNotifier.value = List.from(topItems);
        hasChanges = true;
      }
      
      if (bottomItems != null) {
        _bottomDanmakuNotifier.value = List.from(bottomItems);
        hasChanges = true;
      }
      
      if (specialItems != null) {
        _specialDanmakuNotifier.value = List.from(specialItems);
        hasChanges = true;
      }
      
      if (running != null && _runningNotifier.value != running) {
        _runningNotifier.value = running;
        hasChanges = true;
      }
      
      if (hasChanges) {
        _updateCount++;
        _batchUpdateCount++;
        
        developer.log(
          'Batch update completed',
          name: 'DanmakuStateNotifier',
        );
      }
    } catch (e) {
      developer.log(
        'Error in batch update: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 清空所有弹幕
  void clearAll() {
    try {
      batchUpdate(
        scrollItems: <DanmakuItem>[],
        topItems: <DanmakuItem>[],
        bottomItems: <DanmakuItem>[],
        specialItems: <DanmakuItem>[],
      );
      
      developer.log(
        'Cleared all danmaku lists',
        name: 'DanmakuStateNotifier',
      );
    } catch (e) {
      developer.log(
        'Error clearing all danmaku: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 安排批量更新
  void _scheduleBatchUpdate() {
    if (!_hasPendingUpdates) {
      _hasPendingUpdates = true;
      
      _batchUpdateTimer?.cancel();
      _batchUpdateTimer = Timer(
        Duration(milliseconds: _batchUpdateInterval),
        _performBatchUpdate,
      );
    }
  }

  /// 执行批量更新
  void _performBatchUpdate() {
    try {
      if (_hasPendingUpdates) {
        notifyListeners();
        _hasPendingUpdates = false;
        _batchUpdateCount++;
        
        developer.log(
          'Performed batch update',
          name: 'DanmakuStateNotifier',
        );
      }
    } catch (e) {
      developer.log(
        'Error performing batch update: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }

  /// 获取所有弹幕总数
  int get totalDanmakuCount {
    return scrollDanmakuItems.length +
           topDanmakuItems.length +
           bottomDanmakuItems.length +
           specialDanmakuItems.length;
  }

  /// 获取状态统计信息
  Map<String, dynamic> getStats() {
    return {
      'updateCount': _updateCount,
      'scrollDanmakuCount': _scrollDanmakuNotifier.value.length,
      'topDanmakuCount': _topDanmakuNotifier.value.length,
      'bottomDanmakuCount': _bottomDanmakuNotifier.value.length,
      'specialDanmakuCount': _specialDanmakuNotifier.value.length,
      'isRunning': _runningNotifier.value,
    };
  }

  @override
  void dispose() {
    try {
      _batchUpdateTimer?.cancel();
      _scrollDanmakuNotifier.dispose();
      _topDanmakuNotifier.dispose();
      _bottomDanmakuNotifier.dispose();
      _specialDanmakuNotifier.dispose();
      _runningNotifier.dispose();
      
      developer.log(
        'DanmakuStateNotifier disposed',
        name: 'DanmakuStateNotifier',
      );
      
      super.dispose();
    } catch (e) {
      developer.log(
        'Error disposing DanmakuStateNotifier: $e',
        name: 'DanmakuStateNotifier',
        error: e,
      );
    }
  }
}