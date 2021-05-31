import Vapor
import Fluent
import FluentSQLiteDriver

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    //app.databases.use(.sqlite(.memory), as: .sqlite)
    
    app.migrations.add(CreatePlayer())
    app.migrations.add(CreateRoom())
    app.migrations.add(CreateConnection())
    try app.autoMigrate().wait()
    
    // register routes
    try routes(app)
}
