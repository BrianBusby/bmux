import BMUXMobileCore
@testable import BmuxMobileRPC

struct ReleasableConnectTransportFactory: CmxByteTransportFactory {
    let transport: ReleasableConnectTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}
