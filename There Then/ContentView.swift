//
//  ContentView.swift
//  There Then
//
//  Created by Paul Wicks on 8/13/25.
//
import SwiftUI
import Combine

struct ContentView: View {
    @State private var selectedTab: AppTab = .map
    @StateObject private var apiClient = APIClient.shared
    @State private var isAuthenticated = false
    @State private var currentUser: User?

    var body: some View {
        if isAuthenticated {
            TabView(selection: $selectedTab) {
                MapView()
                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }
                    .tag(AppTab.map)

                MessageView()
                    .tabItem {
                        Image(systemName: "message")
                        Text("Messages")
                    }
                    .tag(AppTab.messages)

                ChannelView()
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Channels")
                    }
                    .tag(AppTab.channels)

                ProfileView(currentUser: $currentUser, isAuthenticated: $isAuthenticated)
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Profile")
                    }
                    .tag(AppTab.profile)
            }
            .accentColor(.blue)
        } else {
            AuthenticationView(isAuthenticated: $isAuthenticated, currentUser: $currentUser)
        }
    }
}

struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @Binding var currentUser: User?
    @State private var isSignUp = false
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo/Title
                VStack(spacing: 10) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("ThereThen")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Connect through shared places and times")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Authentication Form
                VStack(spacing: 15) {
                    if isSignUp {
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 20)

                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action Button
                Button(action: {
                    if isSignUp {
                        signUp()
                    } else {
                        signIn()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || !isFormValid)
                .padding(.horizontal, 20)

                // Toggle Authentication Mode
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = ""
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                }

                Spacer()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // No-op here; AuthenticationView will handle auto-login via launchEnvironment
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !username.isEmpty && !password.isEmpty &&
                   !confirmPassword.isEmpty && password == confirmPassword &&
                   !firstName.isEmpty && !lastName.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }

        isLoading = true
        errorMessage = ""

        APIClient.shared.createUser(
            email: email,
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            },
            receiveValue: { loginResponse in
                APIClient.shared.setAuthToken(loginResponse.access)
                APIClient.shared.getCurrentUser()
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                errorMessage = error.localizedDescription
                            }
                        },
                        receiveValue: { user in
                            currentUser = user
                            isAuthenticated = true
                        }
                    )
                    .store(in: &cancellables)
            }
        )
        .store(in: &cancellables)
    }

    private func signIn() {
        isLoading = true
        errorMessage = ""

        APIClient.shared.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { loginResponse in
                    // Set the access token
                    APIClient.shared.setAuthToken(loginResponse.access)

                    // Get the current user details
                    APIClient.shared.getCurrentUser()
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    errorMessage = error.localizedDescription
                                }
                            },
                            receiveValue: { user in
                                currentUser = user
                                isAuthenticated = true
                            }
                        )
                        .store(in: &cancellables)
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

struct ProfileView: View {
    @Binding var currentUser: User?
    @Binding var isAuthenticated: Bool
    @State private var isEditing = false
    @State private var editedFirstName = ""
    @State private var editedLastName = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 15) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)

                    Text(currentUser?.firstName ?? currentUser?.username ?? "User")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text(currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: currentUser?.isVerified == true ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundColor(currentUser?.isVerified == true ? .green : .red)

                        Text(currentUser?.isVerified == true ? "Verified" : "Not Verified")
                            .font(.caption)
                            .foregroundColor(currentUser?.isVerified == true ? .green : .red)
                    }
                }
                .padding()

                // Profile Actions
                VStack(spacing: 15) {
                    Button("Edit Profile") {
                        isEditing = true
                        editedFirstName = currentUser?.firstName ?? ""
                        editedLastName = currentUser?.lastName ?? ""
                    }
                    .buttonStyle(.bordered)

                    Button("Sign Out") {
                        // Clear authentication
                        APIClient.shared.setAuthToken("")
                        currentUser = nil
                        isAuthenticated = false
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                }

                Spacer()
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $isEditing) {
                EditProfileView(
                    firstName: $editedFirstName,
                    lastName: $editedLastName,
                    isPresented: $isEditing
                )
            }
        }
    }
}

struct EditProfileView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var isPresented: Bool
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveProfile()
                }
                .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
            )
        }
    }

    private func saveProfile() {
        isLoading = true

        APIClient.shared.updateProfile(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    // Handle error
                    print("Error updating profile: \(error)")
                }
            },
            receiveValue: { _ in
                isPresented = false
            }
        )
        .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    ContentView()
}
