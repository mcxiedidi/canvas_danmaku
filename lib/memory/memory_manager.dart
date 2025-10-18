import 'dart:async';
import 'dart:developer' as developer;
import '../models/danmaku_item.dart';
import '../pool/danmaku_object_pool.dart';
import '../pool/paragraph_cache_pool.dart';

/// 内存管理器，用于管理弹幕系统的内存使用
/// 
/// 该类负责监控和控制弹幕系统的内存使用，包括：
/// - 弹幕数量限制
/// - 内存清理策略
/// - 对象池管理
/// - 缓存清理
/// 
/// 通过智能的内存管理策略，确保系统在大量弹幕场景下
/// 保持稳定的内存使用和良好的性能表现。
class MemoryManager {
  /// 最大同时存在的弹幕数量
  static const int _maxDanmakuCount = 2000;
  
  /// 内存清理阈值（弹幕数量）
  static const int _cleanupThreshold = 1800;
  
  /// 批量清理数量
  static const int _batchCleanupCount = 200;
  
  /// 内存清理定时器间隔（毫秒）
  static const int _cleanupInterval = 5000;
  
  /// 对象池引用
  final DanmakuObjectPool _objectPool;
  
  /// Paragraph 缓存池引用
  final ParagraphCachePool _paragraphCache;
  
  /// 内存清理定时器
  Timer? _cleanupTimer;
  
  /// 当前弹幕总数
  int _currentDanmakuCount = 0;
  
  /// 清理操作计数器
  int _cleanupCount = 0;
  
  /// 内存警告计数器
  int _memoryWarningCount = 0;
  
  /// 是否启用自动清理
  bool _autoCleanupEnabled = true;

  /// 构造函数
  /// 
  /// [objectPool] DanmakuItem 对象池
  /// [paragraphCache] Paragraph 缓存池
  MemoryManager({
    required DanmakuObjectPool objectPool,
    required ParagraphCachePool paragraphCache,
  }) : _objectPool = objectPool,
       _paragraphCache = paragraphCache {
    _startAutoCleanup();
  }

  /// 获取当前弹幕数量
  int get currentDanmakuCount => _currentDanmakuCount;
  
  /// 获取最大弹幕数量限制
  int get maxDanmakuCount => _maxDanmakuCount;
  
  /// 获取内存使用率
  double get memoryUsageRate => _currentDanmakuCount / _maxDanmakuCount;
  
  /// 是否接近内存限制
  bool get isNearMemoryLimit => _currentDanmakuCount >= _cleanupThreshold;
  
  /// 是否启用自动清理
  bool get isAutoCleanupEnabled => _autoCleanupEnabled;

  /// 检查是否可以添加新弹幕
  /// 
  /// [count] 要添加的弹幕数量，默认为 1
  /// 
  /// 返回 true 如果可以添加，false 否则
  bool canAddDanmaku({int count = 1}) {
    try {
      final newTotal = _currentDanmakuCount + count;
      
      if (newTotal > _maxDanmakuCount) {
        _memoryWarningCount++;
        
        developer.log(
          'Memory limit reached: $newTotal > $_maxDanmakuCount',
          name: 'MemoryManager',
        );
        
        return false;
      }
      
      return true;
    } catch (e) {
      developer.log(
        'Error checking danmaku capacity: $e',
        name: 'MemoryManager',
        error: e,
      );
      return false;
    }
  }

  /// 通知添加了弹幕
  /// 
  /// [count] 添加的弹幕数量，默认为 1
  void notifyDanmakuAdded({int count = 1}) {
    try {
      _currentDanmakuCount += count;
      
      developer.log(
        'Danmaku added: +$count, total: $_currentDanmakuCount',
        name: 'MemoryManager',
      );
      
      // 检查是否需要立即清理
      if (_currentDanmakuCount >= _cleanupThreshold) {
        _triggerImmediateCleanup();
      }
    } catch (e) {
      developer.log(
        'Error notifying danmaku added: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }

  /// 通知移除了弹幕
  /// 
  /// [count] 移除的弹幕数量，默认为 1
  void notifyDanmakuRemoved({int count = 1}) {
    try {
      _currentDanmakuCount = (_currentDanmakuCount - count).clamp(0, _maxDanmakuCount);
      
      developer.log(
        'Danmaku removed: -$count, total: $_currentDanmakuCount',
        name: 'MemoryManager',
      );
    } catch (e) {
      developer.log(
        'Error notifying danmaku removed: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }

  /// 批量清理最旧的弹幕
  /// 
  /// [danmakuLists] 弹幕列表的映射
  /// [cleanupCount] 要清理的数量，默认使用批量清理数量
  /// 
  /// 返回实际清理的弹幕数量
  int batchCleanupOldest(
    Map<String, List<DanmakuItem>> danmakuLists, {
    int? cleanupCount,
  }) {
    try {
      final targetCleanupCount = cleanupCount ?? _batchCleanupCount;
      int totalCleaned = 0;
      
      // 收集所有弹幕并按创建时间排序
      final allDanmaku = <DanmakuItem>[];
      for (final list in danmakuLists.values) {
        allDanmaku.addAll(list);
      }
      
      if (allDanmaku.isEmpty) {
        return 0;
      }
      
      // 按创建时间排序（最旧的在前）
      allDanmaku.sort((a, b) => a.creationTime.compareTo(b.creationTime));
      
      // 清理最旧的弹幕
      final toCleanup = allDanmaku.take(targetCleanupCount).toList();
      
      for (final item in toCleanup) {
        // 从对应列表中移除
        for (final list in danmakuLists.values) {
          if (list.remove(item)) {
            // 释放到对象池
            _objectPool.release(item);
            totalCleaned++;
            break;
          }
        }
      }
      
      if (totalCleaned > 0) {
        notifyDanmakuRemoved(count: totalCleaned);
        _cleanupCount++;
        
        developer.log(
          'Batch cleanup completed: cleaned $totalCleaned items',
          name: 'MemoryManager',
        );
      }
      
      return totalCleaned;
    } catch (e) {
      developer.log(
        'Error in batch cleanup: $e',
        name: 'MemoryManager',
        error: e,
      );
      return 0;
    }
  }

  /// 清理过期的弹幕
  /// 
  /// [danmakuLists] 弹幕列表的映射
  /// [currentTime] 当前时间戳
  /// [maxAge] 最大存活时间（毫秒），默认为 30 秒
  /// 
  /// 返回清理的弹幕数量
  int cleanupExpiredDanmaku(
    Map<String, List<DanmakuItem>> danmakuLists,
    int currentTime, {
    int maxAge = 30000,
  }) {
    try {
      int totalCleaned = 0;
      final expireTime = currentTime - maxAge;
      
      for (final list in danmakuLists.values) {
        final originalLength = list.length;
        
        list.removeWhere((item) {
          if (item.creationTime < expireTime) {
            _objectPool.release(item);
            return true;
          }
          return false;
        });
        
        totalCleaned += originalLength - list.length;
      }
      
      if (totalCleaned > 0) {
        notifyDanmakuRemoved(count: totalCleaned);
        
        developer.log(
          'Expired danmaku cleanup: cleaned $totalCleaned items',
          name: 'MemoryManager',
        );
      }
      
      return totalCleaned;
    } catch (e) {
      developer.log(
        'Error cleaning expired danmaku: $e',
        name: 'MemoryManager',
        error: e,
      );
      return 0;
    }
  }

  /// 强制内存清理
  /// 
  /// 清理所有缓存和对象池，释放内存
  void forceMemoryCleanup() {
    try {
      // 清理 Paragraph 缓存
      _paragraphCache.clear();
      
      // 清理对象池
      _objectPool.clear();
      
      // 重置计数器
      _currentDanmakuCount = 0;
      _cleanupCount++;
      
      developer.log(
        'Force memory cleanup completed',
        name: 'MemoryManager',
      );
    } catch (e) {
      developer.log(
        'Error in force memory cleanup: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }

  /// 启用或禁用自动清理
  /// 
  /// [enabled] 是否启用自动清理
  void setAutoCleanupEnabled(bool enabled) {
    try {
      _autoCleanupEnabled = enabled;
      
      if (enabled) {
        _startAutoCleanup();
      } else {
        _stopAutoCleanup();
      }
      
      developer.log(
        'Auto cleanup ${enabled ? 'enabled' : 'disabled'}',
        name: 'MemoryManager',
      );
    } catch (e) {
      developer.log(
        'Error setting auto cleanup: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }

  /// 启动自动清理定时器
  void _startAutoCleanup() {
    if (_cleanupTimer != null) {
      return;
    }
    
    _cleanupTimer = Timer.periodic(
      Duration(milliseconds: _cleanupInterval),
      (_) => _performAutoCleanup(),
    );
    
    developer.log(
      'Auto cleanup timer started',
      name: 'MemoryManager',
    );
  }

  /// 停止自动清理定时器
  void _stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    
    developer.log(
      'Auto cleanup timer stopped',
      name: 'MemoryManager',
    );
  }

  /// 执行自动清理
  void _performAutoCleanup() {
    try {
      if (!_autoCleanupEnabled) {
        return;
      }
      
      // 清理 Paragraph 缓存（如果缓存过大）
      final cacheStats = _paragraphCache.getStats();
      final totalCacheSize = cacheStats['totalCacheSize'] as int;
      
      if (totalCacheSize > 300) {
        _paragraphCache.clear();
        
        developer.log(
          'Auto cleanup: cleared paragraph cache (size: $totalCacheSize)',
          name: 'MemoryManager',
        );
      }
      
      // 如果对象池过大，清理一部分
      if (_objectPool.poolSize > 500) {
        _objectPool.clear();
        
        developer.log(
          'Auto cleanup: cleared object pool (size: ${_objectPool.poolSize})',
          name: 'MemoryManager',
        );
      }
    } catch (e) {
      developer.log(
        'Error in auto cleanup: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }

  /// 触发立即清理
  void _triggerImmediateCleanup() {
    developer.log(
      'Triggering immediate cleanup due to memory pressure',
      name: 'MemoryManager',
    );
    
    _performAutoCleanup();
  }

  /// 获取内存管理统计信息
  Map<String, dynamic> getStats() {
    return {
      'currentDanmakuCount': _currentDanmakuCount,
      'maxDanmakuCount': _maxDanmakuCount,
      'memoryUsageRate': memoryUsageRate,
      'cleanupThreshold': _cleanupThreshold,
      'cleanupCount': _cleanupCount,
      'memoryWarningCount': _memoryWarningCount,
      'autoCleanupEnabled': _autoCleanupEnabled,
      'objectPoolStats': _objectPool.getStats(),
      'paragraphCacheStats': _paragraphCache.getStats(),
    };
  }

  /// 释放资源
  void dispose() {
    try {
      _stopAutoCleanup();
      
      developer.log(
        'MemoryManager disposed',
        name: 'MemoryManager',
      );
    } catch (e) {
      developer.log(
        'Error disposing MemoryManager: $e',
        name: 'MemoryManager',
        error: e,
      );
    }
  }
}