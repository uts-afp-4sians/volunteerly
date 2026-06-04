import XCTest
@testable import volunteerly

final class HTTPClientTests: XCTestCase {
    
    private var mockClient: MockHTTPClient!
    
    override func setUp() {
        super.setUp()
        mockClient = MockHTTPClient.shared
        // Register standard mock data handlers
        MockData.registerAll(in: mockClient)
    }
    
    override func tearDown() {
        mockClient.handlers.removeAll()
        mockClient = nil
        super.tearDown()
    }
    
    /// Interface Test: Verifies that the client can fetch and successfully decode
    /// the programs list, and that date formatting matches exactly (.iso8601).
    func testFetchProgramsDecodingInterface() async throws {
        // Given
        let path = "/programs"
        
        // When
        do {
            let programs: [Program] = try await mockClient.get(path)
            
            // Then
            XCTAssertFalse(programs.isEmpty, "Programs list should not be empty")
            XCTAssertEqual(programs.count, MockData.programs.count)
            
            // Verify date interface (ensuring no parsing errors)
            let firstProgram = programs[0]
            XCTAssertEqual(firstProgram.name, "Centennial Park Tree Planting")
            XCTAssertNotNil(firstProgram.startDatetime, "Dates should be successfully parsed")
        } catch {
            XCTFail("Interface decoding failed: \(error.localizedDescription)")
        }
    }
    
    /// Interface Test: Verifies that the HTTPClient throws a serverError(404)
    /// when requesting an unregistered route interface.
    func testUnregisteredRouteThrowsNotFoundError() async {
        // Given
        let invalidPath = "/non-existent-endpoint"
        
        // When/Then
        do {
            let _: [Program] = try await mockClient.get(invalidPath)
            XCTFail("Should have thrown a 404 error for unregistered path")
        } catch let error as APIError {
            if case .serverError(let code) = error {
                XCTAssertEqual(code, 404, "Unregistered path should throw 404 error")
            } else {
                XCTFail("Expected APIError.serverError, but got: \(error)")
            }
        } catch {
            XCTFail("Expected APIError, but got: \(error)")
        }
    }
}
