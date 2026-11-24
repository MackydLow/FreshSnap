# FreshSnap

FreshSnap is an iPhone app that helps you waste less food. Snap your receipt, a use-by label or a barcode, and FreshSnap builds a virtual fridge, reminds you before food goes off, suggests recipes that use it up, and tracks how much money you've saved.

Built for CS32005 (Mobile App Development) by Mackenzie Low.

## Features

- Sign up, log in, reset password, change name or email, delete account (Firebase Authentication)
- Scan receipts (Apple Vision, with an AI fallback for unclear names), use-by labels and barcodes (Open Food Facts)
- Estimated use-by dates from USDA FoodKeeper data, bundled so it works offline
- Fridge sorted by use-by date, with search, filters and a freezer
- One daily reminder for food expiring soon; tapping it opens that food
- Recipes from TheMealDB that use your fridge food, with diet filters, favourites and "I cooked this"
- Nutrition with UK traffic-light ratings, and AI nutrition estimates for recipes
- Money saved, a weekly impact chart, a no-waste streak and badges
- Accessibility: Dynamic Type, VoiceOver, Reduce Motion and dark mode

## Built with

Swift, SwiftUI, SwiftData, VisionKit, Vision, AVFoundation, UserNotifications, Swift Charts, Firebase (Authentication, AI Logic, App Check), Open Food Facts, USDA FoodKeeper, TheMealDB.

## Requirements

- A Mac with the latest version of Xcode
- An iPhone with an A12 chip or newer (iPhone XS or later), connected by cable
- A free Apple ID

The app also runs in the Xcode Simulator, but camera scanning needs a real iPhone.

## How to run

1. Download the project: click the green **Code** button on this page and choose **Download ZIP**, then unzip it.
2. Open `FreshSnap.xcodeproj` in Xcode. Wait for the Swift packages (Firebase) to finish downloading.
3. In the left sidebar, click the blue **FreshSnap** project, choose the **FreshSnap** target, then **Signing & Capabilities**.
4. Set **Team** to your own Apple ID (Add an Account… if it isn't listed).
5. Change **Bundle Identifier** to something unique, for example `com.yourname.FreshSnap`.
6. Plug in your iPhone, choose it at the top of the Xcode window, and press **Run** (▶).
7. If the iPhone asks, turn on **Developer Mode** (Settings → Privacy & Security), and trust your Apple ID under Settings → General → VPN & Device Management.
8. Sign up with any email and a password of at least 6 characters.

## Notes

- **Internet:** needed for logging in, barcode lookups, new recipes and AI. The fridge, use-by estimates, receipt reading, favourites and recently viewed recipes work offline.
- **AI features:** these are protected by Firebase App Check, which only accepts the developer's registered device. On other builds the AI shows "couldn't be reached" and the app falls back to its built-in receipt dictionary. Everything else works as normal.
- **Free Apple ID:** apps installed this way stop opening after 7 days. Press Run in Xcode again to reinstall.

## Data and credits

- Product and nutrition data from [Open Food Facts](https://world.openfoodfacts.org), available under the Open Database Licence (ODbL)
- Food storage times from the [USDA FSIS FoodKeeper](https://catalog.data.gov/dataset/fsis-foodkeeper-data) data (CC0)
- Recipes from [TheMealDB](https://www.themealdb.com)
- AI features use Google Gemini through Firebase AI Logic
