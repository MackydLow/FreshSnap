//
//  ScanView.swift
//  FreshSnap
//
//  Created by Mackenzie Low on 30/10/2026.
//

import SwiftUI
import VisionKit
import AVFoundation
 
// FreshSnap – Week 6, Step 1
// The Scan tab: live camera with Receipt, Label and Barcode modes.
// For now it shows what it read; Steps 2–4 turn this into food for the fridge.
 
enum ScanMode: String, CaseIterable, Identifiable {
    case receipt = "Receipt"
    case label = "Label"
    case barcode = "Barcode"
 
    var id: Self { self }
 
    var hint: String {
        switch self {
        case .receipt: return "Fit the receipt's item list in view, then tap Scan."
        case .label: return "Point at the use-by date, then tap Scan."
        case .barcode: return "Point at the barcode, then tap Scan."
        }
    }
}
 
// What the camera read, shown in a sheet.
struct ScanResult: Identifiable {
    let id = UUID()
    let mode: ScanMode
    let lines: [String]
}
 
struct ScanView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.openURL) private var openURL
 
    @State private var mode: ScanMode = .receipt
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scanner = ScannerModel()
    @State private var result: ScanResult?
    @State private var showingNothingFound = false
    @State private var showingAddFood = false
 
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
            .sheet(item: $result) { result in
                ScanResultView(result: result)
            }
            .sheet(isPresented: $showingAddFood) {
                AddProductView(ownerID: auth.userID)
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
 
                Button {
                    capture()
                } label: {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Scan")
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
    }
 
    // MARK: Camera refused ("Camera off" in the app map)
 
    private var cameraOff: some View {
        ContentUnavailableView {
            Label("Camera is off", systemImage: "camera.slash")
        } description: {
            Text("FreshSnap needs the camera to scan receipts, use-by dates and barcodes. Turn it on in Settings, or add food by hand.")
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
        if lines.isEmpty {
            showingNothingFound = true
        } else {
            result = ScanResult(mode: mode, lines: lines)
        }
    }
}
 
// MARK: - What the scanner can currently see
 
@MainActor
@Observable
final class ScannerModel {
    var items: [RecognizedItem] = []
 
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
 
// MARK: - Temporary result screen (replaced by Review scan in Steps 2–4)
 
struct ScanResultView: View {
    let result: ScanResult
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        NavigationStack {
            List(result.lines, id: \.self) { line in
                Text(line)
            }
            .navigationTitle("\(result.mode.rawValue) scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
 
