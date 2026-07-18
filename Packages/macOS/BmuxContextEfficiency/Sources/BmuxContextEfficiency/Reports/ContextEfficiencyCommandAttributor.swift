import Foundation

struct ContextEfficiencyCommandAttributor: Sendable {
    private let classifier: ContextEfficiencyCommandClassifier

    init(classifier: ContextEfficiencyCommandClassifier = ContextEfficiencyCommandClassifier()) {
        self.classifier = classifier
    }

    func commandExecutions(
        toolCalls: [ContextEfficiencyToolCallRecord],
        toolOutputs: [ContextEfficiencyToolOutputRecord],
        modelCalls: [ContextEfficiencyModelCallRecord]
    ) -> [ContextEfficiencyCommandExecutionRecord] {
        var matchedOutputIDs = Set<String>()
        return toolCalls.map { toolCall in
            let outputMatch = matchedOutput(
                for: toolCall,
                toolOutputs: toolOutputs,
                matchedOutputIDs: matchedOutputIDs
            )
            if let output = outputMatch.output {
                matchedOutputIDs.insert(output.id)
            }
            let modelCallAttribution = attributedModelCall(
                after: outputMatch.output?.sourceReference ?? toolCall.sourceReference,
                timestamp: outputMatch.output?.timestamp ?? toolCall.timestamp,
                modelCalls: modelCalls
            )
            return commandExecution(
                toolCall: toolCall,
                outputMatch: outputMatch,
                modelCallAttribution: modelCallAttribution
            )
        }
    }

    private func commandExecution(
        toolCall: ContextEfficiencyToolCallRecord,
        outputMatch: (output: ContextEfficiencyToolOutputRecord?, confidence: ContextEfficiencyAttributionConfidence),
        modelCallAttribution: ContextEfficiencyModelCallAttribution?
    ) -> ContextEfficiencyCommandExecutionRecord {
        let output = outputMatch.output
        return ContextEfficiencyCommandExecutionRecord(
            id: "command-execution:\(toolCall.id)",
            threadID: toolCall.threadID,
            callID: toolCall.callID,
            toolName: toolCall.toolName,
            commandSummary: toolCall.commandSummary,
            normalizedExecutable: classifier.normalizedExecutable(from: toolCall.commandSummary),
            category: classifier.category(for: toolCall.commandSummary),
            argumentsByteCount: toolCall.argumentsByteCount,
            outputByteCount: output?.outputByteCount,
            estimatedOriginalOutputTokens: output?.estimatedOriginalTokens,
            rawOutputReferenceCount: output?.rawOutputReferenceCount ?? 0,
            startedAt: toolCall.timestamp,
            completedAt: output?.timestamp,
            elapsedSeconds: elapsedSeconds(startedAt: toolCall.timestamp, completedAt: output?.timestamp),
            toolCallSourceReference: toolCall.sourceReference,
            toolOutputSourceReference: output?.sourceReference,
            outputAttributionConfidence: outputMatch.confidence,
            attributedModelCall: modelCallAttribution
        )
    }

    private func matchedOutput(
        for toolCall: ContextEfficiencyToolCallRecord,
        toolOutputs: [ContextEfficiencyToolOutputRecord],
        matchedOutputIDs: Set<String>
    ) -> (output: ContextEfficiencyToolOutputRecord?, confidence: ContextEfficiencyAttributionConfidence) {
        if let callID = toolCall.callID,
           let exactOutput = toolOutputs.first(where: { $0.callID == callID }) {
            return (exactOutput, .exactToolCallLink)
        }
        if let temporalOutput = toolOutputs.first(where: { output in
            !matchedOutputIDs.contains(output.id)
                && isAfter(
                    output.sourceReference,
                    timestamp: output.timestamp,
                    anchor: toolCall.sourceReference,
                    anchorTimestamp: toolCall.timestamp
                )
        }) {
            return (temporalOutput, .temporalCandidate)
        }
        return (nil, .unmatched)
    }

    private func attributedModelCall(
        after sourceReference: ContextEfficiencySourceReference,
        timestamp: Date?,
        modelCalls: [ContextEfficiencyModelCallRecord]
    ) -> ContextEfficiencyModelCallAttribution? {
        guard let modelCall = modelCalls.first(where: { modelCall in
            isAfter(
                modelCall.sourceReference,
                timestamp: modelCall.timestamp,
                anchor: sourceReference,
                anchorTimestamp: timestamp
            )
        }) else {
            return nil
        }
        return ContextEfficiencyModelCallAttribution(
            modelCallID: modelCall.id,
            confidence: .temporalCandidate,
            modelCallSourceReference: modelCall.sourceReference
        )
    }

    private func isAfter(
        _ sourceReference: ContextEfficiencySourceReference,
        timestamp: Date?,
        anchor: ContextEfficiencySourceReference,
        anchorTimestamp: Date?
    ) -> Bool {
        if let timestamp, let anchorTimestamp, timestamp > anchorTimestamp {
            return true
        }
        guard sourceReference.sourcePath == anchor.sourcePath else {
            return false
        }
        if sourceReference.lineNumber != anchor.lineNumber {
            return sourceReference.lineNumber > anchor.lineNumber
        }
        return sourceReference.byteOffset > anchor.byteOffset
    }

    private func elapsedSeconds(startedAt: Date?, completedAt: Date?) -> Double? {
        guard let startedAt, let completedAt, completedAt >= startedAt else {
            return nil
        }
        return completedAt.timeIntervalSince(startedAt)
    }
}
