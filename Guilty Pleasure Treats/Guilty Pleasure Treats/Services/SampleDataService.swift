//
//  SampleDataService.swift
//  Guilty Pleasure Treats
//
//  Seeds Firestore with sample bakery products. Run once (e.g. from Admin or dev menu).
//  Sample products use Unsplash image URLs (free to use) chosen to match each item (cupcakes, cookies, cakes, brownies).
//

import Foundation

enum SampleDataService {
    /// Unsplash image URL helper (w=400 for menu thumbnails).
    private static func u(_ path: String) -> String {
        "https://images.unsplash.com/\(path)?w=400&q=80&fit=crop"
    }

    static let sampleProducts: [Product] = [
        Product(
            name: "Red Velvet Cupcake",
            productDescription: "Classic red velvet with cream cheese frosting and a hint of cocoa.",
            price: 4.50,
            imageURL: u("photo-1578922864601-79dcc7cbcea9"), // red/pink cupcakes
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true,
            stockQuantity: 24,
            lowStockThreshold: 5
        ),
        Product(
            name: "Chocolate Lovers Cupcake",
            productDescription: "Rich chocolate cake with chocolate buttercream and sprinkles.",
            price: 4.25,
            imageURL: u("photo-1563729784474-d77dbb933a9e"), // chocolate cupcake
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true,
            stockQuantity: 18,
            lowStockThreshold: 5
        ),
        Product(
            name: "Vanilla Bean Cupcake",
            productDescription: "Light vanilla cake with vanilla bean frosting.",
            price: 3.99,
            imageURL: u("photo-1559989260-d4c4a0d358c9"), // vanilla cupcake
            category: ProductCategory.cupcakes.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true,
            stockQuantity: 12,
            lowStockThreshold: 4
        ),
        Product(
            name: "Chocolate Chip Cookie",
            productDescription: "Fresh-baked cookie loaded with milk chocolate chips.",
            price: 2.50,
            imageURL: u("photo-1598839950984-034f6dc7b495"), // chocolate chip cookies
            category: ProductCategory.cookies.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true,
            stockQuantity: 36,
            lowStockThreshold: 8
        ),
        Product(
            name: "Oatmeal Raisin Cookie",
            productDescription: "Hearty oatmeal cookie with plump raisins and cinnamon.",
            price: 2.75,
            imageURL: u("photo-1622926421334-6829deee4b4b"), // oatmeal/brown cookies
            category: ProductCategory.cookies.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true,
            stockQuantity: 20,
            lowStockThreshold: 5
        ),
        Product(
            name: "Snickerdoodle",
            productDescription: "Soft cookie rolled in cinnamon sugar.",
            price: 2.50,
            imageURL: u("photo-1558961363-fa8fdf82db35"), // cinnamon/sugar cookies
            category: ProductCategory.cookies.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Birthday Cake (6 inch)",
            productDescription: "Two-layer vanilla or chocolate cake with buttercream. Serves 6-8.",
            price: 28.00,
            imageURL: u("photo-1625649611137-df49dc542f6a"), // birthday cake with candles
            category: ProductCategory.cakes.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Carrot Cake (8 inch)",
            productDescription: "Spiced carrot cake with cream cheese frosting and walnuts.",
            price: 32.00,
            imageURL: u("photo-1676300186098-9b5ae9916e3c"), // carrot cake slice
            category: ProductCategory.cakes.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Chocolate Fudge Brownie",
            productDescription: "Dense, fudgy brownie with a crackly top.",
            price: 4.00,
            imageURL: u("photo-1568241757756-935df2d96f03"), // chocolate brownies
            category: ProductCategory.brownies.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Blondie",
            productDescription: "Buttery brown sugar blondie with white chocolate chips.",
            price: 4.00,
            imageURL: u("photo-1631531515722-c47833e38f25"), // blondies/brown sugar bars
            category: ProductCategory.brownies.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Pumpkin Spice Cupcake",
            productDescription: "Seasonal pumpkin cupcake with cream cheese frosting and nutmeg.",
            price: 4.75,
            imageURL: u("photo-1577998474517-7eeeed4e448a"), // seasonal cupcake
            category: ProductCategory.seasonalTreats.rawValue,
            isFeatured: true,
            isSoldOut: false,
            isVegetarian: true
        ),
        Product(
            name: "Peppermint Brownie",
            productDescription: "Chocolate brownie with crushed candy canes. Holiday special.",
            price: 4.50,
            imageURL: u("photo-1607482369189-a53b6e71fa48"), // chocolate cake/brownie
            category: ProductCategory.seasonalTreats.rawValue,
            isFeatured: false,
            isSoldOut: false,
            isVegetarian: true
        ),
    ]

    // MARK: - Sample orders (shown when API returns empty or fails, so the orders list has example data)
    static var sampleOrders: [Order] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: today) ?? today
        }
        let taxRate = 0.08
        func tax(_ subtotal: Double) -> Double { subtotal * taxRate }
        func total(_ subtotal: Double) -> Double { subtotal + tax(subtotal) }

        return [
            Order(
                id: "sample-order-1",
                userId: nil,
                customerName: "Jordan Smith",
                customerPhone: "(555) 123-4567",
                items: [
                    OrderItem(id: "oi-1a", productId: "p1", name: "Red Velvet Cupcake", price: 4.50, quantity: 2, specialInstructions: ""),
                    OrderItem(id: "oi-1b", productId: "p2", name: "Chocolate Chip Cookie", price: 2.50, quantity: 1, specialInstructions: ""),
                ],
                subtotal: 11.50,
                tax: tax(11.50),
                total: total(11.50),
                fulfillmentType: FulfillmentType.pickup.rawValue,
                scheduledPickupDate: nil,
                status: OrderStatus.pending.rawValue,
                stripePaymentIntentId: nil,
                manualPaidAt: nil,
                createdAt: daysAgo(0),
                updatedAt: daysAgo(0),
                estimatedReadyTime: nil,
                customCakeOrderIds: nil,
                aiCakeDesignIds: nil
            ),
            Order(
                id: "sample-order-2",
                userId: nil,
                customerName: "Alex Rivera",
                customerPhone: "(555) 987-6543",
                items: [
                    OrderItem(id: "oi-2a", productId: "p3", name: "Birthday Cake (6 inch)", price: 28.00, quantity: 1, specialInstructions: "Happy Birthday Sam!"),
                ],
                subtotal: 28.00,
                tax: tax(28.00),
                total: total(28.00),
                fulfillmentType: FulfillmentType.delivery.rawValue,
                scheduledPickupDate: nil,
                status: OrderStatus.completed.rawValue,
                stripePaymentIntentId: nil,
                manualPaidAt: daysAgo(1),
                createdAt: daysAgo(1),
                updatedAt: daysAgo(1),
                estimatedReadyTime: nil,
                customCakeOrderIds: nil,
                aiCakeDesignIds: nil
            ),
            Order(
                id: "sample-order-3",
                userId: nil,
                customerName: "Morgan Lee",
                customerPhone: "(555) 246-8135",
                items: [
                    OrderItem(id: "oi-3a", productId: "p4", name: "Snickerdoodle", price: 2.50, quantity: 3, specialInstructions: ""),
                    OrderItem(id: "oi-3b", productId: "p5", name: "Vanilla Bean Cupcake", price: 3.99, quantity: 1, specialInstructions: ""),
                ],
                subtotal: 11.49,
                tax: tax(11.49),
                total: total(11.49),
                fulfillmentType: FulfillmentType.pickup.rawValue,
                scheduledPickupDate: nil,
                status: OrderStatus.ready.rawValue,
                stripePaymentIntentId: "pi_sample_123",
                manualPaidAt: nil,
                createdAt: daysAgo(3),
                updatedAt: daysAgo(3),
                estimatedReadyTime: nil,
                customCakeOrderIds: nil,
                aiCakeDesignIds: nil
            ),
            Order(
                id: "sample-order-4",
                userId: nil,
                customerName: "Casey Brown",
                customerPhone: "(555) 369-1470",
                items: [
                    OrderItem(id: "oi-4a", productId: "p6", name: "Chocolate Fudge Brownie", price: 4.00, quantity: 2, specialInstructions: ""),
                    OrderItem(id: "oi-4b", productId: "p7", name: "Oatmeal Raisin Cookie", price: 2.75, quantity: 2, specialInstructions: ""),
                ],
                subtotal: 13.50,
                tax: tax(13.50),
                total: total(13.50),
                fulfillmentType: FulfillmentType.shipping.rawValue,
                scheduledPickupDate: nil,
                status: OrderStatus.completed.rawValue,
                stripePaymentIntentId: "pi_sample_456",
                manualPaidAt: nil,
                createdAt: daysAgo(7),
                updatedAt: daysAgo(7),
                estimatedReadyTime: nil,
                customCakeOrderIds: nil,
                aiCakeDesignIds: nil
            ),
        ]
    }

    /// Seed products via Vercel API if needed (optional). Add sample products via admin or Neon.
    static func seedProductsIfNeeded() async throws {
        // Products are stored in Neon via Vercel API. Use admin in the app or insert via SQL to seed.
    }
}
