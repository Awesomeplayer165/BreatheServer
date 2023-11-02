//
//  AirNow.swift
//  BreatheServer
//
//  Created by Jacob Trentini on 7/6/23.
//

import Foundation
import GEOSwift
import Vapor
import BreatheShared

public class AirNow: Subsystem {
    public static let shared = AirNow()
    
    var dataStations: [AirNowStation] = []
    
    override private init(state: SubsystemTaskState = .notStarted,
                          forceClean: Bool = false
    ) {
        super.init(state: state)
    }
    
    override public func createRoutes(_ app: Application) async throws {
        try await invokePeriodic()
        
        app.get("airNowStations") { request in
            return self.dataStations
        }
    }
    
    @discardableResult
    public override func invokePeriodic() async throws -> SubsystemTaskState {
        print("Running \(String(describing: type(of: self))) periodic")
        try await loadDataStations()
        return .succeeded
    }
    
    private func loadDataStations() async throws {
        dataStations = try await AirNowAPI.shared.dataStations()
        state = .succeeded
    }
}

extension AirNowStation: Content { }
