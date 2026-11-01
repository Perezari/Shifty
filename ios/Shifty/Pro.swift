import Observation
import StoreKit
// with StoreKit, SwiftUI brings the App Store's purchase sheet (PurchaseAction)
import SwiftUI
import WidgetKit

/// Shifty Pro, bought once (ios/store/listing.md): a non-consumable in-app purchase. StoreKit keeps the
/// transactions; this follows them, and keeps what it finds in ProFlag for the widgets and for the app's
/// launches in the background. Its sheet (ProSheet) opens over the tabs from anything marked Pro.
@MainActor
@Observable
final class Pro {
    static let productID = "com.perezari.shifty.pro"
    static let shared = Pro()

    private(set) var unlocked: Bool
    /// The App Store's product, for its price: nil while it loads, or when the store can't be reached.
    private(set) var product: Product?
    private(set) var loading = true
    private(set) var busy = false
    var message: String?
    /// Shifty Pro's sheet, over the tabs (RootView).
    var offering = false
    /// The price shown without a product: the screenshots', as StoreKit has none in the simulator.
    @ObservationIgnored private var fallbackPrice: String?
    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        unlocked = ProFlag.on
        // purchases made elsewhere (another device, Ask to Buy approved, a refund) arrive here
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(result)
            }
        }
        Task {
            await refresh()
            await load()
        }
    }

    #if DEBUG
    /// The screenshots': Pro bought, as the store's pictures show the app, but for the picture of its sheet,
    /// with the price that App Store Connect sets.
    init(screenshot: Screenshot) {
        unlocked = screenshot != .pro
        loading = false
        fallbackPrice = "₪24.90"
    }
    #endif

    /// The App Store's price, as it shows it: "₪24.90".
    var price: String? {
        product?.displayPrice ?? fallbackPrice
    }

    /// Opens Shifty Pro's sheet.
    func offer() {
        message = nil
        offering = true
    }

    /// Whether the purchase is the account's, from the transactions StoreKit keeps on the device.
    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        set(owned)
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = unlocked ? "Shifty Pro שוחזר. תודה!" : "לא נמצאה רכישה קודמת ב-Apple ID הזה."
        } catch StoreKitError.userCancelled {
            // closing Apple's sign-in is not a failure
            message = nil
        } catch {
            message = "השחזור לא הושלם: \(error.localizedDescription)"
        }
    }

    /// The purchase, on the App Store's sheet: bought, or waiting for a parent's approval (Ask to Buy).
    func buy(with purchase: PurchaseAction) async {
        guard let product else { return }
        busy = true
        defer { busy = false }
        message = nil
        do {
            switch try await purchase(product) {
            case .success(let verification):
                await apply(verification)
            case .pending:
                message = "הרכישה ממתינה לאישור. Shifty Pro ייפתח כשהיא תאושר."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "הרכישה לא הושלמה: \(error.localizedDescription)"
        }
    }

    private func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        loading = false
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, transaction.productID == Self.productID else { return }
        set(transaction.revocationDate == nil)
        await transaction.finish()
    }

    /// Kept for the widgets and the launches in the background, and the widgets and the Control Center's switch
    /// drawn again with it; the app (RootView) starts or stops the rest.
    private func set(_ owned: Bool) {
        guard owned != unlocked || owned != ProFlag.on else { return }
        unlocked = owned
        ProFlag.set(owned)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}
