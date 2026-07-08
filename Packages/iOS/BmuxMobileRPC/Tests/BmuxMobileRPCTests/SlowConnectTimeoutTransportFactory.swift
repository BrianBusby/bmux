import BMUXMobileCore
@testable import BmuxMobileRPC

struct SlowConnectTimeoutTransportFactory: CmxByteTransportFactory {
    let transport: SlowConnectTimeoutTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}
