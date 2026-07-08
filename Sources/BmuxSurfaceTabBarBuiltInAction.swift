import Bonsplit
import Foundation

enum BmuxSurfaceTabBarBuiltInAction: String, Codable, Sendable, CaseIterable, Hashable {
    case newWorkspace = "bmux.newWorkspace"
    case newAgentChat = "bmux.newAgentChat"
    case cloudVM = "bmux.cloudvm"
    case mobileConnect = "bmux.mobileconnect"
    case newTerminal = "bmux.newTerminal"
    case newBrowser = "bmux.newBrowser"
    case splitRight = "bmux.splitRight"
    case splitDown = "bmux.splitDown"

    init?(configID: String) {
        switch configID {
        case "bmux.newWorkspace", "newWorkspace":
            self = .newWorkspace
        case "bmux.newAgentChat", "bmux.agentChat", "newAgentChat", "new-agent-chat", "agentChat":
            self = .newAgentChat
        case "bmux.cloudvm", "bmux.cloudVM", "cloudVM", "cloudvm",
             "bmux.newCloudVM", "bmux.newCloudVm", "newCloudVM", "newCloudVm",
             "bmux.startCloudVM", "bmux.startCloudVm", "startCloudVM", "startCloudVm":
            self = .cloudVM
        case "bmux.mobileconnect", "bmux.mobileConnect", "mobileConnect", "mobileconnect",
             "bmux.connectPhone", "connectPhone":
            self = .mobileConnect
        case "bmux.newTerminal", "newTerminal":
            self = .newTerminal
        case "bmux.newBrowser", "newBrowser":
            self = .newBrowser
        case "bmux.splitRight", "splitRight":
            self = .splitRight
        case "bmux.splitDown", "splitDown":
            self = .splitDown
        default:
            return nil
        }
    }

    var configID: String {
        rawValue
    }

    var defaultIcon: String {
        switch self {
        case .newWorkspace:
            return "plus.square"
        case .newAgentChat:
            return "message"
        case .cloudVM:
            return "cloud"
        case .mobileConnect:
            return "iphone"
        case .newTerminal:
            return "terminal"
        case .newBrowser:
            return "globe"
        case .splitRight:
            return "square.split.2x1"
        case .splitDown:
            return "square.split.1x2"
        }
    }

    var bonsplitAction: BonsplitConfiguration.SplitActionButton.Action? {
        switch self {
        case .newWorkspace, .newAgentChat, .cloudVM, .mobileConnect:
            return nil
        case .newTerminal:
            return .newTerminal
        case .newBrowser:
            return .newBrowser
        case .splitRight:
            return .splitRight
        case .splitDown:
            return .splitDown
        }
    }
}
