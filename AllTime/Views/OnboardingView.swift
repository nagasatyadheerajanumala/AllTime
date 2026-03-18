import SwiftUI

// MARK: - Onboarding Slideshow

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentSlide = 0
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.92
    // Gentle scale: starts at 1.0, drifts to 1.05 over time
    @State private var activeZoom: CGFloat = 1.0

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            imageName: "onboarding_today",
            subtitle: "MORNING BRIEFING",
            title: "Start your day with clarity",
            description: "Your schedule, health, and priorities — all in one glance.",
            accentColor: Color(hex: "3B82F6")
        ),
        OnboardingSlide(
            imageName: "onboarding_calendar",
            subtitle: "CIRCULAR CALENDAR",
            title: "Your calendar, reimagined",
            description: "A beautiful wheel view that makes navigating your month effortless.",
            accentColor: Color(hex: "8B5CF6")
        ),
        OnboardingSlide(
            imageName: "onboarding_protect",
            subtitle: "FOCUS PROTECTION",
            title: "Guard your deep work automatically",
            description: "Clara detects open windows and blocks focus time before it slips away.",
            accentColor: Color(hex: "EF4444")
        ),
        OnboardingSlide(
            imageName: "onboarding_health",
            subtitle: "HEALTH INTELLIGENCE",
            title: "Work with your energy, not against it",
            description: "Track trends in sleep, steps, and heart rate alongside your calendar.",
            accentColor: Color(hex: "10B981")
        ),
        OnboardingSlide(
            imageName: "onboarding_insights",
            subtitle: "WEEKLY INSIGHTS",
            title: "See the patterns shaping your week",
            description: "A work-life balance score with actionable quick wins.",
            accentColor: Color(hex: "6366F1")
        ),
        OnboardingSlide(
            imageName: "onboarding_actions",
            subtitle: "SMART ACTIONS",
            title: "Intelligent nudges, right on time",
            description: "Deep work blocks, activity alerts, and lunch breaks — all suggested for you.",
            accentColor: Color(hex: "F59E0B")
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)

                // Slide content
                TabView(selection: $currentSlide) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        OnboardingSlideView(
                            slide: slide,
                            zoomScale: currentSlide == index ? activeZoom : 1.0
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Text content below the image
                VStack(spacing: 10) {
                    Text(slides[currentSlide].subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(slides[currentSlide].accentColor)

                    Text(slides[currentSlide].title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(slides[currentSlide].description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.3), value: currentSlide)

                Spacer().frame(height: 24)

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentSlide ? Color.white : Color.white.opacity(0.25))
                            .frame(
                                width: index == currentSlide ? 24 : 8,
                                height: 8
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
                    }
                }
                .padding(.bottom, 24)

                // Continue / Get Started button
                Button(action: {
                    if currentSlide < slides.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSlide += 1
                        }
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentSlide == slides.count - 1 ? "Get Started" : "Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(slides[currentSlide].accentColor)
                        .cornerRadius(14)
                        .animation(.easeInOut(duration: 0.4), value: currentSlide)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
            .scaleEffect(contentScale)
        }
        .onAppear {
            animateEntrance()
        }
        .onChange(of: currentSlide) { _, _ in
            startGentleZoom()
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
            contentOpacity = 1.0
            contentScale = 1.0
        }
        // Kick off the first gentle zoom after entrance settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            startGentleZoom()
        }
    }

    private func startGentleZoom() {
        // Reset to 1.0 instantly, then drift to 1.05 slowly
        activeZoom = 1.0
        withAnimation(.easeInOut(duration: 4.0)) {
            activeZoom = 1.05
        }
    }
}

// MARK: - Slide Data

private struct OnboardingSlide {
    let imageName: String
    let subtitle: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Slide View

private struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let zoomScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let frameWidth = geo.size.width - 40
            let frameHeight = geo.size.height

            ZStack {
                // Dark fill behind image
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(hex: "1C1C1E"))
                    .frame(width: frameWidth, height: frameHeight)

                // Screenshot image — fits entirely within the frame
                Image(slide.imageName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale, anchor: .center)
                    .frame(width: frameWidth, height: frameHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                // Bottom gradient fade for text readability
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.7),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: frameHeight * 0.25)
                }
                .frame(width: frameWidth, height: frameHeight)
                .clipShape(RoundedRectangle(cornerRadius: 30))

                // Subtle border
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: frameWidth, height: frameHeight)
            }
            .shadow(color: slide.accentColor.opacity(0.15), radius: 30, x: 0, y: 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
