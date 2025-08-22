//
//  MessageView.swift
//  ThereThen
//
//  Created by Paul Wicks on 8/13/25.
//
import SwiftUI
import Combine

struct MessageView: View {
    @State private var selectedFilter: MessageFilter = .all
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showingNewMessage = false
    @State private var selectedChannel: Channel?
    @State private var wsClient: WebSocketClient? = nil

    var body: some View {
        NavigationView {
            VStack {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    Text("All").tag(MessageFilter.all)
                    Text("Anonymous").tag(MessageFilter.anonymous)
                    Text("With PII").tag(MessageFilter.withPii)
                    Text("Restricted").tag(MessageFilter.restricted)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Messages List
                if isLoading {
                    Spacer()
                    ProgressView("Loading messages...")
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No messages yet")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("Join a channel to start messaging")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Join Channel") {
                            // Navigate to channels
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(filteredMessages) { message in
                        MessageRowView(message: message)
                            .onTapGesture {
                                // Handle message tap
                            }
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Message") {
                        showingNewMessage = true
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                NewMessageView(wsClient: wsClient)
            }
            .onAppear {
                loadMessages()
                // Connect to WebSocket for real-time updates
                let wsUrl = URL(string: "ws://yourserver/ws/chat/")!
                let client = WebSocketClient(url: wsUrl)
                client.onMessage = { messageText in
                    if let data = messageText.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let newMessage = Message(
                            id: json["id"] as? String ?? UUID().uuidString,
                            channel: selectedChannel ?? Channel(
                                id: json["channelId"] as? String ?? "ws",
                                name: json["channel"] as? String ?? "WebSocket",
                                area: GeographicArea(
                                    id: "",
                                    name: nil,
                                    geometryWkt: nil,
                                    startYear: 0,
                                    endYear: 0,
                                    startMonth: nil,
                                    endMonth: nil,
                                    createdBy: nil,
                                    createdAt: nil
                                ),
                                createdBy: nil,
                                isPrivate: false,
                                createdAt: nil,
                                updatedAt: nil,
                                memberCount: 1
                            ),
                            author: User(
                                id: "ws",
                                email: "",
                                username: json["author"] as? String ?? "Unknown",
                                firstName: nil,
                                lastName: nil,
                                isVerified: false,
                                verificationDate: nil,
                                createdAt: ""
                            ),
                            content: json["content"] as? String ?? "",
                            isAnonymous: json["isAnonymous"] as? Bool ?? false,
                            containsPii: json["containsPii"] as? Bool ?? false,
                            restrictedToNames: json["restrictedToNames"] as? [String] ?? [],
                            createdAt: json["createdAt"] as? String,
                            updatedAt: json["updatedAt"] as? String,
                            reactions: [:],
                            // ...existing code...
                        )
                        DispatchQueue.main.async {
                            messages.insert(newMessage, at: 0)
                        }
                    }
}
                client.connect()
                wsClient = client
            }
            .onDisappear {
                wsClient?.disconnect()
            }
        }
    }

    private var filteredMessages: [Message] {
        switch selectedFilter {
        case .all:
            return messages
        case .anonymous:
            return messages.filter { $0.isAnonymous }
        case .withPii:
            return messages.filter { $0.containsPii }
        case .restricted:
            return messages.filter { !$0.restrictedToNames.isEmpty }
        }
    }

    private func loadMessages() {
        isLoading = true

        // Load messages from all channels the user is a member of
        APIClient.shared.getMyChannels()
            .flatMap { channels -> AnyPublisher<[Message], Error> in
                let publishers = channels.map { channel in
                    APIClient.shared.getMessagesByChannel(channel.id)
                }
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { messageArrays in
                        messageArrays.flatMap { $0 }
                    }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading messages: \(error)")
                    }
                },
                receiveValue: { allMessages in
                    messages = allMessages.sorted {
                        ($0.createdAt ?? "") > ($1.createdAt ?? "")
                    }
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

struct MessageRowView: View {
    let message: Message
    @State private var showingReactions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message Header
            HStack {
                VStack(alignment: .leading) {
                    Text(message.isAnonymous ? "Anonymous" : message.author.username)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(message.channel.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatDate(message.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Message Content
            Text(message.content)
                .font(.body)
                .lineLimit(3)

            // Message Metadata
            HStack {
                if message.containsPii {
                    Label("Contains PII", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if !message.restrictedToNames.isEmpty {
                    Label("Restricted", systemImage: "lock")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                // Reactions
                if !message.reactions.isEmpty {
                    Button(action: {
                        showingReactions.toggle()
                    }) {
                        HStack(spacing: 4) {
                            ForEach(Array(message.reactions.prefix(3)), id: \.key) { reactionType, count in
                                Text(getReactionEmoji(reactionType))
                                    .font(.caption)
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingReactions) {
            ReactionsView(message: message)
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else {
            return "N/A"
        }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }

    private func getReactionEmoji(_ reactionType: String) -> String {
        switch reactionType {
        case "like": return "👍"
        case "love": return "❤️"
        case "laugh": return "😂"
        case "wow": return "😮"
        case "sad": return "😢"
        case "angry": return "😠"
        default: return "👍"
        }
    }
}

struct NewMessageView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedChannel: Channel?
    @State private var messageContent = ""
    @State private var isAnonymous = true
    @State private var containsPii = false
    @State private var restrictedToNames: [String] = []
    @State private var showingChannelPicker = false
    @State private var availableChannels: [Channel] = []
    @State private var isLoading = false
    var wsClient: WebSocketClient?

    var body: some View {
        NavigationView {
            Form {
                Section("Channel") {
                    HStack {
                        Text(selectedChannel?.name ?? "Select Channel")
                            .foregroundColor(selectedChannel == nil ? .secondary : .primary)

                        Spacer()

                        Button("Choose") {
                            showingChannelPicker = true
                        }
                    }
                }

                Section("Message") {
                    TextField("Type your message...", text: $messageContent, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Privacy Settings") {
                    Toggle("Send Anonymously", isOn: $isAnonymous)

                    Toggle("Contains Personal Information", isOn: $containsPii)

                    if !isAnonymous {
                        VStack(alignment: .leading) {
                            Text("Restrict to specific names:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(restrictedToNames.indices, id: \.self) { index in
                                HStack {
                                    TextField("Name", text: $restrictedToNames[index])
                                        .textFieldStyle(RoundedBorderTextFieldStyle())

                                    Button("Remove") {
                                        restrictedToNames.remove(at: index)
                                    }
                                    .foregroundColor(.red)
                                }
                            }

                            Button("Add Name") {
                                restrictedToNames.append("")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Send") {
                    sendMessage()
                }
                .disabled(messageContent.isEmpty || selectedChannel == nil || isLoading)
            )
            .sheet(isPresented: $showingChannelPicker) {
                ChannelPickerView(
                    channels: availableChannels,
                    selectedChannel: $selectedChannel
                )
            }
            .onAppear {
                loadChannels()
            }
        }
    }

    private func loadChannels() {
        APIClient.shared.getMyChannels()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error loading channels: \(error)")
                    }
                },
                receiveValue: { channels in
                    availableChannels = channels
                }
            )
            .store(in: &cancellables)
    }

    private func sendMessage() {
        guard let channel = selectedChannel else { return }

        isLoading = true

        APIClient.shared.createMessage(
            channelId: channel.id,
            content: messageContent,
            isAnonymous: isAnonymous,
            containsPii: containsPii,
            restrictedToNames: restrictedToNames
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("Error sending message: \(error)")
                }
                else {
                    let messageDict: [String: Any] = [
                        "content": messageContent,
                        "author": "Lost Connection", // Replace with current user if available
                        "channel": selectedChannel?.name ?? "",
                        "createdAt": ISO8601DateFormatter().string(from: Date()),
                        "isAnonymous": isAnonymous,
                        "containsPii": containsPii,
                        "restrictedToNames": restrictedToNames
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: messageDict),
                    let jsonString = String(data: jsonData, encoding: .utf8) {
                        wsClient?.send(message: jsonString)
                    }
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

struct ChannelPickerView: View {
    let channels: [Channel]
    @Binding var selectedChannel: Channel?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(channels) { channel in
                Button(action: {
                    selectedChannel = channel
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.name)
                            .font(.headline)

                        Text("\(channel.memberCount) members")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(channel.area.name ?? "Unnamed Area")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Channel")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct ReactionsView: View {
    let message: Message
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedReaction: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Reaction")
                    .font(.title2)
                    .fontWeight(.semibold)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(["like", "love", "laugh", "wow", "sad", "angry"], id: \.self) { reactionType in
                        Button(action: {
                            selectedReaction = reactionType
                            addReaction(reactionType)
                        }) {
                            VStack(spacing: 8) {
                                Text(getReactionEmoji(reactionType))
                                    .font(.system(size: 40))

                                Text(reactionType.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(selectedReaction == reactionType ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(12)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func getReactionEmoji(_ reactionType: String) -> String {
        switch reactionType {
        case "like": return "👍"
        case "love": return "❤️"
        case "laugh": return "😂"
        case "wow": return "😮"
        case "sad": return "😢"
        case "angry": return "😠"
        default: return "👍"
        }
    }

    private func addReaction(_ reactionType: String) {
        APIClient.shared.reactToMessage(message.id, reactionType: reactionType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error adding reaction: \(error)")
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

#Preview {
    MessageView()
}
