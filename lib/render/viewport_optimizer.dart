import 'dart:developer' as developer;
import 'dart:ui' as ui;
import '../models/danmaku_item.dart';

/// 视口优化器，用于实现视口裁剪和可见性检测
/// 
/// 该类负责优化弹幕渲染性能，只绘制可见区域内的弹幕。
/// 通过提前计算弹幕的可见性，避免绘制屏幕外的弹幕，
/// 显著提升大量弹幕场景下的渲染性能。
/// 
/// 主要功能：
/// - 视口边界检测
/// - 弹幕可见性计算
/// - 批量可见性过滤
/// - 渲染区域优化
class ViewportOptimizer {
  /// 视口宽度
  double _viewportWidth = 0;
  
  /// 视口高度
  double _viewportHeight = 0;

  /// 构造函数
  /// 
  /// [viewportWidth] 视口宽度（可选）
  /// [viewportHeight] 视口高度（可选）
  ViewportOptimizer({
    double? viewportWidth,
    double? viewportHeight,
  }) {
    if (viewportWidth != null && viewportHeight != null) {
      updateViewport(viewportWidth, viewportHeight);
    }
  }
  
  /// 扩展边界（用于预加载即将进入视口的弹幕）
  static const double _expandBoundary = 100.0;
  
  /// 可见性检测计数器
  int _visibilityCheckCount = 0;
  
  /// 过滤的弹幕数量
  int _filteredCount = 0;

  /// 获取视口宽度
  double get viewportWidth => _viewportWidth;
  
  /// 获取视口高度
  double get viewportHeight => _viewportHeight;
  
  /// 获取可见性检测统计信息
  Map<String, int> get stats => {
    'visibilityChecks': _visibilityCheckCount,
    'filteredItems': _filteredCount,
  };

  /// 更新视口尺寸
  /// 
  /// [width] 视口宽度
  /// [height] 视口高度
  /// 
  /// 抛出 [ArgumentError] 如果尺寸为负数
  void updateViewport(double width, double height) {
    try {
      if (width < 0 || height < 0) {
        throw ArgumentError('Viewport dimensions must be non-negative');
      }
      
      final sizeChanged = _viewportWidth != width || _viewportHeight != height;
      
      _viewportWidth = width;
      _viewportHeight = height;
      
      if (sizeChanged) {
        developer.log(
          'Updated viewport size: ${width}x${height}',
          name: 'ViewportOptimizer',
        );
      }
    } catch (e) {
      developer.log(
        'Error updating viewport: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      rethrow;
    }
  }

  /// 检查弹幕是否在视口内可见
  /// 
  /// [item] 弹幕对象
  /// [includeExpanded] 是否包含扩展边界，默认为 true
  /// 
  /// 返回 true 如果弹幕可见，false 否则
  bool isItemVisible(DanmakuItem item, {bool includeExpanded = true}) {
    try {
      _visibilityCheckCount++;
      
      final expandBoundary = includeExpanded ? _expandBoundary : 0.0;
      
      // 检查水平方向可见性
      final leftBound = -expandBoundary;
      final rightBound = _viewportWidth + expandBoundary;
      
      if (item.xPosition + item.width < leftBound || 
          item.xPosition > rightBound) {
        return false;
      }
      
      // 检查垂直方向可见性
      final topBound = -expandBoundary;
      final bottomBound = _viewportHeight + expandBoundary;
      
      if (item.yPosition + item.height < topBound || 
          item.yPosition > bottomBound) {
        return false;
      }
      
      return true;
    } catch (e) {
      developer.log(
        'Error checking item visibility: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      return true; // 出错时默认可见，确保不丢失弹幕
    }
  }

  /// 过滤可见的弹幕列表
  /// 
  /// [items] 弹幕列表
  /// [includeExpanded] 是否包含扩展边界，默认为 true
  /// 
  /// 返回可见的弹幕列表
  List<DanmakuItem> filterVisibleItems(
    List<DanmakuItem> items, {
    bool includeExpanded = true,
  }) {
    try {
      if (items.isEmpty) {
        return items;
      }
      
      final visibleItems = <DanmakuItem>[];
      int filteredCount = 0;
      
      for (final item in items) {
        if (isItemVisible(item, includeExpanded: includeExpanded)) {
          visibleItems.add(item);
        } else {
          filteredCount++;
        }
      }
      
      _filteredCount += filteredCount;
      
      if (filteredCount > 0) {
        developer.log(
          'Filtered ${filteredCount} invisible items, visible: ${visibleItems.length}',
          name: 'ViewportOptimizer',
        );
      }
      
      return visibleItems;
    } catch (e) {
      developer.log(
        'Error filtering visible items: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      return items; // 出错时返回原列表
    }
  }

  /// 批量过滤多个弹幕列表的可见项
  /// 
  /// [scrollItems] 滚动弹幕列表
  /// [topItems] 顶部弹幕列表
  /// [bottomItems] 底部弹幕列表
  /// [specialItems] 特殊弹幕列表
  /// 
  /// 返回包含所有可见弹幕列表的 Map
  Map<String, List<DanmakuItem>> batchFilterVisible({
    List<DanmakuItem>? scrollItems,
    List<DanmakuItem>? topItems,
    List<DanmakuItem>? bottomItems,
    List<DanmakuItem>? specialItems,
  }) {
    try {
      final result = <String, List<DanmakuItem>>{};
      
      if (scrollItems != null) {
        result['scroll'] = filterVisibleItems(scrollItems);
      }
      
      if (topItems != null) {
        result['top'] = filterVisibleItems(topItems);
      }
      
      if (bottomItems != null) {
        result['bottom'] = filterVisibleItems(bottomItems);
      }
      
      if (specialItems != null) {
        result['special'] = filterVisibleItems(specialItems);
      }
      
      developer.log(
        'Batch filtered visible items',
        name: 'ViewportOptimizer',
      );
      
      return result;
    } catch (e) {
      developer.log(
        'Error in batch filter: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      
      // 出错时返回原列表
      return {
        if (scrollItems != null) 'scroll': scrollItems,
        if (topItems != null) 'top': topItems,
        if (bottomItems != null) 'bottom': bottomItems,
        if (specialItems != null) 'special': specialItems,
      };
    }
  }

  /// 检查弹幕是否完全在视口外（用于清理）
  /// 
  /// [item] 弹幕对象
  /// 
  /// 返回 true 如果弹幕完全在视口外，false 否则
  bool isItemCompletelyOutside(DanmakuItem item) {
    try {
      // 检查水平方向
      if (item.xPosition + item.width < 0 || 
          item.xPosition > _viewportWidth) {
        return true;
      }
      
      // 检查垂直方向
      if (item.yPosition + item.height < 0 || 
          item.yPosition > _viewportHeight) {
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log(
        'Error checking if item is completely outside: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      return false;
    }
  }

  /// 计算弹幕在视口中的可见区域
  /// 
  /// [item] 弹幕对象
  /// 
  /// 返回可见区域的 Rect，如果不可见则返回 null
  ui.Rect? getVisibleRect(DanmakuItem item) {
    try {
      if (!isItemVisible(item, includeExpanded: false)) {
        return null;
      }
      
      final left = item.xPosition.clamp(0.0, _viewportWidth);
      final top = item.yPosition.clamp(0.0, _viewportHeight);
      final right = (item.xPosition + item.width).clamp(0.0, _viewportWidth);
      final bottom = (item.yPosition + item.height).clamp(0.0, _viewportHeight);
      
      if (left >= right || top >= bottom) {
        return null;
      }
      
      return ui.Rect.fromLTRB(left, top, right, bottom);
    } catch (e) {
      developer.log(
        'Error calculating visible rect: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      return null;
    }
  }

  /// 预测弹幕未来位置的可见性
  /// 
  /// [item] 弹幕对象
  /// [deltaTime] 时间增量（毫秒）
  /// [speed] 弹幕移动速度（像素/毫秒）
  /// 
  /// 返回 true 如果未来位置可见，false 否则
  bool predictVisibility(DanmakuItem item, int deltaTime, double speed) {
    try {
      // 计算未来位置
      final futureX = item.xPosition - (speed * deltaTime);
      
      // 创建临时对象用于可见性检测
      final futureItem = DanmakuItem(
        content: item.content,
        creationTime: item.creationTime,
        width: item.width,
        height: item.height,
        xPosition: futureX,
        yPosition: item.yPosition,
      );
      
      return isItemVisible(futureItem);
    } catch (e) {
      developer.log(
        'Error predicting visibility: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
      return true;
    }
  }

  /// 重置统计信息
  void resetStats() {
    try {
      _visibilityCheckCount = 0;
      _filteredCount = 0;
      
      developer.log(
        'Reset viewport optimizer stats',
        name: 'ViewportOptimizer',
      );
    } catch (e) {
      developer.log(
        'Error resetting stats: $e',
        name: 'ViewportOptimizer',
        error: e,
      );
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'viewportWidth': _viewportWidth,
      'viewportHeight': _viewportHeight,
      'expandBoundary': _expandBoundary,
      'visibilityCheckCount': _visibilityCheckCount,
      'filteredCount': _filteredCount,
      'filterRate': _visibilityCheckCount > 0 
          ? _filteredCount / _visibilityCheckCount 
          : 0.0,
    };
  }

  /// 获取详细的统计信息
  Map<String, dynamic> getDetailedStats() {
    return getStats();
  }
}