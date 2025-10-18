import 'dart:collection';
import 'dart:developer' as developer;
import '../models/danmaku_item.dart';

/// 轨道管理器，用于优化弹幕轨道冲突检测
/// 
/// 该类将原来的 O(n) 线性搜索优化为 O(1) 的 Map 查找。
/// 为每个轨道维护独立的弹幕列表，大幅提升大量弹幕场景下的性能。
/// 
/// 主要优化：
/// - 使用 Map<double, List<DanmakuItem>> 存储轨道弹幕
/// - 快速查找指定轨道的弹幕
/// - 支持批量操作和清理
class TrackManager {
  /// 轨道弹幕映射表，key 为轨道 Y 坐标，value 为该轨道的弹幕列表
  final Map<double, List<DanmakuItem>> _trackItems = <double, List<DanmakuItem>>{};
  
  /// 所有轨道的 Y 坐标列表
  List<double> _trackYPositions = <double>[];
  
  /// 轨道数量
  int get trackCount => _trackYPositions.length;
  
  /// 总弹幕数量
  int get totalItemCount {
    int count = 0;
    for (final items in _trackItems.values) {
      count += items.length;
    }
    return count;
  }

  /// 初始化轨道
  /// 
  /// [trackYPositions] 轨道 Y 坐标列表
  /// 
  /// 抛出 [ArgumentError] 如果轨道列表为空
  void initializeTracks(List<double> trackYPositions) {
    try {
      if (trackYPositions.isEmpty) {
        throw ArgumentError('Track positions cannot be empty');
      }
      
      // 清理旧轨道
      clear();
      
      _trackYPositions = List.from(trackYPositions);
      
      // 为每个轨道初始化空列表
      for (final yPosition in _trackYPositions) {
        _trackItems[yPosition] = <DanmakuItem>[];
      }
      
      developer.log(
        'Initialized ${_trackYPositions.length} tracks',
        name: 'TrackManager',
      );
    } catch (e) {
      developer.log(
        'Error initializing tracks: $e',
        name: 'TrackManager',
        error: e,
      );
      rethrow;
    }
  }

  /// 检查滚动弹幕是否可以添加到指定轨道
  /// 
  /// [yPosition] 轨道 Y 坐标
  /// [newDanmakuWidth] 新弹幕宽度
  /// [viewWidth] 视图宽度
  /// 
  /// 返回 true 如果可以添加，false 否则
  bool canAddScrollDanmaku(double yPosition, double newDanmakuWidth, double viewWidth) {
    try {
      final trackItems = _trackItems[yPosition];
      if (trackItems == null || trackItems.isEmpty) {
        return true;
      }
      
      // 检查轨道上的所有弹幕
      for (final item in trackItems) {
        final existingEndPosition = item.xPosition + item.width;
        
        // 首先保证进入屏幕时不发生重叠
        if (viewWidth - existingEndPosition < 0) {
          return false;
        }
        
        // 其次保证直到移出屏幕前不与速度慢的弹幕发生重叠
        if (item.width < newDanmakuWidth) {
          final existingProgress = (viewWidth - item.xPosition) / (item.width + viewWidth);
          final newProgress = viewWidth / (viewWidth + newDanmakuWidth);
          
          if ((1 - existingProgress) > newProgress) {
            return false;
          }
        }
      }
      
      return true;
    } catch (e) {
      developer.log(
        'Error checking scroll danmaku collision: $e',
        name: 'TrackManager',
        error: e,
      );
      return false;
    }
  }

  /// 检查静态弹幕（顶部/底部）是否可以添加到指定轨道
  /// 
  /// [yPosition] 轨道 Y 坐标
  /// 
  /// 返回 true 如果可以添加，false 否则
  bool canAddStaticDanmaku(double yPosition) {
    try {
      final trackItems = _trackItems[yPosition];
      return trackItems == null || trackItems.isEmpty;
    } catch (e) {
      developer.log(
        'Error checking static danmaku collision: $e',
        name: 'TrackManager',
        error: e,
      );
      return false;
    }
  }

  /// 添加弹幕到指定轨道
  /// 
  /// [item] 弹幕对象
  /// 
  /// 抛出 [ArgumentError] 如果轨道不存在
  void addItem(DanmakuItem item) {
    try {
      final trackItems = _trackItems[item.yPosition];
      if (trackItems == null) {
        throw ArgumentError('Track ${item.yPosition} does not exist');
      }
      
      trackItems.add(item);
      
      developer.log(
        'Added danmaku to track ${item.yPosition}, track size: ${trackItems.length}',
        name: 'TrackManager',
      );
    } catch (e) {
      developer.log(
        'Error adding danmaku to track: $e',
        name: 'TrackManager',
        error: e,
      );
      rethrow;
    }
  }

  /// 从轨道中移除弹幕
  /// 
  /// [item] 要移除的弹幕对象
  /// 
  /// 返回 true 如果成功移除，false 否则
  bool removeItem(DanmakuItem item) {
    try {
      final trackItems = _trackItems[item.yPosition];
      if (trackItems == null) {
        return false;
      }
      
      final removed = trackItems.remove(item);
      
      if (removed) {
        developer.log(
          'Removed danmaku from track ${item.yPosition}, track size: ${trackItems.length}',
          name: 'TrackManager',
        );
      }
      
      return removed;
    } catch (e) {
      developer.log(
        'Error removing danmaku from track: $e',
        name: 'TrackManager',
        error: e,
      );
      return false;
    }
  }

  /// 批量移除满足条件的弹幕
  /// 
  /// [predicate] 判断条件函数
  /// 
  /// 返回移除的弹幕数量
  int removeWhere(bool Function(DanmakuItem) predicate) {
    int removedCount = 0;
    
    try {
      for (final trackItems in _trackItems.values) {
        final originalLength = trackItems.length;
        trackItems.removeWhere(predicate);
        removedCount += originalLength - trackItems.length;
      }
      
      developer.log(
        'Batch removed $removedCount danmakus',
        name: 'TrackManager',
      );
    } catch (e) {
      developer.log(
        'Error in batch remove: $e',
        name: 'TrackManager',
        error: e,
      );
    }
    
    return removedCount;
  }

  /// 获取指定轨道的弹幕列表
  /// 
  /// [yPosition] 轨道 Y 坐标
  /// 
  /// 返回弹幕列表，如果轨道不存在则返回空列表
  List<DanmakuItem> getTrackItems(double yPosition) {
    return _trackItems[yPosition] ?? <DanmakuItem>[];
  }

  /// 获取所有弹幕列表
  /// 
  /// 返回包含所有轨道弹幕的列表
  List<DanmakuItem> getAllItems() {
    final allItems = <DanmakuItem>[];
    
    try {
      for (final trackItems in _trackItems.values) {
        allItems.addAll(trackItems);
      }
    } catch (e) {
      developer.log(
        'Error getting all items: $e',
        name: 'TrackManager',
        error: e,
      );
    }
    
    return allItems;
  }

  /// 获取轨道统计信息
  /// 
  /// 返回包含各轨道弹幕数量的 Map
  Map<double, int> getTrackStats() {
    final stats = <double, int>{};
    
    try {
      for (final entry in _trackItems.entries) {
        stats[entry.key] = entry.value.length;
      }
    } catch (e) {
      developer.log(
        'Error getting track stats: $e',
        name: 'TrackManager',
        error: e,
      );
    }
    
    return stats;
  }

  /// 查找可用的轨道
  /// 
  /// [isScrollDanmaku] 是否为滚动弹幕
  /// [danmakuWidth] 弹幕宽度（滚动弹幕需要）
  /// [viewWidth] 视图宽度（滚动弹幕需要）
  /// [excludeTopTrack] 是否排除顶部轨道（安全区域）
  /// 
  /// 返回可用轨道的 Y 坐标，如果没有可用轨道则返回 null
  double? findAvailableTrack({
    required bool isScrollDanmaku,
    double? danmakuWidth,
    double? viewWidth,
    bool excludeTopTrack = false,
  }) {
    try {
      final startIndex = excludeTopTrack ? 1 : 0;
      
      for (int i = startIndex; i < _trackYPositions.length; i++) {
        final yPosition = _trackYPositions[i];
        
        if (isScrollDanmaku) {
          if (danmakuWidth != null && viewWidth != null) {
            if (canAddScrollDanmaku(yPosition, danmakuWidth, viewWidth)) {
              return yPosition;
            }
          }
        } else {
          if (canAddStaticDanmaku(yPosition)) {
            return yPosition;
          }
        }
      }
      
      return null;
    } catch (e) {
      developer.log(
        'Error finding available track: $e',
        name: 'TrackManager',
        error: e,
      );
      return null;
    }
  }

  /// 清空所有轨道
  void clear() {
    try {
      _trackItems.clear();
      _trackYPositions.clear();
      
      developer.log(
        'Cleared all tracks',
        name: 'TrackManager',
      );
    } catch (e) {
      developer.log(
        'Error clearing tracks: $e',
        name: 'TrackManager',
        error: e,
      );
    }
  }

  /// 获取轨道管理器统计信息
  Map<String, dynamic> getStats() {
    return {
      'trackCount': trackCount,
      'totalItemCount': totalItemCount,
      'trackStats': getTrackStats(),
    };
  }
}