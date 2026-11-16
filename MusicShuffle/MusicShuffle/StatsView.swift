//
//  StatsView.swift
//  MusicShuffle
//

import Charts
import MusicShuffleCore
import SwiftUI

struct StatsView: View {
    @Environment(StatsRecorder.self) private var recorder
    @State private var range = StatsRange.current(.week)
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    @State private var customEnd = Date.now
    @State private var statistics: PlayStatistics?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: unitBinding) {
                        ForEach(StatsUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    if range.unit == .custom {
                        DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        DatePicker("To", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    } else {
                        rangeNavigator
                    }
                }

                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                } else if let statistics {
                    if statistics.totalPlays == 0 {
                        ContentUnavailableView("No Plays", systemImage: "chart.bar",
                                               description: Text("Plays in this range show here."))
                    } else {
                        StatsContent(statistics: statistics)
                    }
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                if recorder.isCheckingLibrary {
                    ProgressView()
                        .accessibilityLabel("Checking the music library for new plays")
                }
            }
            .refreshable { await recorder.checkLibrary() }
            .task(id: LoadKey(range: range, revision: recorder.revision)) { await load() }
            .onChange(of: customStart) { updateCustomRange() }
            .onChange(of: customEnd) { updateCustomRange() }
        }
    }

    private var unitBinding: Binding<StatsUnit> {
        Binding {
            range.unit
        } set: { unit in
            if unit == .custom {
                range = .custom(from: customStart, through: customEnd)
            } else {
                range = .current(unit)
            }
        }
    }

    private var rangeNavigator: some View {
        HStack {
            Button("Previous", systemImage: "chevron.backward") { range = range.shifted(by: -1) }
                .disabled(!range.canShift)
            Spacer()
            Text(range.title)
                .font(.headline)
            Spacer()
            Button("Next", systemImage: "chevron.forward") { range = range.shifted(by: 1) }
                .disabled(!range.canShift || range.contains(.now))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func updateCustomRange() {
        if range.unit == .custom {
            range = .custom(from: customStart, through: customEnd)
        }
    }

    private func load() async {
        do {
            let statistics = try await recorder.store.statistics(for: range)
            // The range can change while the statistics load. `.task(id:)` then starts a new load.
            guard !Task.isCancelled else { return }
            self.statistics = statistics
            loadError = nil
        } catch {
            loadError = "Could not load the play history: \(error.localizedDescription)"
        }
    }

    private struct LoadKey: Hashable {
        let range: StatsRange
        let revision: Int
    }
}

private struct StatsContent: View {
    let statistics: PlayStatistics
    private let topCount = 10

    var body: some View {
        Section {
            HStack {
                SummaryTile(title: "Plays", value: statistics.totalPlays.formatted())
                SummaryTile(title: "Listening Time", value: Duration.seconds(statistics.listeningTime)
                    .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
            }
            if let artist = statistics.topArtists.first {
                LabeledContent("Top Artist", value: artist.title)
            }
        } footer: {
            if statistics.estimatedPlays > 0 {
                Text("^[\(statistics.estimatedPlays) play](inflect: true) occurred while the app was closed. Their dates are estimated.")
            }
        }

        if !statistics.timeline.isEmpty {
            Section("Plays Over Time") {
                Chart(statistics.timeline) { bucket in
                    BarMark(x: .value("Date", bucket.start, unit: statistics.timelineComponent),
                            y: .value("Plays", bucket.plays))
                }
                .chartXScale(domain: chartDomain)
                .frame(height: 180)
            }
        }

        rankedSection("Top Songs", items: statistics.topSongs)
        rankedSection("Top Artists", items: statistics.topArtists)
        rankedSection("Top Albums", items: statistics.topAlbums)
    }

    private var chartDomain: ClosedRange<Date> {
        if let interval = statistics.range.interval {
            return interval.start...interval.end
        }
        let dates = statistics.timeline.map(\.start)
        let first = dates.min() ?? .now
        return first...max(dates.max() ?? .now, first.addingTimeInterval(1))
    }

    private func rankedSection(_ title: String, items: [RankedItem]) -> some View {
        Section(title) {
            ForEach(Array(items.prefix(topCount).enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 24, alignment: .trailing)
                    VStack(alignment: .leading) {
                        Text(item.title)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    Spacer()
                    Text("^[\(item.plays) play](inflect: true)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension StatsUnit {
    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .allTime: "All"
        case .custom: "Custom"
        }
    }
}

private extension StatsRange {
    var title: String {
        guard let interval else { return "All Time" }
        switch unit {
        case .day:
            return interval.start.formatted(.dateTime.weekday(.wide).month().day().year())
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .year:
            return interval.start.formatted(.dateTime.year())
        case .week, .custom, .allTime:
            // The interval end is the start of the next day, so show the day before it.
            let lastDay = interval.end.addingTimeInterval(-1)
            return (interval.start..<lastDay).formatted(.interval.month(.abbreviated).day().year())
        }
    }
}
