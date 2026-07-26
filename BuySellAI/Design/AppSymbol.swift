import Foundation

enum AppSymbol {
    enum Flow {
        static let snapPhoto = "camera.fill"
        static let snapPhotoCompact = "camera.fill"
        static let answer = "message.fill"
        static let copy = "doc.on.doc.fill"
        static let savedListing = "doc.text.fill"
        static let help = "info.circle.fill"
        static let complete = "checkmark.circle.fill"
    }

    enum Action {
        static let search = "magnifyingglass"
        static let composeListing = "square.and.pencil"
        static let edit = "pencil.circle.fill"
        static let retry = "arrow.clockwise"
        static let retakePhoto = "camera.rotate"
        static let addPhoto = "photo.badge.plus"
        static let category = "tag.fill"
        static let condition = "slider.horizontal.3"
    }

    enum Item {
        static let electronics = "iphone"
        static let home = "house.fill"
        static let clothing = "tshirt.fill"
        static let shoes = "shoeprints.fill"
        static let bags = "handbag.fill"
        static let jewelry = "diamond.fill"
        static let toys = "gamecontroller.fill"
        static let kids = "teddybear.fill"
        static let tools = "wrench.and.screwdriver.fill"
        static let sports = "basketball.fill"
        static let books = "books.vertical.fill"
        static let media = "play.rectangle.fill"
        static let music = "music.note"
        static let collectibles = "star.fill"
        static let art = "paintpalette.fill"
        static let other = "tag.fill"
    }

    enum Marketplace {
        static let cart = "cart.fill"
        static let local = "mappin.circle.fill"
        static let people = "person.2.fill"
        static let fashion = "tshirt.fill"
        static let package = "shippingbox.fill"
        static let video = "play.rectangle.fill"
        static let music = "music.note"
        static let art = "paintpalette.fill"
        static let verified = "checkmark.seal.fill"
        static let luxury = "handbag.fill"
        static let phone = "iphone"
        static let home = "house.fill"
        static let vintage = "clock.fill"
        static let cards = "rectangle.stack.fill"
    }

    enum Condition {
        static let newItem = "checkmark.seal.fill"
        static let likeNew = "checkmark.circle.fill"
        static let good = "hand.thumbsup.fill"
        static let fair = "exclamationmark.circle.fill"
        static let forParts = "wrench.fill"
    }

    static let familiarSellingSymbols: Set<String> = [
        Flow.snapPhoto,
        Flow.snapPhotoCompact,
        Flow.answer,
        Flow.copy,
        Flow.savedListing,
        Flow.help,
        Flow.complete,
        Action.search,
        Action.composeListing,
        Action.edit,
        Action.retry,
        Action.retakePhoto,
        Action.addPhoto,
        Action.category,
        Action.condition,
        Item.electronics,
        Item.home,
        Item.clothing,
        Item.shoes,
        Item.bags,
        Item.jewelry,
        Item.toys,
        Item.kids,
        Item.tools,
        Item.sports,
        Item.books,
        Item.media,
        Item.music,
        Item.collectibles,
        Item.art,
        Item.other,
        Marketplace.cart,
        Marketplace.local,
        Marketplace.people,
        Marketplace.fashion,
        Marketplace.package,
        Marketplace.video,
        Marketplace.music,
        Marketplace.art,
        Marketplace.verified,
        Marketplace.luxury,
        Marketplace.phone,
        Marketplace.home,
        Marketplace.vintage,
        Marketplace.cards,
        Condition.newItem,
        Condition.likeNew,
        Condition.good,
        Condition.fair,
        Condition.forParts
    ]
}
