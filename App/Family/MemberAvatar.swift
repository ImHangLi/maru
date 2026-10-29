import MaruCore
import SwiftUI
import UIKit

extension Person {
    /// The name that the app shows: the user's name, or the word "Me" for "Me" before a rename (D121).
    var displayName: String { name ?? DoseOwner.meName }
}

extension PetSymbol {
    /// The SF Symbol of the avatar of a pet (D124).
    var systemImage: String {
        switch self {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .bird: "bird.fill"
        case .rabbit: "rabbit.fill"
        case .fish: "fish.fill"
        case .paw: "pawprint.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .dog: "Dog"
        case .cat: "Cat"
        case .bird: "Bird"
        case .rabbit: "Rabbit"
        case .fish: "Fish"
        case .paw: "Other Animal"
        }
    }
}

/// What an avatar draws. "Everyone" in the person menu of Today is not a member, so it has its own case.
enum AvatarSubject: Equatable {
    case member(Person)
    case everyone
}

/// The avatar of a member (D124, D127): the photo, else a soft fill of the member color with the initial, the person silhouette
/// for "Me", or the animal of a pet in the full member color. No gradient and no ring. "Me" and a member with no color use the
/// app color.
struct MemberAvatar: View {
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let subject: AvatarSubject
    let side: CGFloat
    /// A photo that is not stored yet, from the member page.
    var preview: UIImage?
    /// The image of a system menu draws at once, so it reads only the cache of the photos.
    var waitsForPhoto = true
    @State private var loaded: UIImage?

    init(_ person: Person, side: CGFloat, preview: UIImage? = nil) {
        subject = .member(person)
        self.side = side
        self.preview = preview
    }

    init(_ subject: AvatarSubject, side: CGFloat, waitsForPhoto: Bool = true) {
        self.subject = subject
        self.side = side
        self.waitsForPhoto = waitsForPhoto
    }

    private var person: Person? {
        if case let .member(person) = subject { person } else { nil }
    }

    private var photo: UIImage? {
        preview ?? person?.imageReference.flatMap(ItemPhotos.cached) ?? loaded
    }

    private var color: Color {
        (person?.color ?? appColor).tint
    }

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(color.opacity(0.16))
                    .overlay { glyph }
                    .foregroundStyle(color)
                    .frame(width: side, height: side)
            }
        }
        // The name is always beside the avatar, so VoiceOver reads the name and not the picture.
        .accessibilityHidden(true)
        .task(id: person?.imageReference) {
            loaded = nil
            guard waitsForPhoto, preview == nil, let reference = person?.imageReference else { return }
            loaded = await ItemPhotos.thumbnail(reference)
        }
    }

    @ViewBuilder private var glyph: some View {
        switch subject {
        case .everyone:
            Image(systemName: "person.2.fill")
                .font(.system(size: side * 0.36, weight: .medium))
        case let .member(person):
            switch person.kind {
            case .me:
                Image(systemName: "person.fill")
                    .font(.system(size: side * 0.5, weight: .medium))
                    .offset(y: side * 0.02)
            case .pet:
                Image(systemName: (person.symbol ?? .paw).systemImage)
                    .font(.system(size: side * 0.48, weight: .medium))
            case .person:
                Text(verbatim: person.displayName.first.map { String($0).uppercased() } ?? "")
                    .font(.system(size: side * 0.46, weight: .medium))
            }
        }
    }
}

extension MemberAvatar {
    /// The avatar as an image for a system menu, which draws only images. It keeps its own colors.
    @MainActor static func menuImage(_ subject: AvatarSubject, side: CGFloat = 24) -> Image {
        let style = UITraitCollection.current.userInterfaceStyle
        let renderer = ImageRenderer(content: MemberAvatar(subject, side: side, waitsForPhoto: false)
            .environment(\.colorScheme, style == .dark ? .dark : .light))
        renderer.scale = UITraitCollection.current.displayScale
        guard let image = renderer.uiImage else { return Image(systemName: "person.crop.circle") }
        return Image(uiImage: image.withRenderingMode(.alwaysOriginal))
    }
}

/// Overlapping avatars, each with a ring of the row color, as iOS Settings shows a family.
struct AvatarStack: View {
    let people: [Person]
    /// More avatars than this show as the first ones only, so a long Family does not push the row title.
    private let limit = 4

    var body: some View {
        HStack(spacing: -7) {
            ForEach(people.prefix(limit), id: \.id) { person in
                MemberAvatar(person, side: 26)
                    .padding(1.5)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            }
        }
    }
}
