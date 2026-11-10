//
//  ScanView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import SwiftUI
import VisionKit
import AVFoundation
 
// FreshSnap – Week 6, Steps 1 to 5
// The Scan tab: live camera with Receipt, Label and Barcode modes.
// Receipt -> Vision + abbreviation dictionary (+ AI fallback) -> Review scan (many items)
// Label   -> use-by date reader                -> Review scan
// Barcode -> Open Food Facts                   -> Review scan
 
enum ScanMode: String, CaseIterable, Identifiable {
    case receipt = "Receipt"
    case label = "Label"
    case barcode = "Barcode"
 
    var id: Self { self }
 
    var hint: String {
        switch self {
        case .receipt: return "Hold your phone about 20–30 cm away so the whole item list fits, keep steady, then tap Scan."
        case .label: return "Hold your phone about 15 cm from the use-by date, then tap Scan."
        case .barcode: return "Hold your phone about 15 cm from the barcode, then tap Scan."
        }
    }
}
 
// One scanned product waiting to be checked on the Review scan screen.
struct ReviewDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var category = "Other"
    var expiryDate: Date?
    var note: String?
    var nutrition: Nutrition?
}
 
// A scanned receipt waiting to be checked.
struct ReceiptDraft: Identifiable {
    let id = UUID()
    let items: [ReceiptItem]
    var aiFailed = false
}
 
struct ScanView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.openURL) private var openURL
 
    @State private var mode: ScanMode = .receipt
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scanner = ScannerModel()
 
    @State private var review: ReviewDraft?
    @State private var receiptReview: ReceiptDraft?
    @State private var busyMessage: String?
 
    @State private var showingNothingFound = false
    @State private var showingNoDate = false
    @State private var showingNoItems = false
    @State private var showingAddFood = false
    @State private var showingDistanceTip = false
 
    var body: some View {
        NavigationStack {
            Group {
                if !DataScannerViewController.isSupported {
                    ContentUnavailableView(
                        "Scanning isn't supported on this device",
                        systemImage: "camera.badge.ellipsis",
                        description: Text("You can still add food by hand from the Fridge.")
                    )
                } else {
                    switch cameraStatus {
                    case .authorized:
                        scannerScreen
                    case .notDetermined:
                        ProgressView()
                            .task { await requestCamera() }
                    default:
                        cameraOff
                    }
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .profileButton()
            .onAppear {
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
            .sheet(isPresented: $showingAddFood) {
                AddProductView(ownerID: auth.userID)
            }
            // Label and barcode: review one item
            .sheet(item: $review) { draft in
                AddProductView(
                    ownerID: auth.userID,
                    title: "Review scan",
                    note: draft.note,
                    name: draft.name,
                    expiryDate: draft.expiryDate,
                    amount: draft.amount,
                    category: draft.category,
                    nutrition: draft.nutrition
                )
            }
            // Receipt: review every item
            .sheet(item: $receiptReview) { draft in
                ReceiptReviewView(ownerID: auth.userID, items: draft.items, aiFailed: draft.aiFailed)
            }
            .alert("No date found", isPresented: $showingNoDate) {
                Button("Try again", role: .cancel) {}
                Button("Add by hand") { showingAddFood = true }
            } message: {
                Text("Make sure the use-by date is in view and clear, or add the food by hand.")
            }
            .alert("No food found on the receipt", isPresented: $showingNoItems) {
                Button("Try again", role: .cancel) {}
                Button("Add by hand") { showingAddFood = true }
            } message: {
                Text("Lay the receipt flat in good light and fit the item list in view. Very faded receipts may not scan.")
            }
            // "Scan readable?" – No: ask them to try again
            .alert("Nothing found", isPresented: $showingNothingFound) {
                Button("Try again", role: .cancel) {}
            } message: {
                Text("Move closer, hold the phone steady and make sure there's enough light.")
            }
        }
    }
 
    // MARK: Camera allowed
 
    private var scannerScreen: some View {
        VStack(spacing: 12) {
            Picker("Scan mode", selection: $mode) {
                ForEach(ScanMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
 
            ZStack(alignment: .bottom) {
                LiveScanner(mode: mode, model: scanner)
                    .id(mode)   // a fresh scanner for each mode
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    // Tester feedback: people held the phone too close.
                    // The tip only appears when nothing has been recognised for a while.
                    .overlay(alignment: .top) {
                        if showingDistanceTip {
                            Label("Blurry? Move your phone further away", systemImage: "arrow.up.backward.and.arrow.down.forward")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: Capsule())
                                .padding(.top, 12)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
 
                if let busyMessage {
                    ProgressView(busyMessage)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .frame(maxHeight: .infinity)
                }
 
                Button {
                    capture()
                } label: {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Scan \(mode.rawValue.lowercased())")
                .accessibilityHint(mode.hint)
                .disabled(busyMessage != nil)
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
 
            Text(mode.hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        // If the camera sees nothing for 4 seconds, show the tip for 4 seconds,
        // then wait at least 6 seconds before it can appear again.
        .task(id: mode) {
            showingDistanceTip = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard scanner.items.isEmpty else { continue }
 
                withAnimation { showingDistanceTip = true }
                try? await Task.sleep(for: .seconds(4))
                withAnimation { showingDistanceTip = false }
 
                try? await Task.sleep(for: .seconds(6))   // don't nag straight away
            }
        }
        // Hide it as soon as something is recognised
        .onChange(of: scanner.items.isEmpty) { _, isEmpty in
            if !isEmpty {
                withAnimation { showingDistanceTip = false }
            }
        }
    }
 
    // MARK: Camera refused ("Camera off" in the app map)
 
    private var cameraOff: some View {
        ContentUnavailableView {
            Label("Camera is off", systemImage: "camera.slash")
        } description: {
            Text("FreshSnap needs the camera to scan receipts, use-by dates and barcodes. Turn it on in your iPhone's Settings, or add food by hand.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
 
            Button("Add food by hand") {
                showingAddFood = true
            }
        }
    }
 
    // MARK: Actions
 
    private func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = granted ? .authorized : .denied
    }
 
    private func capture() {
        let lines = scanner.readLines(for: mode)
        guard !lines.isEmpty else {
            showingNothingFound = true
            // Show the tip briefly after a failed scan
            withAnimation { showingDistanceTip = true }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation { showingDistanceTip = false }
            }
            return
        }
 
        switch mode {
        case .receipt:
            Task { await readReceipt(fallbackLines: lines) }
        case .label:
            readLabel(lines)
        case .barcode:
            if let barcode = lines.first {
                Task { await lookUp(barcode: barcode) }
            }
        }
    }
 
    // Receipt -> full photo -> Vision -> abbreviation dictionary -> Review scan
    private func readReceipt(fallbackLines: [String]) async {
        busyMessage = "Reading receipt…"
 
        var rows: [String] = []
        if let photo = await scanner.capturePhoto() {
            rows = await ReceiptReader.readRows(from: photo)
        }
        if rows.isEmpty {
            rows = fallbackLines   // use what the live camera could see
        }
 
        var items = ReceiptParser.items(from: rows)
        var aiFailed = false
 
        // AI fallback (can be switched off in Preferences)
        if AppSettings.useAI && !items.isEmpty {
            busyMessage = "Improving names with AI…"
            let result = await ReceiptAI.improve(items)
            items = result.items
            aiFailed = result.outcome == .failed
        }
        busyMessage = nil
 
        if items.isEmpty {
            showingNoItems = true
        } else {
            receiptReview = ReceiptDraft(items: items, aiFailed: aiFailed)
        }
    }
 
    // Label -> find the date -> Review scan
    private func readLabel(_ lines: [String]) {
        guard let found = LabelDateReader.findDate(in: lines) else {
            showingNoDate = true
            return
        }
 
        let dateText = found.date.formatted(.dateTime.day().month(.wide).year())
        let note: String
        switch found.kind {
        case .useBy:
            note = "Found a use-by date: \(dateText). Type the product name and check the details."
        case .bestBefore:
            note = "Found a best-before date: \(dateText). Best before is about quality, so food may still be fine after it, unlike use-by, which is about safety. Type the product name and check the details."
        case .unlabelled:
            note = "Found the date \(dateText), but couldn't tell if it's use-by or best-before. Check the pack and type the product name."
        }
 
        review = ReviewDraft(expiryDate: found.date, note: note)
    }
 
    // Barcode -> Open Food Facts -> Review scan
    private func lookUp(barcode: String) async {
        busyMessage = "Looking up product…"
        let product = await OpenFoodFacts.lookUp(barcode: barcode)
        busyMessage = nil
 
        if let product {
            let estimate = ShelfLife.estimate(forName: product.name, category: product.category)
            review = ReviewDraft(
                name: product.name,
                amount: product.quantity,
                category: product.category,
                expiryDate: estimate.date,
                note: "Found on Open Food Facts. Barcodes don't include use-by dates, so the date is an estimate from \(estimate.source). Check the pack and change it if needed.",
                nutrition: product.nutrition
            )
        } else {
            review = ReviewDraft(
                note: "We couldn't find barcode \(barcode) on Open Food Facts, or there's no internet connection. Add the details yourself."
            )
        }
    }
}
 
// MARK: - What the scanner can currently see
 
@MainActor
@Observable
final class ScannerModel {
    var items: [RecognizedItem] = []
    @ObservationIgnored weak var scanner: DataScannerViewController?
 
    // Text top to bottom (receipt, label) or barcode numbers.
    func readLines(for mode: ScanMode) -> [String] {
        let sorted = items.sorted {
            if abs($0.bounds.topLeft.y - $1.bounds.topLeft.y) > 10 {
                return $0.bounds.topLeft.y < $1.bounds.topLeft.y
            }
            return $0.bounds.topLeft.x < $1.bounds.topLeft.x
        }
 
        return sorted.compactMap { item in
            switch item {
            case .text(let text):
                return mode == .barcode ? nil : text.transcript
            case .barcode(let barcode):
                return mode == .barcode ? barcode.payloadStringValue : nil
            @unknown default:
                return nil
            }
        }
    }
 
    // A full-resolution photo for reading whole receipts.
    func capturePhoto() async -> UIImage? {
        guard let scanner else { return nil }
        return try? await scanner.capturePhoto()
    }
}
 
// MARK: - VisionKit's live scanner, wrapped for SwiftUI
 
struct LiveScanner: UIViewControllerRepresentable {
    let mode: ScanMode
    let model: ScannerModel
 
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let dataTypes: Set<DataScannerViewController.RecognizedDataType> =
            mode == .barcode ? [.barcode()] : [.text()]
 
        let scanner = DataScannerViewController(
            recognizedDataTypes: dataTypes,
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        model.scanner = scanner
        return scanner
    }
 
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }
 
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()   // turns the camera off when leaving the tab (saves battery)
    }
 
    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }
 
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let model: ScannerModel
 
        init(model: ScannerModel) {
            self.model = model
        }
 
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            model.items = allItems
        }
 
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            model.items = allItems
        }
 
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            model.items = allItems
        }
    }
}
