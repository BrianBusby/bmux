import BMUXMobileCore
@testable import BmuxMobileRPC

struct ResponseTimeoutSurvivalTransportFactory: CmxByteTransportFactory {
    let transport: ResponseTimeoutSurvivalTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}
