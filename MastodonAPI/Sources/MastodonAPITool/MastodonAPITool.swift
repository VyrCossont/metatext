// Copyright © 2023 Vyr Cossont. All rights reserved.

import ArgumentParser
import CombineInterop
import Foundation
import Mastodon
import MastodonAPI

/// Command-line API client and benchmarking utility for Feditext HTML parsers.
@main
struct MastodonAPITool: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Benchmarking tool for Feditext components.",
        subcommands: [Fetch.self, Bench.self, Summarize.self]
    )

    struct TimelineFileOptions: ParsableArguments {
        @Argument(
            help: "The recorded timeline data file to load or save.",
            completion: .file(),
            transform: URL.init(fileURLWithPath:)
        )
        var dataFile: URL
    }

    /// Return an unauthenticated client with API capabilities detected.
    static func unauthenticatedClient(_ instanceURL: URL) async throws -> MastodonAPIClient {
        let nodeInfo = try await NodeInfoClient(
            session: .shared,
            instanceURL: instanceURL,
            allowUnencryptedHTTP: true
        )
            .nodeInfo()

        var apiCapabilities = APICapabilities(nodeInfo: nodeInfo)

        let bootstrapClient = try MastodonAPIClient(
            session: .shared,
            instanceURL: instanceURL,
            apiCapabilities: apiCapabilities,
            accessToken: nil,
            allowUnencryptedHTTP: true
        )

        let instance = try await bootstrapClient
            .request(InstanceEndpoint.instance)
            .singleValue

        apiCapabilities.setDetectedFeatures(instance)

        return try MastodonAPIClient(
            session: .shared,
            instanceURL: instanceURL,
            apiCapabilities: apiCapabilities,
            accessToken: nil,
            rateLimiter: MastodonRateLimiter(),
            allowUnencryptedHTTP: true
        )
    }

    struct Fetch: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Fetch some posts from a public federated timeline."
        )

        @OptionGroup var options: TimelineFileOptions

        @Option(help: "Approximate number of timeline posts to fetch.")
        var count: Int = 1000

        @Option(
            help: "Instance to fetch from.",
            transform: { raw in
                if let url = URL(string: raw) {
                    return url
                }
                throw ValidationError("Couldn't parse URL")
            }
        )
        var instanceURL: URL = URL(string: "https://mastodon.social/")!

        mutating func run() async throws {
            let client = try await MastodonAPITool.unauthenticatedClient(instanceURL)

            var htmlFragments = [String]()
            var maxId: String?
            while htmlFragments.count < count {
                let page = try await client.pagedRequest(
                    StatusesEndpoint.timelinesPublic(local: false),
                    maxId: maxId
                )
                maxId = page.info.maxId
                htmlFragments.append(contentsOf: page.result.compactMap { status in
                    let htmlFragment = status.content.raw
                    return if htmlFragment.isEmpty { nil } else { htmlFragment }
                })
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(htmlFragments).write(to: options.dataFile)
        }
    }

    struct Bench: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Benchmark HTML parsing given a set of posts."
        )

        @OptionGroup var options: TimelineFileOptions

        mutating func run() async throws {
            let htmlFragments = try JSONDecoder().decode([String].self, from: Data(contentsOf: options.dataFile))

            print("total input HTML fragments: \(htmlFragments.count)")
            print()

            // If we print some function of the actual output, the parsing can't get optimized out.
            var outputCharCount = 0
            var emptyOutputStrings = 0
            var worstParseTime: TimeInterval = 0

            let startTime = ProcessInfo.processInfo.systemUptime
            for htmlFragment in htmlFragments {
                let fragmentStartTime = ProcessInfo.processInfo.systemUptime
                let parsed = HTML(raw: htmlFragment).attrStr
                let fragmentEndTime = ProcessInfo.processInfo.systemUptime

                outputCharCount += parsed.characters.count
                if parsed.characters.isEmpty {
                    emptyOutputStrings += 1
                }
                let fragmentElapsedTime = fragmentEndTime - fragmentStartTime
                worstParseTime = max(worstParseTime, fragmentElapsedTime)
            }
            let endTime = ProcessInfo.processInfo.systemUptime

            let elapsedTime = endTime - startTime

            print("elapsed time (s): \(String(format: "%.1f", elapsedTime))")
            print("average time per input string (ms): \(String(format: "%.0f", 1000 * elapsedTime / Double(htmlFragments.count)))")
            print("worst time for any input string (ms): \(String(format: "%.0f", 1000 * worstParseTime))")
            print("total output chars: \(outputCharCount)")
            print("total empty output strings: \(emptyOutputStrings)")
            print()
        }
    }

    struct Summarize: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Summarize an account's posting habits."
        )

        @OptionGroup var options: TimelineFileOptions

        @Option(help: "username@domain to fetch.")
        var user: String = "gargron@mastodon.social"

        @Option(help: "Approximate number of days of posts to fetch.")
        var days: Int = 30

        @Option(
            help: "Instance to fetch from.",
            transform: { raw in
                if let url = URL(string: raw) {
                    return url
                }
                throw ValidationError("Couldn't parse URL")
            }
        )
        var instanceURL: URL = URL(string: "https://mastodon.social/")!

        enum SummarizeError: Error {
            case malformedUsername
        }

        mutating func run() async throws {
            var statuses: [Status]
            do {
                statuses = try JSONDecoder().decode([Status].self, from: Data(contentsOf: options.dataFile))
            } catch {
                print("\(options.dataFile) doesn't exist, fetching posts")
                statuses = try await fetchPosts()
            }

            guard let localInstance = user.split(separator: "@").dropFirst().first.map(String.init) else {
                throw SummarizeError.malformedUsername
            }
            summarize(statuses, localInstance: localInstance)
        }

        func fetchPosts() async throws -> [Status] {
            let client = try await MastodonAPITool.unauthenticatedClient(instanceURL)

            let account = try await client.request(AccountEndpoint.lookup(acct: user))

            var statuses = [Status]()
            var maxId: String?
            repeat {
                let page = try await client.pagedRequest(
                    StatusesEndpoint.accountsStatuses(
                        id: account.id,
                        excludeReplies: false,
                        excludeReblogs: false,
                        onlyMedia: false,
                        pinned: false
                    ),
                    maxId: maxId
                )
                maxId = page.info.maxId

                for status in page.result {
                    if status.createdAt.timeIntervalSinceNow < -86400 * TimeInterval(days) {
                        // Reached the end of the time period we're interested in. Don't fetch more pages.
                        maxId = nil
                    }
                    statuses.append(status)
                }
            } while maxId != nil

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(statuses).write(to: options.dataFile)

            return statuses
        }

        func summarize(_ statuses: [Status], localInstance: String) {
            var accountSummary = AccountSummary()
            var statusLookup = [Status.Id: Status]()
            for status in statuses {
                accountSummary.add(status, localInstance: localInstance)
                statusLookup[status.id] = status
            }
            let stats = accountSummary.total()

            print("Total posts, replies, and boosts: \(stats.total)")
            if stats.total > 0 {
                let pctPosts = Int(100 * Double(stats.posts) / Double(stats.total))
                print("Posts: \(stats.posts) (\(pctPosts)%)")

                let pctReplies = Int(100 * Double(stats.replies) / Double(stats.total))
                print("Replies: \(stats.replies) (\(pctReplies)%)")

                let pctBoosts = Int(100 * Double(stats.boosts) / Double(stats.total))
                print("Boosts: \(stats.boosts) (\(pctBoosts)%)")

                let pctOwn = Int(100 * Double(stats.own) / Double(stats.total))
                print("Own posts (posts and replies): \(stats.own) (\(pctOwn)%)")
            }
            print()

            if stats.own > 0 {
                let charsPerPost = Int(Double(stats.chars) / Double(stats.own))
                print("Average own post length: \(charsPerPost)")

                let pctMedia = Int(100 * Double(stats.withMedia) / Double(stats.own))
                print("Own posts with media: \(stats.withMedia) (\(pctMedia)%)")

                let pctCWed = Int(100 * Double(stats.cws) / Double(stats.own))
                print("Own posts with a content warning: \(stats.cws) (\(pctCWed)%)")

                let pctSensitive = Int(100 * Double(stats.sensitive) / Double(stats.own))
                print("Own posts marked NSFW: \(stats.sensitive) (\(pctSensitive)%)")
            }
            print()

            print("Own media attachments: \(stats.media)")
            if stats.media > 0 {
                let pctAltText = Int(100 * Double(stats.altText) / Double(stats.media))
                print("Own media attachments described: \(stats.altText) (\(pctAltText)%)")
            }
            print()

            func getTop<K, V>(_ dict: [K: V], n: Int) -> some Sequence<(K, V)> where V: Comparable {
                return dict.map { $0 }.sorted(by: { lhs, rhs in lhs.1 > rhs.1 }).prefix(n)
            }

            if !stats.instances.isEmpty {
                let top = Array(getTop(stats.instances, n: 10))
                print("Top \(top.count) most mentioned/boosted instances:")
                for (instance, count) in top {
                    print("\t\(count)\t\(instance)")
                }
                print()
            }

            if !stats.accounts.isEmpty {
                let top = Array(getTop(stats.accounts, n: 10))
                print("Top \(top.count) most mentioned/boosted users:")
                for (account, count) in top {
                    print("\t\(count)\t\(account)")
                }
                print()
            }

            if !stats.hashtags.isEmpty {
                let top = Array(getTop(stats.hashtags, n: 10))
                print("Top \(top.count) most used hashtags:")
                for (hashtag, count) in top {
                    print("\t\(count)\t\(hashtag)")
                }
                print()
            }

            if !stats.statuses.isEmpty {
                let top = Array(getTop(stats.statuses, n: 10))
                print("Top \(top.count) most popular posts:")
                for (id, count) in top {
                    let status = statusLookup[id]!
                    print("\t\(count)\t\(status.url!)")
                }
                print()
            }
        }
    }
}

struct AccountSummary {
    var byDay = [Date: SpanStats]()

    mutating func add(_ status: Status, localInstance: String) {
        let day = Date(
            timeIntervalSince1970: status.createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)
        )
        var dayStats = byDay[day] ?? .init()
        dayStats.add(status, localInstance: localInstance)
        byDay[day] = dayStats
    }

    func total() -> SpanStats {
        var acc = SpanStats()
        for dayStats in byDay.values {
            acc.add(dayStats)
        }
        return acc
    }

    /// Stats for a given span of time.
    struct SpanStats {
        var posts: Int = 0
        var replies: Int = 0
        var boosts: Int = 0

        var total: Int { posts + replies + boosts }
        var own: Int { posts + replies }

        var chars: Int = 0
        var cws: Int = 0
        var sensitive: Int = 0

        var withMedia: Int = 0
        var media: Int = 0
        var altText: Int = 0

        /// Normalized (which currently means lower-cased and nothing else).
        var hashtags = [String: Int]()
        /// Includes mentions and boosts of.
        var accounts = [String: Int]()
        /// Includes mentions and boosts of.
        var instances = [String: Int]()
        /// Activity on their own statuses, counting replies, boosts, and favs.
        var statuses = [Status.Id: Int]()

        mutating func add(_ status: Status, localInstance: String) {
            if status.reblog != nil {
                boosts += 1
            } else if let inReplyToAccountId = status.inReplyToAccountId,
                      inReplyToAccountId != status.account.id {
                replies += 1
            } else {
                posts += 1
            }

            if let boost = status.reblog {
                if boost.account.id != status.account.id {
                    addInteraction(acct: boost.account.acct, localInstance: localInstance)
                }
                return
            }

            chars += status.content.attrStr.characters.count
            if !status.spoilerText.isEmpty {
                cws += 1
            }
            if status.sensitive {
                sensitive += 1
            }

            if !status.mediaAttachments.isEmpty {
                withMedia += 1
            }
            media += status.mediaAttachments.count
            altText += status.mediaAttachments.lazy.compactMap(\.description).count

            for mention in status.mentions {
                addInteraction(acct: mention.acct, localInstance: localInstance)
            }

            for tag in status.tags {
                let tagKey = Tag.normalizeName(tag.name)
                var count = hashtags[tagKey] ?? 0
                count += 1
                hashtags[tagKey] = count
            }

            statuses[status.id] = status.repliesCount + status.reblogsCount + status.favouritesCount
        }

        mutating private func addInteraction(acct: String, localInstance: String) {
            var account = acct
            let parts = account.split(separator: "@", maxSplits: 1)
            let instance: String
            if parts.count > 1 {
                instance = .init(parts[1])
            } else {
                account += "@" + localInstance
                instance = localInstance
            }

            var count: Int

            count = accounts[account] ?? 0
            count += 1
            accounts[account] = count

            count = instances[instance] ?? 0
            count += 1
            instances[instance] = count
        }

        mutating func add(_ spanStats: SpanStats) {
            posts += spanStats.posts
            replies += spanStats.replies
            boosts += spanStats.boosts

            chars += spanStats.chars
            cws += spanStats.cws
            sensitive += spanStats.sensitive

            withMedia += spanStats.withMedia
            media += spanStats.media
            altText += spanStats.altText

            for (tagKey, count) in spanStats.hashtags {
                var total = hashtags[tagKey] ?? 0
                total += count
                hashtags[tagKey] = total
            }

            for (account, count) in spanStats.accounts {
                var total = accounts[account] ?? 0
                total += count
                accounts[account] = total
            }

            for (instance, count) in spanStats.instances {
                var total = instances[instance] ?? 0
                total += count
                instances[instance] = total
            }

            // statuses should never have any overlap between days.
            for (id, count) in spanStats.statuses {
                statuses[id] = count
            }
        }
    }
}
