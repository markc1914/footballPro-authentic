//
//  CoachingProfileTests.swift
//  footballProTests
//
//  Tests for the Coaching Profile system: situation bucketing, profile generation,
//  weighted play type rolling, and AI integration.
//

import Foundation
import Testing
@testable import footballPro

@Suite("Coaching Profile Tests")
struct CoachingProfileTests {

    // MARK: - Bucket Mapping Tests

    @Test("TimeBucket maps seconds remaining correctly")
    func timeBucketMapping() {
        #expect(TimeBucket.from(secondsRemainingInHalf: 30) == .t0_2)
        #expect(TimeBucket.from(secondsRemainingInHalf: 119) == .t0_2)
        #expect(TimeBucket.from(secondsRemainingInHalf: 120) == .t2_5)
        #expect(TimeBucket.from(secondsRemainingInHalf: 299) == .t2_5)
        #expect(TimeBucket.from(secondsRemainingInHalf: 300) == .t5_8)
        #expect(TimeBucket.from(secondsRemainingInHalf: 600) == .t8_12)
        #expect(TimeBucket.from(secondsRemainingInHalf: 780) == .t12_15)
        #expect(TimeBucket.from(secondsRemainingInHalf: 1800) == .t15plus)
    }

    @Test("YardsBucket maps yards to go correctly")
    func yardsBucketMapping() {
        #expect(YardsBucket.from(yardsToGo: 1) == .y1_2)
        #expect(YardsBucket.from(yardsToGo: 2) == .y1_2)
        #expect(YardsBucket.from(yardsToGo: 3) == .y3_5)
        #expect(YardsBucket.from(yardsToGo: 5) == .y3_5)
        #expect(YardsBucket.from(yardsToGo: 6) == .y6_10)
        #expect(YardsBucket.from(yardsToGo: 10) == .y6_10)
        #expect(YardsBucket.from(yardsToGo: 11) == .y11_15)
        #expect(YardsBucket.from(yardsToGo: 15) == .y11_15)
        #expect(YardsBucket.from(yardsToGo: 16) == .y16plus)
        #expect(YardsBucket.from(yardsToGo: 25) == .y16plus)
    }

    @Test("FieldZone maps field position correctly")
    func fieldZoneMapping() {
        #expect(FieldZone.from(fieldPosition: 5) == .own1_10)
        #expect(FieldZone.from(fieldPosition: 10) == .own1_10)
        #expect(FieldZone.from(fieldPosition: 11) == .own11_25)
        #expect(FieldZone.from(fieldPosition: 25) == .own11_25)
        #expect(FieldZone.from(fieldPosition: 40) == .own26_50)
        #expect(FieldZone.from(fieldPosition: 50) == .own26_50)
        #expect(FieldZone.from(fieldPosition: 60) == .opp49_26)
        #expect(FieldZone.from(fieldPosition: 80) == .opp25_11)
        #expect(FieldZone.from(fieldPosition: 95) == .opp10_1)
        #expect(FieldZone.from(fieldPosition: 99) == .goalLine)
    }

    @Test("ScoreDiffBucket maps score differential correctly")
    func scoreDiffBucketMapping() {
        #expect(ScoreDiffBucket.from(scoreDifferential: -14) == .losingBig)
        #expect(ScoreDiffBucket.from(scoreDifferential: -8) == .losingBig)
        #expect(ScoreDiffBucket.from(scoreDifferential: -7) == .within7)
        #expect(ScoreDiffBucket.from(scoreDifferential: 0) == .within7)
        #expect(ScoreDiffBucket.from(scoreDifferential: 7) == .within7)
        #expect(ScoreDiffBucket.from(scoreDifferential: 8) == .aheadBig)
        #expect(ScoreDiffBucket.from(scoreDifferential: 21) == .aheadBig)
    }

    // MARK: - Situation Key Tests

    @Test("CoachingSituationKey from GameSituation maps correctly")
    func situationKeyFromGameSituation() {
        let situation = GameSituation(
            down: 3, yardsToGo: 7, fieldPosition: 65,
            quarter: 4, timeRemaining: 180, scoreDifferential: -3, isRedZone: false
        )
        let key = CoachingSituationKey.from(situation: situation)

        #expect(key.down == 3)
        #expect(key.distance == .y6_10)
        #expect(key.field == .opp49_26)
        #expect(key.scoreDiff == .within7)
        // Q4 with 180 seconds = second quarter of second half, so secondsInHalf = 180
        #expect(key.time == .t2_5)
    }

    @Test("CoachingSituationKey from Q1 converts to half-remaining correctly")
    func situationKeyQ1() {
        let situation = GameSituation(
            down: 1, yardsToGo: 10, fieldPosition: 25,
            quarter: 1, timeRemaining: 600, scoreDifferential: 0, isRedZone: false
        )
        let key = CoachingSituationKey.from(situation: situation)
        // Q1 with 600s remaining + 900s for Q2 = 1500 seconds in half = 25 minutes
        #expect(key.time == .t15plus)
    }

    // MARK: - Profile Generation Tests

    @Test("OFF1 generates 2,520 offensive situations")
    func off1SituationCount() {
        let profile = CoachingProfileDefaults.off1
        #expect(profile.offensiveSituationCount == 2520)
        #expect(profile.name == "OFF1")
        #expect(profile.fgRange >= 5)
        #expect(profile.fgRange <= 50)
    }

    @Test("OFF2 generates 2,520 offensive situations")
    func off2SituationCount() {
        let profile = CoachingProfileDefaults.off2
        #expect(profile.offensiveSituationCount == 2520)
        #expect(profile.name == "OFF2")
    }

    @Test("DEF1 generates 2,520 defensive situations")
    func def1SituationCount() {
        let profile = CoachingProfileDefaults.def1
        #expect(profile.defensiveSituationCount == 2520)
        #expect(profile.name == "DEF1")
    }

    @Test("DEF2 generates 2,520 defensive situations")
    func def2SituationCount() {
        let profile = CoachingProfileDefaults.def2
        #expect(profile.defensiveSituationCount == 2520)
        #expect(profile.name == "DEF2")
    }

    @Test("All 4 default profiles are available")
    func allDefaultProfiles() {
        let profiles = CoachingProfileDefaults.allProfiles
        #expect(profiles.count == 4)
        let names = Set(profiles.map(\.name))
        #expect(names.contains("OFF1"))
        #expect(names.contains("OFF2"))
        #expect(names.contains("DEF1"))
        #expect(names.contains("DEF2"))
    }

    // MARK: - Weighted Roll Tests

    @Test("Offensive roll returns a valid play type for every situation")
    func offensiveRollCoversAllSituations() {
        let profile = CoachingProfileDefaults.off1
        // Sample 20 random situations and verify all return a result
        let testSituations: [(Int, Int, Int, Int, Int)] = [
            (60, 1, 10, 25, 0),    // Normal 1st and 10 from own 25
            (30, 3, 7, 60, -10),   // 3rd and 7 from opp 40, losing big, 30 sec
            (900, 1, 10, 99, 0),   // 1st and goal from 1
            (120, 4, 1, 50, 3),    // 4th and 1 at midfield, up 3
            (300, 2, 15, 10, -14), // 2nd and 15 from own 10, losing badly
        ]

        for (secs, down, ytg, fp, sd) in testSituations {
            let key = CoachingSituationKey.from(
                secondsInHalf: secs, down: down, yardsToGo: ytg,
                fieldPosition: fp, scoreDifferential: sd
            )
            let result = profile.rollOffensivePlayType(for: key)
            #expect(result != nil, "No offensive response for \(key)")
        }
    }

    @Test("Defensive roll returns a valid play type for every situation")
    func defensiveRollCoversAllSituations() {
        let profile = CoachingProfileDefaults.def1
        let testSituations: [(Int, Int, Int, Int, Int)] = [
            (60, 1, 10, 25, 0),
            (30, 3, 7, 60, 10),
            (900, 1, 10, 99, 0),
            (120, 4, 1, 50, -3),
            (300, 2, 15, 10, 14),
        ]

        for (secs, down, ytg, fp, sd) in testSituations {
            let key = CoachingSituationKey.from(
                secondsInHalf: secs, down: down, yardsToGo: ytg,
                fieldPosition: fp, scoreDifferential: sd
            )
            let result = profile.rollDefensivePlayType(for: key)
            #expect(result != nil, "No defensive response for \(key)")
        }
    }

    @Test("Weights sum to 100 for all offensive situations in OFF1")
    func offensiveWeightsSum() {
        let profile = CoachingProfileDefaults.off1
        for (_, response) in profile.offensiveResponses {
            let total = response.choices.reduce(0) { $0 + $1.weight }
            #expect(total == 100, "Weights sum to \(total), expected 100")
        }
    }

    @Test("Weights sum to 100 for all defensive situations in DEF1")
    func defensiveWeightsSum() {
        let profile = CoachingProfileDefaults.def1
        for (_, response) in profile.defensiveResponses {
            let total = response.choices.reduce(0) { $0 + $1.weight }
            #expect(total == 100, "Weights sum to \(total), expected 100")
        }
    }

    // MARK: - Play Type Mapping Tests

    @Test("CoachingPlayType.matchingPlayTypes returns non-empty arrays")
    func playTypeMappings() {
        for cpt in CoachingPlayType.allCases {
            #expect(!cpt.matchingPlayTypes.isEmpty, "No matching play types for \(cpt)")
            #expect(!cpt.matchingCategories.isEmpty, "No matching categories for \(cpt)")
        }
    }

    @Test("CoachingDefensivePlayType.matchingCoverages returns non-empty arrays")
    func defensivePlayTypeMappings() {
        for dpt in CoachingDefensivePlayType.allCases {
            #expect(!dpt.matchingCoverages.isEmpty, "No matching coverages for \(dpt)")
            #expect(!dpt.preferredFormations.isEmpty, "No preferred formations for \(dpt)")
        }
    }

    // MARK: - AICoach Integration Tests

    @Test("AICoach uses coaching profile for offensive selection")
    func aiCoachUsesProfile() {
        let coach = AICoach()
        coach.setProfiles(
            offensive: CoachingProfileDefaults.off1,
            defensive: CoachingProfileDefaults.def1
        )

        #expect(coach.offensiveProfile != nil)
        #expect(coach.defensiveProfile != nil)
        #expect(coach.offensiveProfile?.name == "OFF1")
        #expect(coach.defensiveProfile?.name == "DEF1")
    }

    @Test("Goal line situations produce goal line play types")
    func goalLineSituation() {
        let profile = CoachingProfileDefaults.off1
        let key = CoachingSituationKey(
            time: .t8_12, down: 1, distance: .y1_2,
            field: .goalLine, scoreDiff: .within7
        )
        let response = profile.offensiveResponse(for: key)
        #expect(response != nil)
        // Goal line responses should include goal line plays
        let types = response!.choices.map(\.type)
        let hasGoalLine = types.contains(.goalLineRun) || types.contains(.goalLinePass)
        #expect(hasGoalLine, "Goal line situation should include goal line plays, got \(types)")
    }

    @Test("2-minute drill losing produces pass-heavy responses")
    func twoMinuteDrill() {
        let profile = CoachingProfileDefaults.off1
        let key = CoachingSituationKey(
            time: .t0_2, down: 2, distance: .y6_10,
            field: .own26_50, scoreDiff: .losingBig
        )
        let response = profile.offensiveResponse(for: key)
        #expect(response != nil)
        #expect(response!.stopClock == true, "Should want to stop clock when trailing late")
        // Should be pass-heavy
        let types = response!.choices.map(\.type)
        let passCount = types.filter { !$0.isRun }.count
        #expect(passCount >= 2, "2-minute drill should be pass-heavy, got \(types)")
    }
}
