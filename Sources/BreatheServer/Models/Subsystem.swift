//
//  Subsystem.swift
//  BreatheServer
//
//  Created by Jacob Trentini on 7/6/23.
//

import Foundation
import Vapor

public class Subsystem {
    public var state: SubsystemTaskState
    
    public func createRoutes(_ app: Application) async throws { }
    
    @discardableResult
    public func invokePeriodic() async throws -> SubsystemTaskState {
        print("Running \(String(describing: type(of: self))) periodic")
        return .failed(message: "Not overriden")
    }
    
    public func invokePeriodic(completionHandler: ((SubsystemTaskState) -> Void)? = nil) {
        Task {
            completionHandler?(try await invokePeriodic())
        }
    }
    
    init(state: SubsystemTaskState = .notStarted,
         forceClean: Bool = false
    ) {
        self.state = state
    }
}

extension Subsystem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: type(of: self)))
    }
}

extension Subsystem: Equatable {
    public static func == (lhs: Subsystem, rhs: Subsystem) -> Bool {
        String(describing: type(of: lhs)) == String(describing: type(of: rhs))
    }
}


public enum SubsystemTaskState {
    case notStarted
    case failed(message: String)
    case succeeded
}
