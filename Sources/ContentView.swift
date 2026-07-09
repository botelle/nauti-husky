import SwiftUI

struct ContentView: View {
    @Bindable var model: SpotsModel
    @Bindable var prefs: Preferences

    @State private var showingSettings = false
    @State private var showingMap = false
    @State private var showingList = false

    private var skyPhase: Sky.Phase {
        Sky.phase(coord: model.selected?.coordinate)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .idle, .locating, .discovering:
                    statusView(progressLabel)
                case .failed(let message):
                    failureView(message)
                case .loading, .ready:
                    contentScroll
                }
            }
            .background(Sky.gradient(skyPhase).ignoresSafeArea())
            .navigationTitle("Nauti Husky")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                if model.isRefreshing {
                    ToolbarItem(placement: .automatic) {
                        ProgressView().controlSize(.small)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingMap = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .disabled(model.spots.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $showingList) {
                SpotListView(model: model, prefs: prefs)
            }
            .sheet(isPresented: $showingMap) {
                SpotMapView(model: model, prefs: prefs)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(prefs: prefs, model: model) {
                    Task { await model.refresh() }
                }
            }
        }
        .preferredColorScheme(Sky.isDark(skyPhase) ? .dark : .light)
        .task {
            await model.refresh()
        }
    }

    // MARK: - Main content

    private var contentScroll: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    spotPicker
                    favoriteButton
                }

                if let conditions = model.conditions {
                    ConditionsCard(conditions: conditions, prefs: prefs)
                } else {
                    ProgressView().padding(.top, 40)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .refreshable { await model.refresh() }
    }

    private var spotPicker: some View {
        Button {
            showingList = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selected?.name ?? "Choose a spot")
                        .font(.headline)
                        .lineLimit(1)
                    if let s = model.selected {
                        Text(spotSubtitle(s))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Label("\(model.spots.count)", systemImage: "list.bullet")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spotPickerButton")
    }

    private var favoriteButton: some View {
        Button {
            if let spot = model.selected { prefs.toggleFavorite(spot) }
        } label: {
            let on = model.selected.map(prefs.isFavorite) ?? false
            Image(systemName: on ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(on ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(model.selected == nil)
    }

    private func spotSubtitle(_ spot: SwimSpot) -> String {
        "\(spot.kindLabel) · \(miles(spot.distanceMiles)) away"
    }

    // MARK: - Status / failure

    private var progressLabel: String {
        switch model.phase {
        case .locating:    return "Finding your location…"
        case .discovering: return "Looking for swim spots nearby…"
        default:           return "Loading…"
        }
    }

    private func statusView(_ label: String) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.refresh() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func miles(_ d: Double) -> String {
        String(format: "%.1f mi", d)
    }
}

// MARK: - Conditions card

struct ConditionsCard: View {
    let conditions: SpotConditions
    let prefs: Preferences

    var body: some View {
        VStack(spacing: 18) {
            VerdictBanner(verdict: verdict)
            waterSection
            Divider()
            tideSection
            weatherSection
            outlookSection
            lightningSection
            aboutSection
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .skyCard()
    }

    @ViewBuilder
    private var aboutSection: some View {
        let info = KnownSpots.info(for: conditions.spot)
        let directions = KnownSpots.directionsURL(for: conditions.spot)
        if info != nil || directions != nil {
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("About this spot")
                    .font(.subheadline.weight(.semibold))
                if let info {
                    ForEach(info.amenities, id: \.text) { a in
                        Label {
                            Text(a.text).font(.caption)
                        } icon: {
                            Image(systemName: a.symbol).foregroundStyle(.blue)
                        }
                    }
                }
                HStack(spacing: 16) {
                    if let directions {
                        Link(destination: directions) {
                            Label("Directions & parking", systemImage: "map")
                        }
                    }
                    if let url = info?.infoURL {
                        Link(destination: url) {
                            Label("More info", systemImage: "info.circle")
                        }
                    }
                }
                .font(.caption.weight(.medium))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var outlookSection: some View {
        let points = SwimOutlook.hours(conditions,
                                       tidePreference: prefs.tidePreference,
                                       tideWindowHours: prefs.tideWindowHours,
                                       avoidDawnDusk: prefs.avoidDawnDusk)
        if points.count > 1 {
            Divider()
            let window = SwimOutlook.bestWindow(points)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today's outlook")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let window {
                        Text("Best \(hourLabel(window.start))–\(hourLabel(window.end))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.teal)
                    } else {
                        Text("No clear window soon")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(points) { p in
                            VStack(spacing: 5) {
                                Text(hourLabel(p.time))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Circle()
                                    .fill(levelColor(p.level))
                                    .frame(width: 12, height: 12)
                                Text(p.airTempF.map { "\(Int($0.rounded()))°" } ?? "–")
                                    .font(.caption2.monospacedDigit())
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour())
    }

    private func levelColor(_ level: SwimVerdict.Level) -> Color {
        switch level {
        case .good:    return .teal
        case .caution: return .orange
        case .avoid:   return .red
        }
    }

    private var verdict: SwimVerdict.Result {
        SwimVerdict.evaluate(conditions,
                             tidePreference: prefs.tidePreference,
                             tideWindowHours: prefs.tideWindowHours,
                             avoidDawnDusk: prefs.avoidDawnDusk)
    }

    @ViewBuilder
    private var waterSection: some View {
        if let water = conditions.water {
            VStack(spacing: 6) {
                Text(fahrenheit(water.waterF))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("water · as of \(water.timestamp.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            CoolingBandView(waterF: water.waterF)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "water.waves")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No water-temp sensor here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Pick a 🌡 spot for water temperature.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }

        if let air = conditions.airTempF {
            let detail: String = {
                if let w = conditions.water?.waterF {
                    let gap = w - air
                    return " · \(gap >= 0 ? "+" : "")\(fahrenheit(gap)) vs water"
                }
                return ""
            }()
            Text("Air \(fahrenheit(air))\(detail)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tideSection: some View {
        if let tides = conditions.tides {
            let advice = TideAdvisor.advise(tides,
                                            preference: prefs.tidePreference,
                                            windowHours: prefs.tideWindowHours)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "water.waves.and.arrow.trianglehead.up")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        if let next = tides.nextEvent() {
                            Text("\(next.kind == .high ? "High" : "Low") tide \(next.time.formatted(.relative(presentation: .named)))")
                                .font(.callout)
                            Text(String(format: "%.1f ft · %@", next.heightFt,
                                        next.time.formatted(date: .omitted, time: .shortened)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let advice {
                            Text(advice.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(advice.color)
                        }
                    }
                    Spacer()
                }
                TideCurveView(tides: tides)
            }
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let weather = conditions.weather {
            HStack(spacing: 10) {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    if let f = weather.shortForecast {
                        Text(f).font(.callout)
                    }
                    if let p = weather.thunderstormProbability, p > 0 {
                        Text("Thunderstorm chance \(p)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(weather.activeAlerts, id: \.self) { alert in
                        Text(alert)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
            }
        }
    }

    private var lightningSection: some View {
        HStack(spacing: 10) {
            Image(systemName: lightning.symbol)
                .foregroundStyle(lightning.color)
            Text(lightning.label)
                .font(.callout)
                .foregroundStyle(lightning.color)
            Spacer()
        }
    }

    private var lightning: (symbol: String, label: String, color: Color) {
        switch conditions.lightning {
        case .unknown:
            return ("bolt.slash", "Lightning: no data", .secondary)
        case .clear:
            return ("bolt.slash", "No lightning risk", .teal)
        case .nearbyStrikes(let n):
            if n > 0 {
                return ("bolt.fill", "Lightning: \(n) strike\(n == 1 ? "" : "s") nearby — stay out", .red)
            }
            return ("bolt.fill", "Thunderstorm risk — stay out of the water", .red)
        }
    }

    private func fahrenheit(_ v: Double) -> String {
        String(format: "%.1f°F", v)
    }
}

// MARK: - Verdict banner

struct VerdictBanner: View {
    let verdict: SwimVerdict.Result

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: verdict.symbol)
                .font(.title2)
                .foregroundStyle(verdict.color)
            VStack(alignment: .leading, spacing: 4) {
                Text(verdict.headline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(verdict.color)
                ForEach(verdict.reasons.prefix(3), id: \.self) { reason in
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(verdict.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Cooling band

struct CoolingBandView: View {
    let waterF: Double

    var body: some View {
        let info = DogTemp.band(for: waterF)
        Text(info.label)
            .font(.title3.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(info.color.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(info.color)
    }
}

// MARK: - Spot list

struct SpotListView: View {
    @Bindable var model: SpotsModel
    var prefs: Preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let favs = model.spots.filter { prefs.isFavorite($0) }
                let others = model.spots.filter { !prefs.isFavorite($0) }
                if !favs.isEmpty {
                    Section("Favorites") {
                        ForEach(favs) { row($0) }
                    }
                }
                Section(favs.isEmpty ? "Spots" : "Nearby") {
                    ForEach(others) { row($0) }
                }
            }
            .navigationTitle("Swim spots")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ spot: SwimSpot) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.select(spot) }
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: spot.kindSymbol)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.name).font(.body)
                        Text("\(spot.kindLabel) · \(String(format: "%.1f mi", spot.distanceMiles))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.selected == spot {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                prefs.toggleFavorite(spot)
            } label: {
                Image(systemName: prefs.isFavorite(spot) ? "star.fill" : "star")
                    .foregroundStyle(prefs.isFavorite(spot) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Bindable var prefs: Preferences
    var model: SpotsModel
    var onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var initialRadius: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Search radius") {
                    VStack(alignment: .leading) {
                        Text("\(Int(prefs.radiusMiles)) miles")
                            .font(.headline)
                        Slider(value: $prefs.radiusMiles, in: 5...100, step: 5)
                    }
                }

                Section("Tides") {
                    Picker("Preference", selection: $prefs.tidePreference) {
                        ForEach(TidePreference.allCases) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    if prefs.tidePreference != .none {
                        Stepper(value: $prefs.tideWindowHours, in: 1...4, step: 0.5) {
                            Text("Window ±\(prefs.tideWindowHours, format: .number) h")
                        }
                    }
                }

                Section {
                    Toggle("Avoid dawn & dusk", isOn: $prefs.avoidDawnDusk)
                        .onChange(of: prefs.avoidDawnDusk) { _, _ in
                            Task { await model.refreshNotifications() }
                        }
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Flags the hour around sunrise and sunset — low light and prime fish-feeding times. Night stays neutral.")
                }

                Section {
                    Toggle("Tell me when it's a good time", isOn: $prefs.notifyOnGoodWindow)
                        .onChange(of: prefs.notifyOnGoodWindow) { _, on in
                            Task {
                                if on { _ = await SwimNotifier.requestAuthorization() }
                                await model.refreshNotifications()
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("A heads-up when the next good swim window opens at your selected spot.")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if prefs.radiusMiles != initialRadius { onApply() }
                        dismiss()
                    }
                }
            }
            .onAppear { initialRadius = prefs.radiusMiles }
        }
    }
}
