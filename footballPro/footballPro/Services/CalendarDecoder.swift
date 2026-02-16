//
//  CalendarDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 CALENDER.DAT.
//  Format: SPC: header (year range + rotation mapping) + 7× SWC: sections (26 dates each).
//  Each SWC variant provides 26 season dates: 4 offseason milestones + 22 game week dates.
//  The SPC rotation maps each year (1992-2019) to one of the 7 SWC variants.
//

import Foundation

struct SeasonDate: Equatable {
    let month: Int  // 1-12
    let day: Int    // 1-31

    /// Resolve to a Foundation Date for a given season start year.
    /// Months 9-12 use the start year; months 1-2 use startYear+1.
    func resolve(seasonStartYear: Int) -> Date? {
        let year = month >= 9 ? seasonStartYear : seasonStartYear + 1
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
}

struct SeasonCalendar: Equatable {
    let weekDates: [SeasonDate]  // 26 dates: 4 offseason + 22 game weeks

    /// Game week dates only (indices 4-25), used for scheduling
    var gameWeekDates: [SeasonDate] {
        guard weekDates.count > 4 else { return weekDates }
        return Array(weekDates[4...])
    }
}

struct CalendarData: Equatable {
    let startYear: Int   // 1992
    let endYear: Int     // 2019
    let preseasonCount: Int
    let gameWeekCount: Int
    let variantCount: Int
    let yearRotation: [Int]          // 1-based variant index per year
    let variants: [SeasonCalendar]   // 7 SWC calendar variants

    /// Look up the calendar variant for a given year
    func weekDates(for year: Int) -> [SeasonDate] {
        let yearIndex = year - startYear
        let rotation: Int
        if yearIndex >= 0 && yearIndex < yearRotation.count {
            rotation = yearRotation[yearIndex]
        } else {
            // Wrap around for years outside the defined range
            let wrapped = ((year - startYear) % yearRotation.count + yearRotation.count) % yearRotation.count
            rotation = yearRotation[wrapped]
        }
        // rotation is 1-based
        let variantIndex = rotation - 1
        guard variantIndex >= 0 && variantIndex < variants.count else {
            return variants.first?.gameWeekDates ?? []
        }
        return variants[variantIndex].gameWeekDates
    }
}

struct CalendarDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    static func decode(at url: URL) throws -> CalendarData {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else {
            throw DecoderError.fileTooSmall
        }

        var pos = 0
        var variants: [SeasonCalendar] = []
        var startYear = 1992
        var endYear = 2019
        var preseasonCount = 4
        var gameWeekCount = 22
        var variantCount = 7
        var yearRotation: [Int] = []

        while pos < data.count - 4 {
            let marker = String(data: data[pos..<pos+4], encoding: .ascii) ?? ""

            if marker == "SPC:" {
                let sectionSize = Int(data[pos+4]) | (Int(data[pos+5]) << 8) |
                                  (Int(data[pos+6]) << 16) | (Int(data[pos+7]) << 24)
                let contentStart = pos + 8

                // Bytes 0-1: start year (uint16 LE)
                startYear = Int(data[contentStart]) | (Int(data[contentStart+1]) << 8)
                // Bytes 2-3: end year (uint16 LE)
                endYear = Int(data[contentStart+2]) | (Int(data[contentStart+3]) << 8)
                // Byte 4: preseason date count
                preseasonCount = Int(data[contentStart+4])
                // Byte 5: game week date count
                gameWeekCount = Int(data[contentStart+5])
                // Byte 6: variant count
                variantCount = Int(data[contentStart+6])

                // Bytes 7+: year rotation mapping (1-based variant indices)
                let rotationCount = endYear - startYear + 1
                let rotStart = contentStart + 7
                for i in 0..<rotationCount {
                    if rotStart + i < data.count {
                        yearRotation.append(Int(data[rotStart + i]))
                    }
                }

                pos += 8 + sectionSize

            } else if marker == "SWC:" {
                let sectionSize = Int(data[pos+4]) | (Int(data[pos+5]) << 8) |
                                  (Int(data[pos+6]) << 16) | (Int(data[pos+7]) << 24)
                let contentStart = pos + 8

                // Content is (sectionSize / 2) date pairs of (month, day)
                let dateCount = sectionSize / 2
                var dates: [SeasonDate] = []
                for i in 0..<dateCount {
                    let offset = contentStart + i * 2
                    guard offset + 1 < data.count else { break }
                    let month = Int(data[offset])
                    let day = Int(data[offset + 1])
                    if month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                        dates.append(SeasonDate(month: month, day: day))
                    }
                }

                variants.append(SeasonCalendar(weekDates: dates))
                pos += 8 + sectionSize
            } else {
                pos += 1
            }
        }

        return CalendarData(
            startYear: startYear,
            endYear: endYear,
            preseasonCount: preseasonCount,
            gameWeekCount: gameWeekCount,
            variantCount: variantCount,
            yearRotation: yearRotation,
            variants: variants
        )
    }

    static func loadDefault() -> CalendarData? {
        let url = defaultDirectory.appendingPathComponent("CALENDER.DAT")
        guard let calendar = try? decode(at: url) else { return nil }
        print("[CalendarDecoder] Loaded \(calendar.variants.count) calendar variants, years \(calendar.startYear)-\(calendar.endYear)")
        return calendar
    }

    enum DecoderError: Error {
        case fileTooSmall
    }
}
