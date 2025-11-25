import SwiftUI

struct MainTabView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var summaryViewModel = DailySummaryViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        TabView {
            CalendarView()
                .environmentObject(calendarViewModel)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            DailySummaryView()
                .environmentObject(summaryViewModel)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Summary")
                }
            
            SettingsView()
                .environmentObject(settingsViewModel)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}

