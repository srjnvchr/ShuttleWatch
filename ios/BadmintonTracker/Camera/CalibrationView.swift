import SwiftUI
import TrackingKit

/// FR-13: drag four handles onto the court's corners over the live preview.
/// With the phone on a tripod, this only needs doing once per session.
struct CalibrationView: View {
    enum SizeChoice: String, CaseIterable, Identifiable {
        case doubles = "Doubles"
        case singles = "Singles"
        case custom = "Custom"

        var id: Self { self }
    }

    let imageAspect: CGFloat
    let onSave: (CourtCalibration) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    @State private var corners: [CGPoint]
    @State private var choice: SizeChoice
    @State private var customWidth: Double
    @State private var customLength: Double
    /// Where a handle was when its drag began, so it moves with the finger from wherever it was grabbed.
    @State private var dragStart: CGPoint?

    init(
        existing: CourtCalibration?,
        imageAspect: CGFloat,
        onSave: @escaping (CourtCalibration) -> Void,
        onClear: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.imageAspect = imageAspect
        self.onSave = onSave
        self.onClear = onClear
        self.onCancel = onCancel
        let usable = existing.flatMap { $0.fits(imageAspect: imageAspect) ? $0 : nil }
        _corners = State(initialValue: usable?.imageCorners ?? CourtCalibration.startingCorners())
        let size = usable?.courtSize ?? CourtCalibration.doublesSize
        _choice = State(initialValue: size == CourtCalibration.doublesSize ? .doubles : size == CourtCalibration.singlesSize ? .singles : .custom)
        _customWidth = State(initialValue: Double(size.width))
        _customLength = State(initialValue: Double(size.height))
    }

    private var courtSize: CGSize {
        switch choice {
        case .doubles: CourtCalibration.doublesSize
        case .singles: CourtCalibration.singlesSize
        case .custom: CGSize(width: customWidth, height: customLength)
        }
    }

    private var calibration: CourtCalibration {
        CourtCalibration(imageCorners: corners, courtSize: courtSize, imageAspect: imageAspect)
    }

    var body: some View {
        GeometryReader { geometry in
            let mapper = AspectFillMapper(viewSize: geometry.size, imageAspect: imageAspect)
            ZStack {
                Path { path in
                    path.addLines(corners.map(mapper.viewPoint))
                    path.closeSubpath()
                }
                .stroke(calibration.isValid ? Color.green : Color.red, lineWidth: 3)

                ForEach(CourtCalibration.Corner.allCases, id: \.rawValue) { corner in
                    handle(corner, mapper: mapper)
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            Text("Drag each handle onto a court corner. Grab a handle beside its centre so your finger does not hide the corner.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(10)
                .background(.black.opacity(0.6), in: .rect(cornerRadius: 10))
                .foregroundStyle(.white)
                .padding()
        }
        .overlay(alignment: .bottom) {
            controls
        }
    }

    private func handle(_ corner: CourtCalibration.Corner, mapper: AspectFillMapper) -> some View {
        let index = corner.rawValue
        let point = mapper.viewPoint(corners[index])
        return ZStack {
            Circle()
                .stroke(.white, lineWidth: 2)
                .background(Circle().fill(.black.opacity(0.15)))
                .frame(width: 56, height: 56)
            // The exact corner is the crosshair's centre.
            Path { path in
                path.move(to: CGPoint(x: 28, y: 14)); path.addLine(to: CGPoint(x: 28, y: 42))
                path.move(to: CGPoint(x: 14, y: 28)); path.addLine(to: CGPoint(x: 42, y: 28))
            }
            .stroke(.yellow, lineWidth: 1.5)
            .frame(width: 56, height: 56)
            Text(corner.name)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.6), in: .capsule)
                .foregroundStyle(.white)
                .offset(y: -42)
        }
        .position(point)
        .gesture(
            DragGesture()
                .onChanged { drag in
                    let start = dragStart ?? corners[index]
                    dragStart = start
                    let moved = CGPoint(
                        x: start.x + drag.translation.width / mapper.imageWidth,
                        y: start.y + drag.translation.height / mapper.imageHeight
                    )
                    corners[index] = CGPoint(x: min(max(moved.x, 0), 1), y: min(max(moved.y, 0), 1))
                }
                .onEnded { _ in dragStart = nil }
        )
        .accessibilityLabel("\(corner.name) corner")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Court", selection: $choice) {
                ForEach(SizeChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if choice == .custom {
                HStack {
                    measurement("Across", value: $customWidth)
                    measurement("Towards you", value: $customLength)
                }
                Text("Measure the rectangle you marked, such as a rug, in metres.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Clear", role: .destructive, action: onClear)
                Spacer()
                Button("Save") { onSave(calibration) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!calibration.isValid)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding()
    }

    private func measurement(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("m")
        }
    }
}
