import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/danmaku_content_item.dart';
import '../utils/utils.dart';

/// Paragraph 缓存池，用于复用 ui.Paragraph 对象
/// 
/// 该类实现了 Paragraph 对象的缓存和复用机制。
/// ui.Paragraph 的创建成本很高，特别是在大量弹幕场景下。
/// 通过缓存相同样式的 Paragraph 对象，可以显著提升性能。
/// 
/// 缓存策略：
/// - 使用文本内容、字体大小、字重等作为缓存键
/// - LRU 淘汰策略，自动清理最久未使用的缓存
/// - 限制缓存大小防止内存泄漏
class ParagraphCachePool {
  /// 普通文本 Paragraph 缓存
  final Map<String, _CacheEntry> _textCache = <String, _CacheEntry>{};
  
  /// 描边文本 Paragraph 缓存
  final Map<String, _CacheEntry> _strokeCache = <String, _CacheEntry>{};
  
  /// 缓存访问顺序队列（LRU）
  final Queue<String> _accessOrder = Queue<String>();
  
  /// 最大缓存条目数
  static const int _maxCacheSize = 500;
  
  /// 缓存命中次数
  int _hitCount = 0;
  
  /// 缓存未命中次数
  int _missCount = 0;
  
  /// 获取缓存命中率
  double get hitRate => (_hitCount + _missCount) > 0 
      ? _hitCount / (_hitCount + _missCount) 
      : 0.0;

  /// 获取或创建 Paragraph（兼容性方法）
  /// 
  /// [cacheKey] 缓存键
  /// [text] 文本内容
  /// [style] 文本样式
  /// [isStroke] 是否为描边文本
  /// 
  /// 返回 ui.Paragraph 对象
  ui.Paragraph getOrCreateParagraph(
    String cacheKey,
    String text,
    TextStyle style,
    bool isStroke,
  ) {
    try {
      final cache = isStroke ? _strokeCache : _textCache;
      
      // 检查缓存
      final cachedEntry = cache[cacheKey];
      if (cachedEntry != null) {
        _hitCount++;
        _updateAccessOrder(cacheKey);
        return cachedEntry.paragraph;
      }
      
      // 缓存未命中，创建新的 Paragraph
      _missCount++;
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textDirection: TextDirection.ltr,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
      ));
      
      builder.pushStyle(ui.TextStyle(
        color: style.color,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
      ));
      
      builder.addText(text);
      
      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
      
      // 添加到缓存
      _addToCache(cache, cacheKey, paragraph);
      
      return paragraph;
    } catch (e) {
      developer.log(
        'Error in getOrCreateParagraph: $e',
        name: 'ParagraphCachePool',
        error: e,
      );
      
      // 出错时创建简单的 Paragraph
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textDirection: TextDirection.ltr,
      ));
      builder.addText(text);
      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
      return paragraph;
    }
  }

  /// 获取或创建普通文本 Paragraph
  /// 
  /// [content] 弹幕内容
  /// [danmakuWidth] 弹幕宽度
  /// [fontSize] 字体大小
  /// [fontWeight] 字重
  /// [size] 尺寸（可选）
  /// [screenSize] 屏幕尺寸（可选）
  /// 
  /// 返回 ui.Paragraph 对象
  ui.Paragraph getTextParagraph({
    required DanmakuContentItem content,
    required double danmakuWidth,
    required double fontSize,
    required int fontWeight,
    ui.Size? size,
    ui.Size? screenSize,
  }) {
    try {
      final cacheKey = _generateTextCacheKey(
        content, danmakuWidth, fontSize, fontWeight, size, screenSize);
      
      // 检查缓存
      final cachedEntry = _textCache[cacheKey];
      if (cachedEntry != null) {
        _hitCount++;
        _updateAccessOrder(cacheKey);
        
        developer.log(
          'Text paragraph cache hit: $cacheKey',
          name: 'ParagraphCachePool',
        );
        
        return cachedEntry.paragraph;
      }
      
      // 缓存未命中，创建新的 Paragraph
      _missCount++;
      final paragraph = Utils.generateParagraph(
        content: content,
        danmakuWidth: danmakuWidth,
        fontSize: fontSize,
        fontWeight: fontWeight,
        size: size,
        screenSize: screenSize,
      );
      
      // 添加到缓存
      _addToCache(_textCache, cacheKey, paragraph);
      
      developer.log(
        'Created and cached text paragraph: $cacheKey',
        name: 'ParagraphCachePool',
      );
      
      return paragraph;
    } catch (e) {
      developer.log(
        'Error getting text paragraph: $e',
        name: 'ParagraphCachePool',
        error: e,
      );
      
      // 发生错误时直接创建，不缓存
      return Utils.generateParagraph(
        content: content,
        danmakuWidth: danmakuWidth,
        fontSize: fontSize,
        fontWeight: fontWeight,
        size: size,
        screenSize: screenSize,
      );
    }
  }

  /// 获取或创建描边文本 Paragraph
  /// 
  /// [content] 弹幕内容
  /// [danmakuWidth] 弹幕宽度
  /// [fontSize] 字体大小
  /// [fontWeight] 字重
  /// [strokeWidth] 描边宽度
  /// [size] 尺寸（可选）
  /// [offset] 偏移（可选）
  /// [screenSize] 屏幕尺寸（可选）
  /// 
  /// 返回 ui.Paragraph 对象
  ui.Paragraph getStrokeParagraph({
    required DanmakuContentItem content,
    required double danmakuWidth,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
    ui.Size? size,
    ui.Offset? offset,
    ui.Size? screenSize,
  }) {
    try {
      final cacheKey = _generateStrokeCacheKey(
        content, danmakuWidth, fontSize, fontWeight, strokeWidth, 
        size, offset, screenSize);
      
      // 检查缓存
      final cachedEntry = _strokeCache[cacheKey];
      if (cachedEntry != null) {
        _hitCount++;
        _updateAccessOrder(cacheKey);
        
        developer.log(
          'Stroke paragraph cache hit: $cacheKey',
          name: 'ParagraphCachePool',
        );
        
        return cachedEntry.paragraph;
      }
      
      // 缓存未命中，创建新的 Paragraph
      _missCount++;
      final paragraph = Utils.generateStrokeParagraph(
        content: content,
        danmakuWidth: danmakuWidth,
        fontSize: fontSize,
        fontWeight: fontWeight,
        strokeWidth: strokeWidth,
        size: size,
        offset: offset,
        screenSize: screenSize,
      );
      
      // 添加到缓存
      _addToCache(_strokeCache, cacheKey, paragraph);
      
      developer.log(
        'Created and cached stroke paragraph: $cacheKey',
        name: 'ParagraphCachePool',
      );
      
      return paragraph;
    } catch (e) {
      developer.log(
        'Error getting stroke paragraph: $e',
        name: 'ParagraphCachePool',
        error: e,
      );
      
      // 发生错误时直接创建，不缓存
      return Utils.generateStrokeParagraph(
        content: content,
        danmakuWidth: danmakuWidth,
        fontSize: fontSize,
        fontWeight: fontWeight,
        strokeWidth: strokeWidth,
        size: size,
        offset: offset,
        screenSize: screenSize,
      );
    }
  }

  /// 生成文本缓存键
  String _generateTextCacheKey(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
    ui.Size? size,
    ui.Size? screenSize,
  ) {
    return 'text_${content.text}_${content.color.value}_'
           '${danmakuWidth}_${fontSize}_${fontWeight}_'
           '${size?.width ?? 0}_${size?.height ?? 0}_'
           '${screenSize?.width ?? 0}_${screenSize?.height ?? 0}_'
           '${content.isColorful}';
  }

  /// 生成描边缓存键
  String _generateStrokeCacheKey(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
    double strokeWidth,
    ui.Size? size,
    ui.Offset? offset,
    ui.Size? screenSize,
  ) {
    return 'stroke_${content.text}_${content.color.value}_'
           '${danmakuWidth}_${fontSize}_${fontWeight}_${strokeWidth}_'
           '${size?.width ?? 0}_${size?.height ?? 0}_'
           '${offset?.dx ?? 0}_${offset?.dy ?? 0}_'
           '${screenSize?.width ?? 0}_${screenSize?.height ?? 0}_'
           '${content.isColorful}';
  }

  /// 添加到缓存
  void _addToCache(Map<String, _CacheEntry> cache, String key, ui.Paragraph paragraph) {
    // 检查缓存大小，必要时清理
    if (cache.length >= _maxCacheSize) {
      _evictLeastRecentlyUsed(cache);
    }
    
    cache[key] = _CacheEntry(paragraph, DateTime.now().millisecondsSinceEpoch);
    _accessOrder.add(key);
  }

  /// 更新访问顺序
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// 淘汰最久未使用的缓存项
  void _evictLeastRecentlyUsed(Map<String, _CacheEntry> cache) {
    if (_accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeFirst();
      final entry = cache.remove(oldestKey);
      entry?.paragraph.dispose();
      
      developer.log(
        'Evicted cache entry: $oldestKey',
        name: 'ParagraphCachePool',
      );
    }
  }

  /// 清空所有缓存
  void clear() {
    try {
      // 释放所有 Paragraph 对象
      for (final entry in _textCache.values) {
        entry.paragraph.dispose();
      }
      for (final entry in _strokeCache.values) {
        entry.paragraph.dispose();
      }
      
      _textCache.clear();
      _strokeCache.clear();
      _accessOrder.clear();
      
      // 重置统计信息
      _hitCount = 0;
      _missCount = 0;
      
      developer.log(
        'Cleared all paragraph caches',
        name: 'ParagraphCachePool',
      );
    } catch (e) {
      developer.log(
        'Error clearing paragraph caches: $e',
        name: 'ParagraphCachePool',
        error: e,
      );
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'textCacheSize': _textCache.length,
      'strokeCacheSize': _strokeCache.length,
      'totalCacheSize': _textCache.length + _strokeCache.length,
      'hitCount': _hitCount,
      'missCount': _missCount,
      'hitRate': hitRate,
      'maxCacheSize': _maxCacheSize,
    };
  }
}

/// 缓存条目
class _CacheEntry {
  final ui.Paragraph paragraph;
  final int timestamp;
  
  _CacheEntry(this.paragraph, this.timestamp);
}