import Vapor

struct ModerationService {
    let app: Application

    struct OpenAIErrorResponse: Content {
        let error: OpenAIError

        struct OpenAIError: Content {
            let message: String
            let type: String?
            let code: String?
        }
    }

    struct OpenAIModerationRequest: Content {
        let input: String
        let model: String

        init(input: String, model: String = "omni-moderation-latest") {
            self.input = input
            self.model = model
        }
    }

    struct OpenAIModerationResponse: Content {
        let id: String
        let model: String
        let results: [ModerationResult]

        struct ModerationResult: Content {
            let flagged: Bool
            let categories: Categories
            let categoryScores: CategoryScores

            enum CodingKeys: String, CodingKey {
                case flagged
                case categories
                case categoryScores = "category_scores"
            }

            struct Categories: Content {
                let harassment: Bool
                let harassmentThreatening: Bool
                let hate: Bool
                let hateThreatening: Bool
                let illicit: Bool
                let illicitViolent: Bool
                let selfHarm: Bool
                let selfHarmIntent: Bool
                let selfHarmInstructions: Bool
                let sexual: Bool
                let sexualMinors: Bool
                let violence: Bool
                let violenceGraphic: Bool

                enum CodingKeys: String, CodingKey {
                    case harassment
                    case harassmentThreatening = "harassment/threatening"
                    case hate
                    case hateThreatening = "hate/threatening"
                    case illicit
                    case illicitViolent = "illicit/violent"
                    case selfHarm = "self-harm"
                    case selfHarmIntent = "self-harm/intent"
                    case selfHarmInstructions = "self-harm/instructions"
                    case sexual
                    case sexualMinors = "sexual/minors"
                    case violence
                    case violenceGraphic = "violence/graphic"
                }
            }

            struct CategoryScores: Content {
                let harassment: Double
                let harassmentThreatening: Double
                let hate: Double
                let hateThreatening: Double
                let illicit: Double
                let illicitViolent: Double
                let selfHarm: Double
                let selfHarmIntent: Double
                let selfHarmInstructions: Double
                let sexual: Double
                let sexualMinors: Double
                let violence: Double
                let violenceGraphic: Double

                enum CodingKeys: String, CodingKey {
                    case harassment
                    case harassmentThreatening = "harassment/threatening"
                    case hate
                    case hateThreatening = "hate/threatening"
                    case illicit
                    case illicitViolent = "illicit/violent"
                    case selfHarm = "self-harm"
                    case selfHarmIntent = "self-harm/intent"
                    case selfHarmInstructions = "self-harm/instructions"
                    case sexual
                    case sexualMinors = "sexual/minors"
                    case violence
                    case violenceGraphic = "violence/graphic"
                }
            }
        }
    }

    struct CustomModerationRequest: Content {
        let content: String
        let customPrompts: [String]
    }

    struct CustomModerationResponse: Content {
        let model: String
        let choices: [Choice]

        struct Choice: Content {
            let message: Message

            struct Message: Content {
                let role: String
                let content: String
            }
        }
    }

    func moderateComment(_ comment: Comment, customPrompts: [String] = []) async throws -> (approved: Bool, result: String) {
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            throw Abort(.internalServerError, reason: "OpenAI API key not configured")
        }

        // First, run OpenAI moderation
        let moderationRequest = OpenAIModerationRequest(input: comment.content)

        let moderationResponse = try await app.client.post(URI(string: "https://api.openai.com/v1/moderations"), headers: [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ], beforeSend: { req in
            try req.content.encode(moderationRequest)
        })

        guard moderationResponse.status == HTTPStatus.ok else {
            let bodyString = moderationResponse.body.map { String(buffer: $0) } ?? "No body"
            app.logger.error("OpenAI moderation API error: Status \(moderationResponse.status.code), Body: \(bodyString)")

            let errorBody = try? moderationResponse.content.decode(OpenAIErrorResponse.self)
            let errorMessage = errorBody?.error.message ?? "Status \(moderationResponse.status.code)"
            throw Abort(.internalServerError, reason: "OpenAI moderation API request failed: \(errorMessage)")
        }

        let moderation = try moderationResponse.content.decode(OpenAIModerationResponse.self)

        guard let firstResult = moderation.results.first else {
            throw Abort(.internalServerError, reason: "No moderation results returned")
        }

        // If flagged by OpenAI, reject
        if firstResult.flagged {
            let flaggedCategories = getFlaggedCategories(firstResult.categories)
            return (false, "Rejected by OpenAI moderation: \(flaggedCategories.joined(separator: ", "))")
        }

        // If custom prompts exist, run additional moderation
        if !customPrompts.isEmpty {
            let customResult = try await runCustomModeration(comment.content, prompts: customPrompts, apiKey: apiKey)
            if !customResult.approved {
                return (false, "Rejected by custom moderation: \(customResult.reason)")
            }
        }

        return (true, "Approved")
    }

    private func getFlaggedCategories(_ categories: OpenAIModerationResponse.ModerationResult.Categories) -> [String] {
        var flagged: [String] = []
        if categories.harassment { flagged.append("harassment") }
        if categories.harassmentThreatening { flagged.append("harassment/threatening") }
        if categories.hate { flagged.append("hate") }
        if categories.hateThreatening { flagged.append("hate/threatening") }
        if categories.illicit { flagged.append("illicit") }
        if categories.illicitViolent { flagged.append("illicit/violent") }
        if categories.selfHarm { flagged.append("self-harm") }
        if categories.selfHarmIntent { flagged.append("self-harm/intent") }
        if categories.selfHarmInstructions { flagged.append("self-harm/instructions") }
        if categories.sexual { flagged.append("sexual") }
        if categories.sexualMinors { flagged.append("sexual/minors") }
        if categories.violence { flagged.append("violence") }
        if categories.violenceGraphic { flagged.append("violence/graphic") }
        return flagged
    }

    private func runCustomModeration(_ content: String, prompts: [String], apiKey: String) async throws -> (approved: Bool, reason: String) {
        let systemPrompt = """
        You are a content moderator. Review the following comment based on these moderation guidelines:

        \(prompts.joined(separator: "\n"))

        Respond with either "APPROVED" or "REJECTED: [reason]"
        """

        struct ChatCompletionRequest: Content {
            let model: String
            let messages: [[String: String]]
            let temperature: Double
            let maxTokens: Int

            enum CodingKeys: String, CodingKey {
                case model, messages, temperature
                case maxTokens = "max_tokens"
            }
        }

        let chatRequest = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": content]
            ],
            temperature: 0.3,
            maxTokens: 100
        )

        let response = try await app.client.post(URI(string: "https://api.openai.com/v1/chat/completions"), headers: [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ], beforeSend: { req in
            try req.content.encode(chatRequest)
        })

        guard response.status == HTTPStatus.ok else {
            throw Abort(.internalServerError, reason: "Custom moderation API request failed")
        }

        let chatResponse = try response.content.decode(CustomModerationResponse.self)

        guard let message = chatResponse.choices.first?.message.content else {
            throw Abort(.internalServerError, reason: "No custom moderation response")
        }

        if message.uppercased().hasPrefix("APPROVED") {
            return (true, "")
        } else if message.uppercased().hasPrefix("REJECTED") {
            let reason = message.replacingOccurrences(of: "REJECTED:", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return (false, reason)
        } else {
            // If unclear, reject to be safe
            return (false, "Unclear moderation result")
        }
    }
}

extension Application {
    var moderation: ModerationService {
        .init(app: self)
    }
}

extension Request {
    var moderation: ModerationService {
        .init(app: application)
    }
}
