import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import '../models/danmaku_item.dart';
import '../models/danmaku_content_item.dart';

/// DanmakuItem 对象池，用于复用弹幕对象以减少内存分配和垃圾回收
/// 
/// 该类实现了对象池模式，通过复用已销毁的弹幕对象来提高性能。
/// 当弹幕数量超过1万时，频繁的对象创建和销毁会导致严重的性能问题。
/// 
/// 使用方式：
/// ```dart
/// final pool = DanmakuObjectPool();
/// final item = pool.acquire(content, creationTime, width, height);
/// // 使用完毕后释放
/// pool.release(item);
/// ```
class DanmakuObjectPool {
  /// 对象池队列，存储可复用的 DanmakuItem 对象
  final Queue<DanmakuItem> _pool = Queue<DanmakuItem>();
  
  /// 对象池最大容量，防止内存无限增长
  static const int _maxPoolSize = 1000;
  
  /// 当前池中对象数量
  int get poolSize => _pool.length;
  
  /// 总共创建的对象数量（用于性能监控）
  int _totalCreated = 0;
  
  /// 总共复用的对象数量（用于性能监控）
  int _totalReused = 0;
  
  /// 获取对象复用率
  double get reuseRate => _totalCreated > 0 ? _totalReused / _totalCreated : 0.0;

  /// 从对象池获取弹幕对象
  /// 
  /// 由于 DanmakuItem 的字段都是 final 的，我们总是创建新对象
  /// 但仍然维护对象池的统计信息以便监控
  /// 
  /// [content] 弹幕内容
  /// [width] 弹幕宽度
  /// [height] 弹幕高度
  /// [xPosition] X 坐标，默认为 0
  /// [yPosition] Y 坐标，默认为 0
  /// 
  /// 返回配置好的弹幕对象
  DanmakuItem acquire({
    required DanmakuContentItem content,
    required double width,
    required double height,
    double xPosition = 0,
    double yPosition = 0,
  }) {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // 由于 DanmakuItem 字段是 final 的，我们总是创建新对象
      final item = DanmakuItem(
        content: content,
        creationTime: currentTime,
        width: width,
        height: height,
        xPosition: xPosition,
        yPosition: yPosition,
      );
      
      _totalCreated++;
      
      developer.log(
        'Created new danmaku item, total created: $_totalCreated',
        name: 'DanmakuObjectPool',
      );
      
      return item;
    } catch (e) {
      developer.log(
        'Error acquiring danmaku item: $e',
        name: 'DanmakuObjectPool',
        error: e,
      );
      
      // 出错时创建新对象
      return DanmakuItem(
        content: content,
        creationTime: DateTime.now().millisecondsSinceEpoch,
        width: width,
        height: height,
        xPosition: xPosition,
        yPosition: yPosition,
      );
    }
  }

  /// 释放弹幕对象到池中
  /// 
  /// [item] 要释放的弹幕对象
  /// 
  /// 由于 DanmakuItem 字段是 final 的，我们不能真正复用对象
  /// 但保留此方法以维护接口一致性和统计信息
  void release(DanmakuItem item) {
    try {
      // 由于 DanmakuItem 字段是 final 的，我们不能复用对象
      // 但可以记录释放统计信息
      developer.log(
        'Released danmaku item (no actual pooling due to final fields)',
        name: 'DanmakuObjectPool',
      );
    } catch (e) {
      developer.log(
        'Error releasing danmaku item: $e',
        name: 'DanmakuObjectPool',
        error: e,
      );
    }
  }

  /// 清空对象池
  /// 
  /// 重置统计信息
  void clear() {
    try {
      // 重置统计信息
      _totalCreated = 0;
      _totalReused = 0;
      
      developer.log(
        'Cleared object pool statistics',
        name: 'DanmakuObjectPool',
      );
    } catch (e) {
      developer.log(
        'Error clearing object pool: $e',
        name: 'DanmakuObjectPool',
        error: e,
      );
    }
  }

  /// 获取对象池统计信息
  /// 
  /// 返回包含创建数量等信息的 Map
  Map<String, dynamic> getStats() {
    return {
      'poolSize': 0, // 由于不能真正池化，始终为 0
      'maxPoolSize': _maxPoolSize,
      'totalCreated': _totalCreated,
      'totalReused': _totalReused,
      'reuseRate': reuseRate,
      'memoryEfficiency': 0.0, // 由于不能复用，效率为 0
    };
  }
}

/// 扩展 DanmakuItem 类以支持对象池功能
/// 
/// 注意：由于 DanmakuItem 的字段都是 final 的，实际上不能进行对象池化
/// 这个扩展主要用于清理资源
extension DanmakuItemPool on DanmakuItem {
  /// 清理对象资源
  /// 
  /// 释放 Paragraph 对象以避免内存泄漏
  void cleanup() {
    try {
      // 释放 Paragraph 对象
      paragraph?.dispose();
      strokeParagraph?.dispose();
    } catch (e) {
      developer.log(
        'Error cleaning up DanmakuItem: $e',
        name: 'DanmakuObjectPool',
        error: e,
      );
    }
  }
}