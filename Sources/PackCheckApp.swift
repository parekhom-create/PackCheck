import AVFoundation
import NaturalLanguage
import SwiftUI
import Translation
import UIKit
import Vision
import VisionKit

@main
struct PackCheckApp: App {
    var body: some Scene {
        WindowGroup { CheckView() }
    }
}

struct CheckView: View {
    @AppStorage("avoidEgg") private var avoidEgg = true
    @AppStorage("customTerms") private var customTerms = ""
    @State private var barcode = ""
    @State private var label = ""
    @State private var needsTranslation = false
    @State private var englishLabel = ""
    @State private var translatedSource: String?
    @State private var unclearPhotoText = false
    @State private var product: Product?
    @State private var lookupMessage = ""
    @State private var lookingUp = false
    @State private var cameraMessage = ""
    @State private var scanningBarcode = false
    @State private var photographing = false
    @State private var lookupTask: Task<Void, Never>?
    @State private var readingPhoto = false
    @State private var showingPreferences = false
    @FocusState private var editingLabel: Bool
    @FocusState private var editingEnglish: Bool

    private var reviewText: String {
        if !needsTranslation { return label }
        return translatedSource == label ? englishLabel : ""
    }

    private var result: IngredientCheck.Result {
        if readingPhoto {
            return .unsure("Waiting for the text from the photograph.")
        }
        if needsTranslation && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .unsure("Add an English translation of the ingredients and warnings.")
        }
        let check = IngredientCheck.evaluate(label: reviewText, confirmed: !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                 terms: IngredientCheck.terms(avoidEgg: avoidEgg, custom: customTerms),
                                 online: product)
        if check == .noMatch && unclearPhotoText {
            return .unsure("Some photographed text was unclear. Compare it with the pack and correct any missing ingredients or warnings.")
        }
        if check == .noMatch && lookingUp {
            return .unsure("Waiting for the online ingredient listing.")
        }
        return check
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Know your food.")
                                .font(.largeTitle.bold())
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }

                    VStack(spacing: 12) {
                        Button {
                            cameraMessage = ""
                            if UIImagePickerController.isSourceTypeAvailable(.camera) &&
                                [.authorized, .notDetermined].contains(AVCaptureDevice.authorizationStatus(for: .video)) {
                                photographing = true
                            } else {
                                cameraMessage = "Camera unavailable. Check camera access in Settings or enter label text below."
                            }
                        }
                        label: {
                            Label("Scan food label", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.large)
                        .disabled(readingPhoto)
                        Button { openBarcodeScanner() } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 18) {
                        Text("Ingredients on the pack")
                            .font(.subheadline.weight(.semibold))
                        if readingPhoto { ProgressView("Reading photograph…") }
                        if !cameraMessage.isEmpty { Text(cameraMessage).foregroundStyle(.secondary) }
                        TextField("Type or paste ingredients and warnings", text: $label, axis: .vertical)
                            .lineLimit(3...8)
                            .padding(12)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Original ingredients and warnings")
                            .focused($editingLabel)
                            .autocorrectionDisabled()
                            .onChange(of: label) { _, _ in resetTranslation() }
                        Toggle(isOn: $needsTranslation) {
                            Label("Translate to English", systemImage: "character.bubble.fill")
                                .foregroundStyle(.purple)
                        }
                        if needsTranslation { translationControls }
                        Text("Results update automatically. Include all ingredients and “may contain” warnings, and correct any text the camera misreads.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                    } label: {
                        Label("Read the label", systemImage: "text.viewfinder")
                            .font(.title2.bold())
                            .foregroundStyle(.indigo)
                    }

                    if !label.isEmpty {
                        GroupBox("Your result") {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(result.title, systemImage: resultIcon)
                                    .font(.title3.bold())
                                    .foregroundStyle(resultColor)
                                    .accessibilityAddTraits(.isHeader)
                                Text(result.detail)
                                Text("Use the original packaging and manufacturer information for allergy decisions.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                        }
                        .background(resultColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(resultBorderColor, lineWidth: 3)
                                .allowsHitTesting(false)
                        }
                        .id("result")
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                        TextField("Enter barcode digits", text: $barcode)
                            .keyboardType(.numberPad)
                            .onChange(of: barcode) { _, _ in
                                lookupTask?.cancel()
                                product = nil
                                lookingUp = false
                                lookupMessage = ""
                            }
                        Button("Look up barcode", systemImage: "magnifyingglass") { lookup(barcode) }
                        if !lookupMessage.isEmpty { Text(lookupMessage).foregroundStyle(.secondary) }
                        }
                        .padding(.top, 12)
                    }

                    if let product {
                        GroupBox("Online listing") {
                            Text(product.name ?? "Product name unavailable").font(.headline)
                            if let brand = product.brand { Text(brand) }
                            Text(product.ingredients ?? "English ingredient list unavailable.")
                            if let tags = product.allergens, !tags.isEmpty { LabeledContent("Allergen tags", value: tags) }
                            if let tags = product.traces, !tags.isEmpty { LabeledContent("Trace tags", value: tags) }
                            if let page = URL(string: "https://world.openfoodfacts.org/product/\(barcode)") {
                                Link("View on Open Food Facts", destination: page)
                            }
                        }
                    }

                    Section {
                        Button("Clear product and label", role: .destructive) {
                            lookupTask?.cancel()
                            lookingUp = false
                            barcode = ""
                            product = nil
                            lookupMessage = ""
                            cameraMessage = ""
                            label = ""
                            unclearPhotoText = false
                            needsTranslation = false
                            resetTranslation()
                        }
                        .disabled(readingPhoto)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                showingPreferences = true
                            } label: {
                                HStack {
                                    Label("Your food preferences", systemImage: "slider.horizontal.3")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .font(.subheadline)
                            Text(IngredientCheck.terms(avoidEgg: avoidEgg, custom: customTerms)
                                .joined(separator: ", ").isEmpty
                                 ? "Choose ingredients you want to avoid"
                                 : "Avoiding " + IngredientCheck.terms(avoidEgg: avoidEgg, custom: customTerms).joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    }
                    .padding(20)
                }
                .background {
                    LinearGradient(
                        colors: [.purple.opacity(0.18), .pink.opacity(0.13), .orange.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                .onChange(of: readingPhoto) { _, reading in
                    if !reading && !label.isEmpty {
                        withAnimation { scroll.scrollTo("result", anchor: .top) }
                    }
                }
                .onChange(of: englishLabel) { _, translated in
                    if !translated.isEmpty && !editingEnglish {
                        withAnimation { scroll.scrollTo("result", anchor: .top) }
                    }
                }
            }
            .navigationTitle("PackCheck")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color(red: 0.08, green: 0.42, blue: 0.38))
            .sheet(isPresented: $showingPreferences) {
                NavigationStack {
                    Form {
                        Section {
                            Toggle("Eggs", isOn: $avoidEgg)
                            TextField("Add ingredients, separated by commas", text: $customTerms, axis: .vertical)
                                .autocorrectionDisabled()
                        } header: {
                            Text("Ingredients to avoid")
                        } footer: {
                            Text("Checks match these English ingredient names. Include alternative names you want to flag.")
                        }
                    }
                    .navigationTitle("Food preferences")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPreferences = false }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $scanningBarcode) {
                NavigationStack {
                    BarcodeScanner { value in
                        scanningBarcode = false
                        if let value {
                            barcode = value
                        }
                        else { lookupMessage = "Scanner unavailable. Enter the barcode digits manually." }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Scan barcode")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { scanningBarcode = false }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $photographing) {
                LabelCamera { photo in
                    photographing = false
                    if let photo { readLabel(photo) }
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var translationControls: some View {
        if #available(iOS 18.0, *) {
            LabelTranslator(source: label) { original, translated in
                guard original == label, needsTranslation else { return }
                translatedSource = original
                englishLabel = translated
            }
            .id(label)
        } else {
            Text("Automatic translation requires iOS 18 or later. You can enter the English text below.")
                .foregroundStyle(.secondary)
        }

        TextField("Review or enter the English translation", text: Binding(
            get: { reviewText },
            set: { value in
                translatedSource = label
                englishLabel = value
            }
        ), axis: .vertical)
        .lineLimit(3...8)
        .focused($editingEnglish)
        .autocorrectionDisabled()
        .accessibilityLabel("English ingredients and warnings")
        .disabled(readingPhoto || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func resetTranslation() {
        translatedSource = nil
        englishLabel = ""
    }

    private var resultBorderColor: Color {
        switch result {
        case .contains: return .red
        case .trace: return .orange
        default: return .clear
        }
    }

    private var resultColor: Color {
        switch result {
        case .contains: return .red
        case .trace: return .orange
        case .unsure: return .primary
        case .noMatch: return .blue
        }
    }

    private var resultIcon: String {
        switch result {
        case .contains: return "exclamationmark.circle"
        case .trace, .unsure: return "exclamationmark.triangle"
        case .noMatch: return "magnifyingglass"
        }
    }

    private func openBarcodeScanner() {
        Task { @MainActor in
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                scanningBarcode = true
            } else {
                lookupMessage = "Scanner unavailable. Enter the barcode digits manually."
            }
        }
    }

    private func lookup(_ input: String) {
        lookupTask?.cancel()
        product = nil
        lookingUp = false
        guard let code = ProductLookup.barcode(input) else {
            lookupMessage = "Enter a valid barcode, including the final digit."
            return
        }

        lookingUp = true
        lookupMessage = "Looking up the product…"
        lookupTask = Task { @MainActor in
            do {
                let found = try await ProductLookup.find(code)
                guard !Task.isCancelled else { return }
                lookingUp = false
                product = found
                lookupMessage = found == nil ? "No matching product found. You can still check the pack." : "Product found. Check the name and flavour against the pack."
            } catch {
                guard !Task.isCancelled else { return }
                lookingUp = false
                lookupMessage = "Online lookup failed. Try again or check the pack."
            }
        }
    }

    private func readLabel(_ photo: UIImage) {
        readingPhoto = true
        // Drawing normalizes the camera image orientation before passing it to Vision.
        let image = UIGraphicsImageRenderer(size: photo.size).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: photo.size))
        }
        guard let pixels = image.cgImage else {
            readingPhoto = false
            cameraMessage = "Could not open the photograph."
            return
        }

        Task { @MainActor in
            defer { readingPhoto = false }
            do {
                let recognized = try await Task.detached(priority: .userInitiated) {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.automaticallyDetectsLanguage = true
                    // Preserve printed ingredient names and abbreviations.
                    request.usesLanguageCorrection = false
                    try VNImageRequestHandler(cgImage: pixels).perform([request])
                    let observations = (request.results ?? []).sorted { first, second in
                        let rowDistance = first.boundingBox.midY - second.boundingBox.midY
                        let tolerance = min(first.boundingBox.height, second.boundingBox.height) / 2
                        if abs(rowDistance) > tolerance { return rowDistance > 0 }
                        return first.boundingBox.minX < second.boundingBox.minX
                    }
                    let candidates = observations.compactMap { $0.topCandidates(1).first }
                    return (
                        text: candidates.map(\.string).joined(separator: "\n"),
                        uncertain: candidates.contains { $0.confidence < 0.8 }
                    )
                }.value
                guard !recognized.text.isEmpty else {
                    cameraMessage = "No text found. Retake the photo in good light or type the ingredients."
                    return
                }
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(recognized.text)
                if let best = recognizer.languageHypotheses(withMaximum: 1).first,
                   best.key != .english, best.value >= 0.7 {
                    needsTranslation = true
                }
                resetTranslation()
                unclearPhotoText = recognized.uncertain
                label = recognized.text
                cameraMessage = recognized.uncertain
                    ? "Some text was unclear. Review the ingredients and warnings, or retake the photo closer in good light."
                    : "Text captured. Check all ingredients and warnings against the pack."
            } catch {
                cameraMessage = "Could not read the photograph. Retake it or type the label."
            }
        }
    }
}

@available(iOS 18.0, *)
private struct LabelTranslator: View {
    let source: String
    let onTranslation: (String, String) -> Void
    @State private var configuration: TranslationSession.Configuration?
    @State private var working = false
    @State private var message = ""

    var body: some View {
        Button("Translate again", systemImage: "arrow.clockwise") {
            beginTranslation()
        }
        .disabled(working || source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .task(id: source) {
            guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            do { try await Task.sleep(for: .milliseconds(700)) }
            catch { return }
            beginTranslation()
        }
        .translationTask(configuration) { session in
            await translate(using: session)
        }

        if working { ProgressView("Translating label…") }
        if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
    }

    private func beginTranslation() {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(source)
        if let englishConfidence = recognizer.languageHypotheses(withMaximum: 3)[.english],
           englishConfidence > 0.9 {
            onTranslation(source, source)
            message = "This text appears to be English. Review it below."
            return
        }
        working = true
        message = ""
        if configuration != nil {
            configuration?.invalidate()
        } else {
            configuration = .init(source: nil, target: Locale.Language(identifier: "en"))
        }
    }

    @MainActor
    private func translate(using session: TranslationSession) async {
        defer { working = false }
        do {
            try await session.prepareTranslation()
            let response = try await session.translate(source)
            guard !Task.isCancelled else { return }
            let english = response.targetText
            guard !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                message = "No translation returned. Enter the English text below."
                return
            }
            onTranslation(source, english)
            message = "Review the English ingredients and warnings below."
        } catch {
            guard !Task.isCancelled else { return }
            message = "Translation unavailable. Check the language download or enter the English text below."
        }
    }
}

private struct BarcodeScanner: UIViewControllerRepresentable {
    let onResult: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .itf14, .upce])],
            isGuidanceEnabled: true, isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        let coordinator = context.coordinator
        Task { @MainActor in
            do { try scanner.startScanning() }
            catch { coordinator.finish(nil) }
        }
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onResult: (String?) -> Void
        private var completed = false

        init(onResult: @escaping (String?) -> Void) { self.onResult = onResult }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue,
                   let valid = ProductLookup.barcode(value) {
                    scanner.stopScanning()
                    finish(valid)
                    return
                }
            }
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            finish(nil)
        }

        func finish(_ value: String?) {
            guard !completed else { return }
            completed = true
            onResult(value)
        }
    }
}

private struct LabelCamera: UIViewControllerRepresentable {
    let onPhoto: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPhoto: onPhoto) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPhoto: (UIImage?) -> Void

        init(onPhoto: @escaping (UIImage?) -> Void) { self.onPhoto = onPhoto }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPhoto(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPhoto(nil)
        }
    }
}
