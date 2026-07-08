import BMUXMobileCore
import BmuxMobileRPC

struct SlowIgnoringCancellationTransportFactory: CmxByteTransportFactory {
    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        SlowIgnoringCancellationTransport()
    }
}
