import SwiftUI

struct RecentSkipBanner: View {
    let session: PlanSession

    var body: some View {
        let count = session.recentSkipCount
        if count > 0 {
            let minutes = session.plan?.settingsSnapshot.recentMinutes ?? 60
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Son \(minutes) dakikada \(count) öğe atlandı (yeni indirmeler).")
                        .font(.callout)
                    if session.recentSkipsDominate {
                        Text("Neredeyse hepsi yeni; eşiği düşürmeyi düşünün.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                OpenSettingsButton(title: "Hariç tutma…", tab: .ignore)
            }
            .padding(10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
