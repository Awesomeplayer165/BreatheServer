import Vapor
import Jobs

// configures your application
public func configure(_ app: Application) async throws {
    try await GroupByCity.shared.createRoutes(app)
    try await Wildfires.shared.createRoutes(app)
    try await AirNow.shared.createRoutes(app)
    
    Jobs.add(name: String(describing: GroupByCity.self),
             interval: .seconds(600)) {
        GroupByCity.shared.invokePeriodic()
    }
    
    Jobs.add(name: String(describing: Wildfires.self),
             interval: .seconds(600)) {
        Wildfires.shared.invokePeriodic()
    }
    
    Jobs.add(name: String(describing: AirNow.self),
             interval: .seconds(600)) {
        AirNow.shared.invokePeriodic()
    }
}
