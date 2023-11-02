//
//  GroupByCity.swift
//  BreatheServer
//
//  Created by Jacob Trentini on 7/6/23.
//

import Foundation
import GEOSwift
import Vapor
import BreatheShared

public class GroupByCity: Subsystem {
    public static let shared = GroupByCity()
    
    override private init(state: SubsystemTaskState = .notStarted,
                          forceClean: Bool = false
    ) {
        super.init(state: state)
        
        if forceClean {
            try? deleteExistingData()
        }
        
        try? loadInitialData()
    }
    
    var sensorsByPlace:             [String: Set<Int>]            = [:]
    var boundariesByPlace:          [String: Geometry]            = [:]
    var reverseGeoCodedDataByPlace: [String: ReverseGeoCodedData] = [:]
    var sensors:                    Set<Sensor>                   = []
    
    var totalSensorCount = 0
    
    override public func createRoutes(_ app: Application) async throws {
        try await invokePeriodic()
        
        app.get("autocomplete", ":city") { request in
            guard let city = request.parameters.get("city") else {
                throw Abort(.badRequest, reason: "City Parameter Missing: \(request.url.path)")
            }
            
            guard city.count >= 3 else {
                throw Abort(.badRequest, reason: "City parameter needs to be at least 3 characters long")
            }
            
            let nameContainsCity: (ReverseGeoCodedData) -> Bool = { data in
                data.name.lowercased().contains(city.lowercased())
            }
            
            var cities: [City] = []
            
            let places = self.reverseGeoCodedDataByPlace.values.filter(nameContainsCity)
            
            var iterations = 0
            
            for place in places {
                if
                    iterations < 5,
                    let boundary = self.boundariesByPlace[place.placeId],
                    let cityInfo = self.calculateCityInfo(on: boundary, reverseGeoCodedData: place)
                {
                    cities.append(cityInfo)
                    iterations += 1
                }
            }
            
            guard !cities.isEmpty else {
                throw Abort(.notFound)
            }
            
            return self.removeDuplicateValues(on: cities).encodeResponse(for: request)
        }
        
        app.get("cities", ":topLeftx", ":topLefty", ":bottomRightx", ":bottomRighty", ":excludedCities") { request in
            let (topLeft, bottomRight) = try {
                guard
                    let topLeftx      = request.parameters.get("topLeftx",      as: Double.self),
                    let topLefty      = request.parameters.get("topLefty",      as: Double.self),
                    let bottomRightx  = request.parameters.get("bottomRightx",  as: Double.self),
                    let bottomRighty  = request.parameters.get("bottomRighty",  as: Double.self)
                else { throw Abort(.badRequest, reason: "topLeft or bottomRight points missing or malformed") }
                
                return (Point(x: topLefty,     y: topLeftx),
                        Point(x: bottomRighty, y: bottomRightx))
                // x and y values reversed. look into sortData() for more information.
            }()
            
            // create Polygon with topLeft and bottomRight
            // for loop through boundariesByPlace values and check if it intersects parent boundary
            // calculate city info for those intersecting
            
            let linearRing = try Polygon.LinearRing(points: [
                topLeft,
                Point(x: bottomRight.x, y: topLeft.y),
                bottomRight,
                Point(x: topLeft.x, y: bottomRight.y),
                topLeft
            ])
            
            let polygon = Polygon(exterior: linearRing)
            
            var intesectingBoundaries: [(String, Geometry)] = []
            
            let excludedCitiesString: String? = request.parameters.get("excludedCities", as: String.self)
            let data = Data(excludedCitiesString!.utf8)
            let excludedCities: [String]? = try? JSONDecoder().decode([String].self, from: data)
            
            for (placeId, boundary) in self.boundariesByPlace {
                if (try? polygon.contains(boundary)) ?? false {
                    if let excludedCities, !excludedCities.contains(placeId) {
                        intesectingBoundaries.append((placeId, boundary))
                    }
                }
            }
            
            let cities = intesectingBoundaries.compactMap { self.calculateCityInfo(on: $0.1, placeId: $0.0) }
            
            guard !cities.isEmpty else {
                throw Abort(.notFound)
            }
            
            return self.removeDuplicateValues(on: cities).encodeResponse(for: request)
        }
    }
    
    private func removeDuplicateValues(on cities: [City]) -> [City ]{
        var newCities: Set<City> = []
        
        for city in cities {
            if !newCities.contains(where: { $0.reverseGeoCodedData.name == city.reverseGeoCodedData.name }) {
                newCities.insert(city)
            }
        }
        
        return newCities.map { City(airQuality:  $0.airQuality,
                                    temperature: $0.temperature,
                                    humidity:    $0.humidity,
                                    reverseGeoCodedData: ReverseGeoCodedData(placeId: $0.reverseGeoCodedData.placeId,
                                                                             coordinate: $0.reverseGeoCodedData.coordinate,
                                                                             name: $0.reverseGeoCodedData.name.trimmingCharacters(in: .decimalDigits)),
                                    linkedSensors: $0.linkedSensors) }
    }
    
    private func calculateCityInfo(on boundary: Geometry, reverseGeoCodedData: ReverseGeoCodedData) -> City? {
        guard let sensorIndices = sensorsByPlace[reverseGeoCodedData.placeId] else { return nil }
        
        let citySensors = sensorIndices.compactMap { sensorIndex in
            self.sensors.first { $0.id == sensorIndex }
        }
        
        guard citySensors.count > 3 else { return nil }
        
        let sortedSensors = citySensors.sorted { $0.airQuality.aqi < $1.airQuality.aqi }
        let sensor = sortedSensors[sortedSensors.count / 2]
        
        return City(airQuality:  sensor.airQuality,
                    temperature: sensor.temperature,
                    humidity:    sensor.humidity,
                    reverseGeoCodedData: reverseGeoCodedData,
                    linkedSensors: sortedSensors.map { $0.index })
    }
    
    private func calculateCityInfo(on boundary: Geometry, placeId: String) -> City? {
        if let place = reverseGeoCodedDataByPlace[placeId] {
            return calculateCityInfo(on: boundary, reverseGeoCodedData: place)
        } else {
            return nil
        }
    }
    
    @discardableResult
    override public func invokePeriodic() async throws -> SubsystemTaskState {
        print("Running \(String(describing: type(of: self))) periodic")
        sensors = try await PurpleAirAPI.shared.sensors()
        
        return .succeeded
    }
    
    private func sortData() async throws {
        totalSensorCount = sensors.count
        
        sensors = sensors.filter { sensor in
                sensor.locationType == .outdoor &&
                !sensorsByPlace.values.contains { $0.contains(sensor.index) }
            }
        
        var count = 0
        
        for sensor in sensors {
            print(count, sensor.index)
            
            if count % 10 == 0 {
                print("Reached \(count / 10)th Checkpoint @ \(count). Writing...")
                
                DispatchQueue.main.async {
                    try? self.writeToFile()
                    
                    self.logProgress()
                }
            }
            
            count += 1
            
            // need to flip sensor.coordinate from x -> y and y -> x since GeoAPIfy gives lon, lat and we have no way to easily changing the decoding process.
            if let (placeId, boundary) = isSensorInBoundary(at: Point(x: sensor.coordinate.longitude, y: sensor.coordinate.latitude)) {
                print("Sensor \(sensor.index) already in boundary @ \(sensor.coordinate.latitude) \(sensor.coordinate.longitude)")
                
                sensorsByPlace[placeId]?.insert(sensor.index)
                
                continue
            }
            
            print("Sensor \(sensor.index) not already in known boundaries")
            
            if
                let reverseGeoCodedData = try await GeoAPIfy.shared.reverseGeoCode(point: sensor.coordinate.toPoint()),
                let boundary = try await GeoAPIfy.shared.boundary(detailsOf: reverseGeoCodedData.placeId)
            {
                boundariesByPlace[reverseGeoCodedData.placeId] = boundary
                reverseGeoCodedDataByPlace[reverseGeoCodedData.placeId] = reverseGeoCodedData
                
                if let _ = sensorsByPlace[reverseGeoCodedData.placeId] {
                    sensorsByPlace[reverseGeoCodedData.placeId]!.insert(sensor.id)
                } else {
                    sensorsByPlace[reverseGeoCodedData.placeId] = Set([sensor.id])
                }
            } else {
                print("PlaceId or Boundary API nil")
            }
        }
    }
    
    private func logProgress() {
        let currentSensors = sensorsByPlace.values.flatMap { $0 }.count
        print("Progress: \(Double(currentSensors) / Double(totalSensorCount) * 100.0)%: \(currentSensors) / \(totalSensorCount)")
    }
    
    private func isSensorInBoundary(at point: Point) -> (String, Geometry)? {
        for (placeId, boundary) in boundariesByPlace {
            if (try? boundary.contains(point)) ?? false {
                return (placeId, boundary)
            }
        }
        
        return nil
    }
    
    private func loadInitialData() throws {
        boundariesByPlace           = (try? FileHelper.shared.readJson(from: .boundariesByPlace,          type: boundariesByPlace.self))          ?? [:]
        sensorsByPlace              = (try? FileHelper.shared.readJson(from: .sensorsByPlace,             type: sensorsByPlace.self))             ?? [:]
        reverseGeoCodedDataByPlace  = (try? FileHelper.shared.readJson(from: .reverseGeoCodedDataByPlace, type: reverseGeoCodedDataByPlace.self)) ?? [:]
    }
    
    private func deleteExistingData() throws {
        try FileHelper.shared.deleteAll()
    }
    
    private func writeToFile() throws {
        try FileHelper.shared.appendJson(to: .boundariesByPlace,
                                         type: boundariesByPlace.self,
                                         appendingOperation: { existingDecodedContent in
            if existingDecodedContent == nil {
                existingDecodedContent = boundariesByPlace
            } else {
                existingDecodedContent!.merge(boundariesByPlace, uniquingKeysWith: { $1 })
            }
        })
        
        try FileHelper.shared.appendJson(to: .sensorsByPlace,
                                         type: sensorsByPlace.self,
                                         appendingOperation: { existingDecodedContent in
            if existingDecodedContent == nil {
                existingDecodedContent = sensorsByPlace
            } else {
                existingDecodedContent!.merge(sensorsByPlace, uniquingKeysWith: { $1 })
            }
        })
        
        try FileHelper.shared.appendJson(to: .reverseGeoCodedDataByPlace,
                                         type: reverseGeoCodedDataByPlace.self,
                                         appendingOperation: { existingDecodedContent in
            if existingDecodedContent == nil {
                existingDecodedContent = reverseGeoCodedDataByPlace
            } else {
                existingDecodedContent!.merge(reverseGeoCodedDataByPlace, uniquingKeysWith: { $1 })
            }
        })
    }
}

extension Coordinate {
    func toPoint() -> Point {
        Point(x: latitude, y: longitude)
    }
}

extension City: Content { }
