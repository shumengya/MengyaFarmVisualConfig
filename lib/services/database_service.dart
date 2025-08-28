import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MongoDB数据库服务类
/// 提供数据库连接、集合操作、文档CRUD等功能
/// 使用单例模式确保全局唯一实例
class DatabaseService {
  // ==================== 常量定义 ====================
  
  /// 默认数据库连接字符串
  static const String _defaultConnectionString =
      'mongodb://192.168.31.205:27017/mengyafarm';
  
  /// 默认集合名称
  static const String _defaultCollectionName = 'gameconfig';
  
  /// SharedPreferences存储键名
  static const String _connectionStringKey = 'database_connection_string';
  static const String _usernameKey = 'database_username';
  static const String _passwordKey = 'database_password';
  static const String _hostKey = 'database_host';
  static const String _portKey = 'database_port';
  static const String _databaseKey = 'database_name';

  // ==================== 私有变量 ====================
  
  /// MongoDB数据库实例
  late Db _db;
  
  /// 当前操作的集合实例
  late DbCollection _collection;
  
  /// 当前使用的连接字符串
  String _currentConnectionString = _defaultConnectionString;
  
  /// 当前操作的集合名称
  String _currentCollectionName = _defaultCollectionName;

  // ==================== 单例模式实现 ====================
  
  /// 单例实例
  static final DatabaseService _instance = DatabaseService._internal();
  
  /// 工厂构造函数，返回单例实例
  factory DatabaseService() => _instance;
  
  /// 私有构造函数
  DatabaseService._internal();

  // ==================== 配置管理方法 ====================
  
  /// 获取保存的数据库连接字符串
  /// 如果没有保存过，则返回默认连接字符串
  /// 
  /// Returns: 数据库连接字符串
  Future<String> getSavedConnectionString() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_connectionStringKey) ?? _defaultConnectionString;
  }

  /// 保存数据库连接字符串到本地存储
  /// 
  /// [connectionString] 要保存的连接字符串
  Future<void> saveConnectionString(String connectionString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionStringKey, connectionString);
    _currentConnectionString = connectionString;
  }

  /// 保存数据库连接参数到本地存储
  /// 根据提供的参数构建完整的MongoDB连接字符串
  /// 
  /// [host] 数据库服务器地址
  /// [port] 数据库端口号
  /// [database] 数据库名称
  /// [username] 可选的用户名（用于认证）
  /// [password] 可选的密码（用于认证）
  Future<void> saveDatabaseConfig({
    required String host,
    required String port,
    required String database,
    String? username,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 保存各个连接参数
    await prefs.setString(_hostKey, host);
    await prefs.setString(_portKey, port);
    await prefs.setString(_databaseKey, database);
    
    // 处理可选的认证信息
    if (username != null && username.isNotEmpty) {
      await prefs.setString(_usernameKey, username);
    } else {
      await prefs.remove(_usernameKey);
    }
    if (password != null && password.isNotEmpty) {
      await prefs.setString(_passwordKey, password);
    } else {
      await prefs.remove(_passwordKey);
    }
    
    // 根据是否有认证信息构建不同格式的连接字符串
    String connectionString;
    if (username != null && username.isNotEmpty && password != null && password.isNotEmpty) {
      // 有认证信息时，需要URL编码用户名和密码中的特殊字符
      final encodedUsername = Uri.encodeComponent(username);
      final encodedPassword = Uri.encodeComponent(password);
      connectionString = 'mongodb://$encodedUsername:$encodedPassword@$host:$port/$database';
    } else {
      // 无认证信息的简单连接字符串
      connectionString = 'mongodb://$host:$port/$database';
    }
    
    // 保存构建好的连接字符串
    await saveConnectionString(connectionString);
  }

  /// 获取保存的数据库连接参数
  /// 从本地存储中读取之前保存的连接配置
  /// 
  /// Returns: 包含连接参数的Map，键包括：
  ///   - 'host': 数据库服务器地址
  ///   - 'port': 数据库端口号
  ///   - 'database': 数据库名称
  ///   - 'username': 用户名（可能为null）
  ///   - 'password': 密码（可能为null）
  Future<Map<String, String?>> getSavedDatabaseConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'host': prefs.getString(_hostKey) ?? '192.168.31.205',
      'port': prefs.getString(_portKey) ?? '27017',
      'database': prefs.getString(_databaseKey) ?? 'mengyafarm',
      'username': prefs.getString(_usernameKey),
      'password': prefs.getString(_passwordKey),
    };
  }

  // ==================== 数据库连接管理方法 ====================
  
  /// 连接到MongoDB数据库
  /// 支持使用指定连接字符串或从本地配置自动构建连接字符串
  /// 连接成功后会自动设置默认集合
  /// 
  /// [connectionString] 可选的连接字符串，如果不提供则使用保存的数据库配置
  /// 
  /// Throws: 连接失败时抛出异常
  Future<void> connect([String? connectionString]) async {
    try {
      // 确定要使用的连接字符串
      if (connectionString != null) {
        _currentConnectionString = connectionString;
        print('使用提供的连接字符串');
      } else {
        // 从本地存储读取数据库配置并构建连接字符串
        print('从本地配置构建连接字符串');
        final config = await getSavedDatabaseConfig();
        final host = config['host'] ?? '192.168.31.205';
        final port = config['port'] ?? '27017';
        final database = config['database'] ?? 'mengyafarm';
        final username = config['username'];
        final password = config['password'];
        
        // 根据是否有认证信息构建不同格式的连接字符串
        if (username != null && username.isNotEmpty && password != null && password.isNotEmpty) {
           // 对用户名和密码进行URL编码以处理特殊字符
           final encodedUsername = Uri.encodeComponent(username);
           final encodedPassword = Uri.encodeComponent(password);
           _currentConnectionString = 'mongodb://$encodedUsername:$encodedPassword@$host:$port/$database?authSource=admin';
           print('使用认证连接字符串');
         } else {
           _currentConnectionString = 'mongodb://$host:$port/$database';
           print('使用无认证连接字符串');
         }
      }

      print('正在连接到数据库: $_currentConnectionString');
      
      // 创建数据库连接实例
      _db = await Db.create(_currentConnectionString);
      
      // 打开数据库连接
      await _db.open();
      
      // 设置默认集合
      _collection = _db.collection(_currentCollectionName);
      
      print('MongoDB连接成功');
      print('数据库名称: ${_db.databaseName}');
      print('当前集合: $_currentCollectionName');
      
    } catch (e) {
      print('MongoDB连接失败: $e');
      print('连接字符串: $_currentConnectionString');
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  /// 获取当前使用的数据库连接字符串
  /// 
  /// Returns: 当前连接字符串
  String get currentConnectionString => _currentConnectionString;

  /// 断开数据库连接
  /// 安全地关闭数据库连接，即使出现错误也不会抛出异常
  /// 
  /// 注意：断开连接后需要重新调用connect()才能继续使用数据库功能
  Future<void> disconnect() async {
    try {
      if (_db.isConnected) {
        await _db.close();
        print('MongoDB连接已成功断开');
      } else {
        print('数据库连接已经处于断开状态');
      }
    } catch (e) {
      print('断开MongoDB连接时出错: $e');
      // 不重新抛出异常，确保断开操作总是"成功"完成
    }
  }

  /// 切换到指定的数据库集合
  /// 切换后所有的数据库操作都将在新集合上进行
  /// 
  /// [collectionName] 要切换到的集合名称
  /// 
  /// 注意：此方法不会验证集合是否存在，如果集合不存在，
  /// 在第一次写入操作时MongoDB会自动创建该集合
  void switchCollection(String collectionName) {
    if (collectionName.isEmpty) {
      throw ArgumentError('集合名称不能为空');
    }
    
    _currentCollectionName = collectionName;
    _collection = _db.collection(collectionName);
    print('已切换到集合: $collectionName');
  }

  /// 获取当前操作的集合名称
  /// 返回当前数据库操作所针对的集合名称
  /// 
  /// Returns: 当前集合名称（String）
  String get currentCollectionName => _currentCollectionName;
  
  /// 插入新文档到当前集合
  /// 向当前选择的集合中添加一个新的文档
  /// 
  /// [document] 要插入的文档数据，格式为Map<String, dynamic>
  /// 
  /// Returns: 插入成功返回新文档的ObjectId，失败返回null
  /// 
  /// 使用示例：
  /// ```dart
  /// final newDoc = {'name': 'config1', 'type': 'weapon', 'level': 1};
  /// final id = await dbService.insertDocument(newDoc);
  /// ```
  Future<ObjectId?> insertDocument(Map<String, dynamic> document) async {
    try {
      final result = await _collection.insertOne(document);
      if (result.isSuccess) {
        print('成功插入文档，ID: ${result.id}');
        return result.id;
      } else {
        print('插入文档失败');
        return null;
      }
    } catch (e) {
      print('插入文档时发生错误: $e');
      return null;
    }
  }
  
  /// 删除指定ID的文档
  /// 根据ObjectId从当前集合中删除指定文档
  /// 
  /// [id] 要删除的文档ID（十六进制字符串格式）
  /// 
  /// Returns: 删除成功返回true，失败返回false
  /// 
  /// 使用示例：
  /// ```dart
  /// final success = await dbService.deleteDocument('507f1f77bcf86cd799439011');
  /// ```
  Future<bool> deleteDocument(String id) async {
    try {
      final objectId = ObjectId.fromHexString(id);
      final result = await _collection.deleteOne(where.id(objectId));
      
      if (result.isSuccess && result.nRemoved > 0) {
        print('成功删除文档 $id');
        return true;
      } else {
        print('删除文档失败: 没有找到匹配的文档');
        return false;
      }
    } catch (e) {
      print('删除文档时发生错误: $e');
      return false;
    }
  }
  
  /// 批量插入文档
  /// 一次性向当前集合插入多个文档，提高插入效率
  /// 
  /// [documents] 要插入的文档列表，每个元素为Map<String, dynamic>
  /// 
  /// Returns: 插入成功的文档数量
  /// 
  /// 使用示例：
  /// ```dart
  /// final docs = [
  ///   {'name': 'config1', 'type': 'weapon'},
  ///   {'name': 'config2', 'type': 'armor'}
  /// ];
  /// final count = await dbService.insertManyDocuments(docs);
  /// ```
  Future<int> insertManyDocuments(List<Map<String, dynamic>> documents) async {
    try {
      final result = await _collection.insertMany(documents);
      if (result.isSuccess) {
        final insertedCount = result.ids?.length ?? 0;
        print('成功批量插入 $insertedCount 个文档');
        return insertedCount;
      } else {
        print('批量插入失败');
        return 0;
      }
    } catch (e) {
      print('批量插入文档时发生错误: $e');
      return 0;
    }
  }

  // ==================== 数据库操作方法 ====================
  
  /// 获取当前集合中的所有文档
  /// 从当前选择的集合中查询所有文档数据，包含详细的连接状态检查
  /// 
  /// Returns: 包含所有文档的列表，每个文档是一个Map<String, dynamic>
  ///          如果查询失败或集合为空，返回空列表
  /// 
  /// 功能说明：
  /// - 检查数据库连接状态
  /// - 验证目标集合是否存在
  /// - 统计文档数量
  /// - 返回所有文档数据
  Future<List<Map<String, dynamic>>> getGameConfigs() async {
    try {
      // 检查数据库连接状态
      print('数据库连接状态: ${_db.isConnected}');
      print('数据库名称: ${_db.databaseName}');
      print('集合名称: $_currentCollectionName');

      // 获取数据库中的所有集合
      final collections = await _db.getCollectionNames();
      print('数据库中的集合: $collections');

      // 检查目标集合是否存在
      if (!collections.contains(_currentCollectionName)) {
        print('警告: 集合 $_currentCollectionName 不存在');
        return [];
      }

      // 获取集合中的文档数量
      final count = await _collection.count();
      print('集合 $_currentCollectionName 中的文档数量: $count');

      final documents = await _collection.find().toList();
      print('成功读取到 ${documents.length} 个配置文档');

      // 如果有文档，打印第一个文档的结构
      if (documents.isNotEmpty) {
        print('第一个文档的键: ${documents.first.keys.toList()}');
      }

      return documents;
    } catch (e) {
      print('读取集合失败: $e');
      return [];
    }
  }

  /// 根据查询条件获取文档
  /// 使用指定的查询条件从当前集合中查找匹配的文档
  /// 
  /// [query] 查询条件，格式为Map<String, dynamic>
  ///         例如：{'name': 'config1', 'type': 'game'}
  ///         注意：当前实现只支持单个字段的等值查询
  /// 
  /// Returns: 匹配查询条件的文档列表
  ///          如果没有找到匹配文档或查询失败，返回空列表
  /// 
  /// 使用示例：
  /// ```dart
  /// final configs = await dbService.getGameConfigsByQuery({'type': 'weapon'});
  /// ```
  Future<List<Map<String, dynamic>>> getGameConfigsByQuery(
    Map<String, dynamic> query,
  ) async {
    try {
      final documents = await _collection
          .find(where.eq(query.keys.first, query.values.first))
          .toList();
      print('根据查询条件找到 ${documents.length} 个文档');
      return documents;
    } catch (e) {
      print('查询gameconfig集合失败: $e');
      return [];
    }
  }

  /// 根据ObjectId查询单个文档
  /// 使用MongoDB的ObjectId精确查找指定文档
  /// 
  /// [id] 文档的ObjectId
  /// 
  /// Returns: 找到的文档数据，如果文档不存在或查询失败返回null
  /// 
  /// 使用示例：
  /// ```dart
  /// final objectId = ObjectId.fromHexString('507f1f77bcf86cd799439011');
  /// final config = await dbService.getGameConfigById(objectId);
  /// ```
  Future<Map<String, dynamic>?> getGameConfigById(ObjectId id) async {
    try {
      final document = await _collection.findOne(where.id(id));
      if (document != null) {
        print('成功找到ID为 $id 的文档');
      } else {
        print('未找到ID为 $id 的文档');
      }
      return document;
    } catch (e) {
      print('根据ID查询文档失败: $e');
      return null;
    }
  }

  /// 更新指定文档的数据
  /// 根据文档ID更新文档中的指定字段
  /// 
  /// [id] 要更新的文档ID（十六进制字符串格式）
  /// [updateData] 要更新的字段和值，格式为Map<String, dynamic>
  ///              例如：{'name': 'newName', 'level': 10}
  /// 
  /// Returns: 更新成功返回true，失败返回false
  /// 
  /// 功能说明：
  /// - 将字符串ID转换为ObjectId
  /// - 使用ModifierBuilder构建更新操作
  /// - 执行原子性更新操作
  /// - 验证更新结果
  /// 
  /// 使用示例：
  /// ```dart
  /// final success = await dbService.updateGameConfig(
  ///   '507f1f77bcf86cd799439011',
  ///   {'name': 'Updated Config', 'version': 2}
  /// );
  /// ```
  Future<bool> updateGameConfig(
    String id,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final objectId = ObjectId.fromHexString(id);
      final modifier = ModifierBuilder();
      updateData.forEach((key, value) {
        modifier.set(key, value);
      });

      final result = await _collection.updateOne(where.id(objectId), modifier);

      if (result.isSuccess && result.nModified > 0) {
        print('成功更新文档 $id');
        return true;
      } else {
        print('更新文档失败: 没有找到匹配的文档或没有修改');
        return false;
      }
    } catch (e) {
      print('更新文档失败: $e');
      return false;
    }
  }

  // ==================== 状态查询方法 ====================
  
  /// 检查数据库连接状态
  /// 快速检查当前数据库连接是否处于活跃状态
  /// 
  /// Returns: 如果数据库已连接返回true，否则返回false
  bool get isConnected => _db.isConnected;
  
  /// 获取数据库连接的详细状态信息
  /// 提供完整的连接状态诊断信息，用于调试和监控
  /// 
  /// Returns: 包含以下信息的Map：
  ///   - 'isConnected': 连接状态（bool）
  ///   - 'databaseName': 当前数据库名称（String或null）
  ///   - 'currentCollection': 当前操作的集合名称（String）
  ///   - 'connectionString': 当前使用的连接字符串（String）
  /// 
  /// 使用示例：
  /// ```dart
  /// final status = dbService.getConnectionStatus();
  /// print('连接状态: ${status['isConnected']}');
  /// print('数据库: ${status['databaseName']}');
  /// ```
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _db.isConnected,
      'databaseName': _db.isConnected ? _db.databaseName : null,
      'currentCollection': _currentCollectionName,
      'connectionString': _currentConnectionString,
    };
  }
}
