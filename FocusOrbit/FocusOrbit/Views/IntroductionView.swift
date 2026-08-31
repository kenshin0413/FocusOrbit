import SwiftData
import SwiftUI

struct IntroductionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router: AppRouter
    let settings: AppSettings
    @State private var page = 0
    @State private var drifting = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                welcomePage.tag(0)
                focusFlowPage.tag(1)
                readyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? Color.white : Color.white.opacity(0.18))
                            .frame(width: index == page ? 34 : 20, height: 3)
                            .animation(.easeInOut(duration: 0.3), value: page)
                    }
                    Spacer()
                    Button(String(localized: "introduction.skip", defaultValue: "スキップ")) { finish() }
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                }
                .padding(.horizontal, 24).padding(.top, 12)
                Spacer()
                Button(page == 2 ? String(localized: "introduction.finish", defaultValue: "ミッション管制へ") : String(localized: "common.continue", defaultValue: "続ける")) {
                    if page == 2 { finish() } else { withAnimation { page += 1 } }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(.white, in: Capsule())
                .foregroundStyle(.black).fontWeight(.semibold)
                .padding(.horizontal, 24).padding(.bottom, 12)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drifting = true }
        }
    }

    private var welcomePage: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Image("EarthNASA")
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width * 1.25, height: proxy.size.width * 1.25)
                    .clipShape(Circle())
                    .offset(x: drifting ? -48 : -62, y: drifting ? -128 : -110)
                    .opacity(0.82)
                LinearGradient(colors: [.clear, .black.opacity(0.22), .black], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 14) {
                    Text("FOCUS ORBIT").font(.system(size: 11, design: .monospaced)).tracking(2.4).foregroundStyle(AppTheme.blue)
                    Text(String(localized: "introduction.welcome.title", defaultValue: "深い集中への航行は、\nここから始まります。"))
                        .font(.system(size: 34, weight: .semibold, design: .rounded)).lineSpacing(5)
                    Text(String(localized: "introduction.welcome.detail", defaultValue: "目的地へ到着するまで、ひとつのことに集中する。\n宇宙船と進む、静かな集中タイマーです。"))
                        .font(.subheadline).foregroundStyle(AppTheme.secondary).lineSpacing(4)
                }
                .padding(.horizontal, 28).padding(.bottom, 128)
            }
        }
    }

    private var focusFlowPage: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Text(String(localized: "introduction.promises.title", defaultValue: "集中を妨げない、\n3つの約束。"))
                .font(.system(size: 32, weight: .semibold, design: .rounded)).lineSpacing(4)
            VStack(spacing: 12) {
                promise("1", String(localized: "introduction.promise1.title", defaultValue: "出発前に決める"), String(localized: "introduction.promise1.detail", defaultValue: "集中内容・時間・目的地を設定します"), "slider.horizontal.3")
                promise("2", String(localized: "introduction.promise2.title", defaultValue: "航行中は完全自動"), String(localized: "introduction.promise2.detail", defaultValue: "タップやチェックインは要求しません"), "location.north.fill")
                promise("3", String(localized: "introduction.promise3.title", defaultValue: "到着後に記録"), String(localized: "introduction.promise3.detail", defaultValue: "集中時間と航行結果を端末に残します"), "checkmark.seal.fill")
            }
            Text(String(localized: "introduction.promises.footer", defaultValue: "操作するのは、開始前と終了後だけです。"))
                .font(.subheadline).foregroundStyle(AppTheme.blue)
            Spacer().frame(height: 118)
        }
        .padding(.horizontal, 24)
    }

    private var readyPage: some View {
        GeometryReader { proxy in
            ZStack {
                SparseIntroductionStars()
                CelestialBodyView(kind: .destination(.moon), rotationSpeed: 0)
                    .frame(width: 150, height: 150)
                    .offset(x: 84, y: -178)
                    .scaleEffect(drifting ? 1.04 : 0.98)
                Image("CockpitIntegratedReady")
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                VStack(alignment: .leading, spacing: 13) {
                    Spacer()
                    Text(String(localized: "introduction.ready.title", defaultValue: "準備はできましたか？")).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(String(localized: "introduction.ready.detail", defaultValue: "集中内容と時間を決め、ミッションパスを認証すると航行が始まります。"))
                        .font(.subheadline).foregroundStyle(AppTheme.secondary).lineSpacing(4)
                    HStack(spacing: 8) {
                        Label(String(localized: "introduction.ready.duration", defaultValue: "1〜180分"), systemImage: "timer")
                        Label(String(localized: "introduction.ready.destinations", defaultValue: "5つの目的地"), systemImage: "sparkles")
                    }
                    .font(.caption).foregroundStyle(AppTheme.blue)
                    Spacer().frame(height: 116)
                }
                .padding(.horizontal, 26)
            }
        }
    }

    private func promise(_ number: String, _ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(AppTheme.blue.opacity(0.11))
                Image(systemName: symbol).foregroundStyle(AppTheme.blue)
            }.frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(AppTheme.secondary)
        }
        .padding(15).background(AppTheme.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(AppTheme.line))
    }

    private func finish() {
        settings.hasCompletedIntroduction = true
        try? context.save()
        router.returnHome()
    }
}

private struct SparseIntroductionStars: View {
    var body: some View {
        Canvas(opaque: true, colorMode: .linear) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            for index in 0..<24 {
                let x = CGFloat((index * 431 + 59) % 997) / 997 * size.width
                let y = CGFloat((index * 677 + 31) % 991) / 991 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(.white.opacity(0.28)))
            }
        }
    }
}
