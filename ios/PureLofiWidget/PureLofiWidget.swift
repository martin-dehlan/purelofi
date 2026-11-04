// The home and lock screen widget (#144). Not yet a target in the Xcode
// project: see ios/PureLofiWidget/README.md for the three steps to add it.
import AppIntents
import SwiftUI
import WidgetKit

private let group = "group.app.purelofi"

struct RoomEntry: TimelineEntry {
  let date: Date
  let room: String
  let track: String?
  let artist: String?
  let cover: UIImage?
  let playing: Bool
}

struct RoomProvider: TimelineProvider {
  func placeholder(in context: Context) -> RoomEntry {
    RoomEntry(date: .now, room: "Rainy Room", track: "Dusk Tape", artist: nil, cover: nil, playing: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (RoomEntry) -> Void) {
    completion(read())
  }

  // The app writes and reloads on every change, so one entry is enough.
  func getTimeline(in context: Context, completion: @escaping (Timeline<RoomEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .never))
  }

  private func read() -> RoomEntry {
    let data = UserDefaults(suiteName: group)
    let path = data?.string(forKey: "cover")
    return RoomEntry(
      date: .now,
      room: data?.string(forKey: "room") ?? "PureLofi",
      track: data?.string(forKey: "track"),
      artist: data?.string(forKey: "artist"),
      cover: path.flatMap { UIImage(contentsOfFile: $0) },
      playing: data?.bool(forKey: "playing") ?? false
    )
  }
}

struct RoomWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: RoomEntry

  var body: some View {
    switch family {
    case .accessoryRectangular:
      VStack(alignment: .leading) {
        Text(entry.room).font(.caption2)
        Text(entry.track ?? "PureLofi").font(.headline).lineLimit(1)
      }
    default:
      HStack(spacing: 12) {
        cover.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 6))
        if family != .systemSmall {
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.room).font(.caption).foregroundStyle(.secondary)
            Text(entry.track ?? "PureLofi").font(.headline).lineLimit(1)
            if let artist = entry.artist { Text(artist).font(.caption).foregroundStyle(.secondary) }
          }
          Spacer()
          Button(intent: OpenToPlayIntent()) {
            Image(systemName: entry.playing ? "pause.fill" : "play.fill")
              .foregroundStyle(Color(red: 0.94, green: 0.63, blue: 0.36))
          }
          .buttonStyle(.plain)
        }
      }
      .containerBackground(Color(red: 0.01, green: 0.01, blue: 0.03), for: .widget)
    }
  }

  // Nearest-neighbour: the pixel art stays crisp.
  @ViewBuilder private var cover: some View {
    if let image = entry.cover {
      Image(uiImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fill)
    } else {
      Color.gray.opacity(0.2)
    }
  }
}

/// Opens the app, which carries on playing: a widget cannot start audio on
/// its own while the app is not running.
struct OpenToPlayIntent: AppIntent {
  static var title: LocalizedStringResource = "Play PureLofi"
  static var openAppWhenRun: Bool = true
  func perform() async throws -> some IntentResult { .result() }
}

@main
struct PureLofiWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PureLofiWidget", provider: RoomProvider()) { entry in
      RoomWidgetView(entry: entry)
    }
    .configurationDisplayName("PureLofi")
    .description("The room you are in, and what plays.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}
