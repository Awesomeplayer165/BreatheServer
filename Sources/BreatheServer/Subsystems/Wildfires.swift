//
//  Wildfires.swift
//  BreatheServer
//
//  Created by Jacob Trentini on 7/6/23.
//

import Foundation
import GEOSwift
import Vapor
import BreatheShared

public class Wildfires: Subsystem {
    public static let shared = Wildfires()
    
    var wildfires: [Wildfire] = []
    
    override private init(state: SubsystemTaskState = .notStarted,
                          forceClean: Bool = false
    ) {
        super.init(state: state)
    }
    
    override public func createRoutes(_ app: Application) async throws {
        try await invokePeriodic()
        
        app.get("wildfires") { request in
            return self.wildfires
        }
    }
    
    private func loadWildfires() async throws {
        wildfires = try await WildfireAPI.shared.wildfireIncidents()
        state = .succeeded
    }
    
    @discardableResult
    public override func invokePeriodic() async throws -> SubsystemTaskState {
        print("Running \(String(describing: type(of: self))) periodic")
        try await loadWildfires()
        return .succeeded
    }
}

extension Wildfire: Content { }
