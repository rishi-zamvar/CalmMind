import Foundation

/// A crisis support resource (hotline, text line, website)
struct CrisisResource: Codable, Sendable, Equatable {
    /// Name of the resource
    let name: String

    /// Description of the service
    let description: String

    /// Phone number to call (optional)
    let phoneNumber: String?

    /// Number to text (optional)
    let textNumber: String?

    /// Text keyword to send (optional)
    let textKeyword: String?

    /// Website URL (optional)
    let websiteURL: String?

    /// Whether this is available 24/7
    let is24Hours: Bool

    /// Primary language (for localization)
    let language: String
}

/// Provider of crisis resources
/// CRITICAL: These resources must be accurate and up-to-date
enum CrisisResources {

    /// Get all crisis resources for the US
    static var allResources: [CrisisResource] {
        return [
            // 988 Suicide & Crisis Lifeline (primary)
            CrisisResource(
                name: "988 Suicide & Crisis Lifeline",
                description: "Free, confidential support for people in distress. Call or text 988.",
                phoneNumber: "988",
                textNumber: "988",
                textKeyword: nil,
                websiteURL: "https://988lifeline.org",
                is24Hours: true,
                language: "en"
            ),

            // Crisis Text Line
            CrisisResource(
                name: "Crisis Text Line",
                description: "Free crisis counseling via text message. Text HOME to 741741.",
                phoneNumber: nil,
                textNumber: "741741",
                textKeyword: "HOME",
                websiteURL: "https://www.crisistextline.org",
                is24Hours: true,
                language: "en"
            ),

            // National Alliance on Mental Illness (NAMI)
            CrisisResource(
                name: "NAMI Helpline",
                description: "Mental health information, resources, and support.",
                phoneNumber: "1-800-950-NAMI",
                textNumber: nil,
                textKeyword: nil,
                websiteURL: "https://www.nami.org/help",
                is24Hours: false,
                language: "en"
            ),

            // SAMHSA
            CrisisResource(
                name: "SAMHSA National Helpline",
                description: "Free, confidential treatment referrals and information.",
                phoneNumber: "1-800-662-4357",
                textNumber: nil,
                textKeyword: nil,
                websiteURL: "https://www.samhsa.gov/find-help/national-helpline",
                is24Hours: true,
                language: "en"
            ),

            // Veterans Crisis Line
            CrisisResource(
                name: "Veterans Crisis Line",
                description: "Support for veterans and their families. Call 988, then Press 1.",
                phoneNumber: "988",
                textNumber: "838255",
                textKeyword: nil,
                websiteURL: "https://www.veteranscrisisline.net",
                is24Hours: true,
                language: "en"
            ),

            // Trevor Project (LGBTQ+)
            CrisisResource(
                name: "The Trevor Project",
                description: "Crisis support for LGBTQ+ young people.",
                phoneNumber: "1-866-488-7386",
                textNumber: "678-678",
                textKeyword: "START",
                websiteURL: "https://www.thetrevorproject.org",
                is24Hours: true,
                language: "en"
            ),
        ]
    }

    /// Get primary crisis resources (most critical)
    static var primaryResources: [CrisisResource] {
        return allResources.filter { resource in
            resource.phoneNumber == "988" ||
            resource.name.contains("988") ||
            resource.name.contains("Crisis Text Line")
        }
    }

    /// Get resources that support text-based communication
    static var textResources: [CrisisResource] {
        return allResources.filter { $0.textNumber != nil }
    }

    /// Get 24/7 resources
    static var available24Hours: [CrisisResource] {
        return allResources.filter { $0.is24Hours }
    }
}
