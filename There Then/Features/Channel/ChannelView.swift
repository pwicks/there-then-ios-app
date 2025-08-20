//
//  ChannelView.swift
//  There Then
//
//  Created by Paul Wicks on 8/13/25.
//
import SwiftUI
import Combine

struct ChannelView: View {
    @State private var channels: [Channel] = []
    @State private var isLoading = false
    @State private var showingNewChannel = false
    @State private var searchText = ""
    @State private var selectedFilter: ChannelFilter = .all

    var body: some View {
        NavigationView {
            VStack {
                // Search and Filter
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search channels...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        Text("All").tag(ChannelFilter.all)
                        Text("My Channels").tag(ChannelFilter.myChannels)
                        Text("Public").tag(ChannelFilter.public)
                        Text("Private").tag(ChannelFilter.private)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.top)

                // Channels List
                if isLoading {
                    Spacer()
                    ProgressView("Loading channels...")
                    Spacer()
                } else if filteredChannels.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No channels found")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("Create a new channel or join existing ones")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Create Channel") {
                            showingNewChannel = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(filteredChannels) { channel in
                        ChannelRowView(channel: channel) {
                            loadChannels()
                        }
                    }
                }
            }
            .navigationTitle("Channels")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Channel") {
                        showingNewChannel = true
                    }
                }
            }
            .sheet(isPresented: $showingNewChannel) {
                NewChannelView()
            }
            .onAppear {
                loadChannels()
            }
        }
    }

    private var filteredChannels: [Channel] {
        var filtered = channels

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { channel in
                channel.name.localizedCaseInsensitiveContains(searchText) ||
                (channel.area.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .myChannels:
            // This would need to be implemented based on user membership
            break
        case .public:
            filtered = filtered.filter { !$0.isPrivate }
        case .private:
            filtered = filtered.filter { $0.isPrivate }
        }

        return filtered
    }

    private func loadChannels() {
        isLoading = true

        APIClient.shared.getMyChannels()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading channels: \(error)")
                    }
                },
                receiveValue: { userChannels in
                    channels = userChannels
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

enum ChannelFilter {
    case all
    case myChannels
    case `public`
    case `private`
}

struct ChannelRowView: View {
    let channel: Channel
    let onUpdate: () -> Void

    @State private var showingChannelDetails = false
    @State private var isJoining = false
    @State private var isLeaving = false

    var body: some View {
        Button(action: {
            showingChannelDetails = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Channel Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(channel.name)
                                .font(.headline)
                                .fontWeight(.semibold)

                            if channel.isPrivate {
                                Image(systemName: "lock")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        Text(channel.area.name ?? "Unnamed Area")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(channel.memberCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)

                        Text("members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Channel Metadata
                HStack {
                    Text("Created by \(channel.createdBy?.username ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let createdAt = channel.createdAt {
                        Text(formatDate(createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Action Buttons
                HStack {
                    if isJoining {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Joining...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isLeaving {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Leaving...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Join") {
                            joinChannel()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Leave") {
                            leaveChannel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingChannelDetails) {
            ChannelDetailsView(channel: channel)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }

    private func joinChannel() {
        isJoining = true

        APIClient.shared.joinChannel(channel.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isJoining = false
                    if case .failure(let error) = completion {
                        print("Error joining channel: \(error)")
                    }
                },
                receiveValue: { _ in
                    onUpdate()
                }
            )
            .store(in: &cancellables)
    }

    private func leaveChannel() {
        isLeaving = true

        APIClient.shared.leaveChannel(channel.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLeaving = false
                    if case .failure(let error) = completion {
                        print("Error leaving channel: \(error)")
                    }
                },
                receiveValue: { _ in
                    onUpdate()
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

struct NewChannelView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var channelName = ""
    @State private var selectedArea: GeographicArea?
    @State private var isPrivate = false
    @State private var availableAreas: [GeographicArea] = []
    @State private var showingAreaPicker = false
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Form {
                Section("Channel Details") {
                    TextField("Channel Name", text: $channelName)

                    HStack {
                        Text(selectedArea?.name ?? "Select Area")
                            .foregroundColor(selectedArea == nil ? .secondary : .primary)

                        Spacer()

                        Button("Choose") {
                            showingAreaPicker = true
                        }
                    }

                    Toggle("Private Channel", isOn: $isPrivate)
                }

                Section("Channel Info") {
                    if let area = selectedArea {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Area: \(area.name ?? "Unnamed")")
                                .font(.subheadline)

                            Text("Time Period: \(area.startYear) - \(area.endYear)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let startMonth = area.startMonth, let endMonth = area.endMonth {
                                Text("Months: \(startMonth) - \(endMonth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Channel")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    createChannel()
                }
                .disabled(channelName.isEmpty || selectedArea == nil || isLoading)
            )
            .sheet(isPresented: $showingAreaPicker) {
                AreaPickerView(
                    areas: availableAreas,
                    selectedArea: $selectedArea
                )
            }
            .onAppear {
                loadAreas()
            }
        }
    }

    private func loadAreas() {
        // Load areas that the user has created or has access to
        // For now, we'll use a mock approach
        availableAreas = [
            GeographicArea(
                id: "mock-area-1",
                name: "San Francisco 2020-2024",
                geometryWkt: nil,
                startYear: 2020,
                endYear: 2024,
                startMonth: nil,
                endMonth: nil,
                createdBy: User(
                    id: "mock-user",
                    email: "user@example.com",
                    username: "user",
                    firstName: nil,
                    lastName: nil,
                    isVerified: false,
                    verificationDate: nil,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                ),
                createdAt: nil
            )
        ]
    }

    private func createChannel() {
        guard let area = selectedArea else { return }

        isLoading = true

        APIClient.shared.createChannel(
            name: channelName,
            areaId: area.id,
            isPrivate: isPrivate
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("Error creating channel: \(error)")
                }
            },
            receiveValue: { _ in
                presentationMode.wrappedValue.dismiss()
            }
        )
        .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

struct AreaPickerView: View {
    let areas: [GeographicArea]
    @Binding var selectedArea: GeographicArea?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(areas) { area in
                Button(action: {
                    selectedArea = area
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(area.name ?? "Unnamed Area")
                            .font(.headline)

                        Text("\(area.startYear) - \(area.endYear)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let startMonth = area.startMonth, let endMonth = area.endMonth {
                            Text("Months: \(startMonth) - \(endMonth)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Area")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct ChannelDetailsView: View {
    let channel: Channel
    @State private var members: [ChannelMembership] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Channel Info
                VStack(alignment: .leading, spacing: 10) {
                    Text(channel.name)
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Area: \(channel.area.name ?? "Unnamed")")
                        .font(.subheadline)

                    Text("Time Period: \(channel.area.startYear) - \(channel.area.endYear)")
                        .font(.subheadline)

                    HStack {
                        Text("\(channel.memberCount) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if channel.isPrivate {
                            Label("Private", systemImage: "lock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Members Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Members")
                        .font(.headline)

                    if isLoading {
                        ProgressView()
                    } else if members.isEmpty {
                        Text("No members yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(members) { membership in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(membership.user.username)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text("Joined \(formatDate(membership.joinedAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if membership.isAdmin {
                                    Text("Admin")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Channel Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMembers()
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }

    private func loadMembers() {
        isLoading = true

        APIClient.shared.getChannelMembers(channel.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading members: \(error)")
                    }
                },
                receiveValue: { channelMembers in
                    members = channelMembers
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    ChannelView()
}
