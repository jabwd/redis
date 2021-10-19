import Foundation
import Redis
import Vapor
import Logging
import XCTVapor
import NIOSSL

private extension RedisID {
    static let one: RedisID = "one"
    static let two: RedisID = "two"
}

class MultipleRedisTests: XCTestCase {

    var redisConfig: RedisConfiguration!
    var redisConfig2: RedisConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let tlsConfiguration = TLSConfiguration.makeClientConfiguration()

        redisConfig = try RedisConfiguration(
            hostname: Environment.get("REDIS_HOSTNAME") ?? "localhost",
            port: Environment.get("REDIS_PORT")?.int ?? 6379)
        redisConfig2 = try RedisConfiguration(
            hostname: Environment.get("REDIS_HOSTNAME_2") ?? "streamsplitter.exurion.internal",
            port: Environment.get("REDIS_PORT_2")?.int ?? 6380,
            tlsConfiguration: tlsConfiguration)
    }

    func testApplicationRedis() throws {
        let app = Application()
        defer { app.shutdown() }

        app.redis(.one).configuration = redisConfig
        app.redis(.two).configuration = redisConfig2

        try app.boot()
        let info1 = try app.redis(.one).send(.info()).wait()
        XCTAssertContains(info1, "redis_version")

        let info2 = try app.redis(.two).send(.info()).wait()
        XCTAssertContains(info2, "redis_version")
    }

    func testSetAndGet() throws {
        let app = Application()
        defer { app.shutdown() }

        app.redis(.one).configuration = redisConfig
        app.redis(.two).configuration = redisConfig2

        app.get("test1") { req in
            req.redis(.one).get("name").unwrap(or: Abort(.notFound, reason: "Key not found")).map {
                $0.description
            }
        }
        app.get("test2") { req in
            req.redis(.two).get("name2").unwrap(or: Abort(.notFound, reason: "Key not found")).map {
                $0.description
            }
        }

        try app.boot()

        try app.redis(.one).set("name", to: "redis1").wait()
        try app.redis(.two).set("name2", to: "redis2").wait()

        try app.test(.GET, "test1") { res in
            XCTAssertEqual(res.body.string, "redis1")
        }

        try app.test(.GET, "test2") { res in
            XCTAssertEqual(res.body.string, "redis2")
        }

        XCTAssertEqual("redis1", try app.redis(.one).get("name").wait()?.string ?? "")
        XCTAssertEqual("redis2", try app.redis(.two).get("name2").wait()?.string ?? "")
    }
}
