@_exported import struct Foundation.URL
@_exported import struct Logging.Logger
@_exported import struct NIO.TimeAmount
import enum NIO.SocketAddress
import NIOSSL

/// Configuration for connecting to a Redis instance
public struct RedisConfiguration {
    public typealias ValidationError = RedisConnection.Configuration.ValidationError

    public var serverAddresses: [SocketAddress]
    public var password: String?
    public var database: Int?
    public var pool: PoolOptions
    public var tlsConfiguration: TLSConfiguration?

    public struct PoolOptions {
        public var maximumConnectionCount: RedisConnectionPoolSize
        public var minimumConnectionCount: Int
        public var connectionBackoffFactor: Float32
        public var initialConnectionBackoffDelay: TimeAmount
        public var connectionRetryTimeout: TimeAmount?

        public init(
            maximumConnectionCount: RedisConnectionPoolSize = .maximumActiveConnections(2),
            minimumConnectionCount: Int = 0,
            connectionBackoffFactor: Float32 = 2,
            initialConnectionBackoffDelay: TimeAmount = .milliseconds(100),
            connectionRetryTimeout: TimeAmount? = nil
        ) {
            self.maximumConnectionCount = maximumConnectionCount
            self.minimumConnectionCount = minimumConnectionCount
            self.connectionBackoffFactor = connectionBackoffFactor
            self.initialConnectionBackoffDelay = initialConnectionBackoffDelay
            self.connectionRetryTimeout = connectionRetryTimeout
        }
    }

    public init(url string: String, pool: PoolOptions = .init(), tlsConfiguration: TLSConfiguration? = nil) throws {
        guard let url = URL(string: string) else { throw ValidationError.invalidURLString }
        try self.init(url: url, pool: pool, tlsConfiguration: tlsConfiguration)
    }

    public init(url: URL, pool: PoolOptions = .init(), tlsConfiguration: TLSConfiguration? = nil) throws {
        guard
            let scheme = url.scheme,
            !scheme.isEmpty
        else { throw ValidationError.missingURLScheme }
        guard scheme == "redis" else { throw ValidationError.invalidURLScheme }
        guard let host = url.host, !host.isEmpty else { throw ValidationError.missingURLHost }

        try self.init(
            hostname: host,
            port: url.port ?? RedisConnection.Configuration.defaultPort,
            password: url.password,
            database: Int(url.lastPathComponent),
            pool: pool,
            tlsConfiguration: tlsConfiguration
        )
    }

    public init(
        hostname: String,
        port: Int = RedisConnection.Configuration.defaultPort,
        password: String? = nil,
        database: Int? = nil,
        pool: PoolOptions = .init(),
        tlsConfiguration: TLSConfiguration? = nil
    ) throws {
        if database != nil && database! < 0 { throw ValidationError.outOfBoundsDatabaseID }

        try self.init(
            serverAddresses: [.makeAddressResolvingHost(hostname, port: port)],
            password: password,
            database: database,
            pool: pool,
            tlsConfiguration: tlsConfiguration
        )
    }

    public init(
        serverAddresses: [SocketAddress],
        password: String? = nil,
        database: Int? = nil,
        useSSL: Bool = false,
        pool: PoolOptions = .init(),
        tlsConfiguration: TLSConfiguration? = nil
    ) throws {
        self.serverAddresses = serverAddresses
        self.password = password
        self.database = database
        self.pool = pool
        self.tlsConfiguration = tlsConfiguration
    }
}

extension RedisConnectionPool.Configuration {
    internal init(_ config: RedisConfiguration, defaultLogger: Logger) {
        self.init(
            initialServerConnectionAddresses: config.serverAddresses,
            maximumConnectionCount: config.pool.maximumConnectionCount,
            connectionFactoryConfiguration: .init(
                connectionInitialDatabase: config.database,
                connectionPassword: config.password,
                connectionDefaultLogger: defaultLogger,
                tlsConfiguration: config.tlsConfiguration,
                tcpClient: nil
            ),
            minimumConnectionCount: config.pool.minimumConnectionCount,
            connectionBackoffFactor: config.pool.connectionBackoffFactor,
            initialConnectionBackoffDelay: config.pool.initialConnectionBackoffDelay,
            connectionRetryTimeout: config.pool.connectionRetryTimeout,
            poolDefaultLogger: defaultLogger
        )
    }
}
