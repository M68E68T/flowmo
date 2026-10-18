import AppKit
import SwiftUI
import FlostedCore

struct ImageEditor: View {
    let file: URL
    let image: CGImage
    let action: FileAction
    let completed: (URL) -> Void
    let cancel: () -> Void
    @State private var selection = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var ratio = 0.0
    @State private var padding = 80.0
    @State private var radius = 28.0
    @State private var shadow = 24.0
    @State private var gradient = true
    @State private var first = Color(red: 1, green: 0.45, blue: 0.16)
    @State private var second = Color(red: 0.97, green: 0.19, blue: 0.29)
    @State private var aspect = 0.0
    @State private var selectedPreset = 0
    @State private var third: RGB? = RGB(0.35, 0.22, 0.86)
    @State private var backdrop: CGImage?
    @State private var backdropVersion = 0
    @State private var quality = 0.80
    @State private var scale = 1.0
    @State private var targetKB = 0
    @State private var preview: NSImage?
    @State private var compressedBytes = 0
    @State private var saving = false
    @State private var errorMessage: String?
    private let accent = ReferenceStyle.accent
    private var ratios: [(String, Double)] {
        [(tr("editor.ratioFree"), 0), ("1:1", 1), ("16:9", 16/9), ("9:16", 9/16), ("4:3", 4/3), ("3:4", 3/4)]
    }
    private let presets: [(RGB, RGB)] = [
        (RGB(1,0.45,0.16), RGB(0.97,0.19,0.29)), (RGB(0.14,0.61,0.98), RGB(0.36,0.20,0.80)),
        (RGB(0.99,0.65,0.78), RGB(0.70,0.34,0.94)), (RGB(0.26,0.79,0.64), RGB(0.06,0.38,0.33)),
        (RGB(0.82,0.69,0.96), RGB(0.99,0.82,0.83)), (RGB(0.12,0.47,0.34), RGB(0.93,0.45,0.52)),
        (RGB(0.15,0.67,0.97), RGB(0.30,0.32,0.88)), (RGB(0.20,0.73,0.85), RGB(0.35,0.48,0.79)),
        (RGB(0.70,0.80,0.97), RGB(1,1,1))]
    private let solids = [RGB(1,1,1),RGB(0.99,0.79,0.14),RGB(0.65,0.83,0.14),RGB(0.15,0.57,0.31),RGB(0.05,0.57,0.54),RGB(0.15,0.67,0.77),RGB(0.14,0.27,0.81),RGB(0.08,0.11,0.17),RGB(0.38,0.18,0.66)]

    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                ReferenceHeader(title: tr(action == .crop ? "editor.crop" : action == .background ? "editor.background" : "editor.compress"), close: cancel)
                ZStack {
                    if action == .crop {
                        CropCanvas(image: image, selection: $selection, ratio: ratio).padding(22)
                    } else if let preview {
                        Image(nsImage: preview).resizable().interpolation(.high).scaledToFit().padding(action == .background ? 12 : 22)
                    } else { ProgressView().controlSize(.small) }
                }
                .frame(maxWidth: .infinity,minHeight:340,maxHeight: .infinity)
                .background(action == .background ? Color.black.opacity(0.035) : .clear,in:RoundedRectangle(cornerRadius:9))
                .padding(.horizontal,action == .background ? 12 : 0)
                .padding(.top,action == .background ? 10 : 0)
                VStack(alignment:.leading,spacing:12) {
                    if action == .crop { cropControls }
                    else if action == .background { backgroundControls }
                    else { compressionControls }
                }.padding(.horizontal,16).padding(.vertical,15)
                HStack {
                    Button("editor.reset",action:reset).buttonStyle(ReferenceActionButton()).help(Text("help.resetEditor"))
                    Spacer()
                    if saving { ProgressView().controlSize(.small) }
                    Button(tr(action == .background ? "editor.saveWithBackground" : action == .crop ? "editor.apply" : "editor.save"),action:save)
                        .buttonStyle(ReferenceActionButton(primary:true)).keyboardShortcut(.defaultAction)
                        .help(Text("help.saveEditor"))
                }.padding(13).disabled(saving)
                    .overlay(alignment:.top) { Rectangle().fill(.black.opacity(0.075)).frame(height:0.6) }
            }
        }.frame(width:action == .background ? 440:420,height:action == .background ? 660:640)
        .task(id: previewKey) { await updatePreview() }
        .alert(Text("editor.saveFailed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing:8) {
                Text("editor.aspectRatio").font(.system(size:11)).fixedSize()
                ReferenceSegments(values:ratios,selection:$ratio).onChange(of:ratio) { resetSelection(ratio:$0) }
            }.help(Text("help.aspectRatio"))
            HStack(spacing:7) {
                Text("editor.widthShort").font(.system(size:11))
                TextField("editor.width",value:Binding(get:{ Int(selection.width*Double(image.width)) },set:{ resizeCrop(width:$0,height:nil) }),format:.number)
                    .labelsHidden().textFieldStyle(.plain).padding(.horizontal,7).frame(width:60,height:23).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:5))
                Text("editor.heightShort").font(.system(size:11))
                TextField("editor.height",value:Binding(get:{ Int(selection.height*Double(image.height)) },set:{ resizeCrop(width:nil,height:$0) }),format:.number)
                    .labelsHidden().textFieldStyle(.plain).padding(.horizontal,7).frame(width:60,height:23).background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:5))
                Text("px").font(.system(size:10)).foregroundStyle(.secondary)
                Spacer()
            }.help(Text("help.cropSize"))
        }
    }
    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment:.top,spacing:8) {
                Text("editor.backgroundLabel").font(.system(size:10)).frame(width:66,alignment:.leading).padding(.top,5)
                VStack(spacing:6) {
                    HStack(spacing:5) {
                ForEach(presets.indices, id: \.self) { index in
                    Button { applyPreset(index) } label: {
                        RoundedRectangle(cornerRadius:5).fill(LinearGradient(colors:[color(presets[index].0),color(presets[index].1)],startPoint:.topLeading,endPoint:.bottomTrailing))
                            .overlay { if index == 0 { RoundedRectangle(cornerRadius:5).fill(RadialGradient(colors:[.purple.opacity(0.8),.clear],center:.bottomTrailing,startRadius:0,endRadius:30)) } }
                            .frame(width:25,height:27).overlay(RoundedRectangle(cornerRadius:5).strokeBorder(selectedPreset == index ? accent : Color.white.opacity(0.35),lineWidth:selectedPreset == index ? 1.6 : 0.6))
                    }.buttonStyle(.plain).accessibilityLabel(Text(tr("editor.gradient", index + 1)))
                        .help(Text("help.presets"))
                }
                        // -2 marks a chosen backdrop; it gets the same ring as the presets.
                        Button(action:chooseBackdrop) {
                            Image(systemName:"photo.on.rectangle").font(.system(size:12)).frame(width:25,height:27)
                                .background(.black.opacity(0.07),in:RoundedRectangle(cornerRadius:5))
                                .overlay(RoundedRectangle(cornerRadius:5).strokeBorder(selectedPreset == -2 ? accent : Color.white.opacity(0.35),lineWidth:selectedPreset == -2 ? 1.6 : 0.6))
                        }
                            .buttonStyle(.plain).accessibilityLabel(Text("editor.chooseBackdrop"))
                            .help(Text("help.chooseBackdrop"))
                    }
                    HStack(spacing:5) {
                        ForEach(solids.indices,id:\.self) { index in
                            Button { first=color(solids[index]);gradient=false;third=nil;backdrop=nil;backdropVersion += 1;selectedPreset=100+index } label: {
                                RoundedRectangle(cornerRadius:5).fill(color(solids[index])).frame(width:25,height:25)
                                    .overlay(RoundedRectangle(cornerRadius:5).strokeBorder(selectedPreset == 100+index ? accent : Color.white.opacity(0.35),lineWidth:selectedPreset == 100+index ? 1.6 : 0.6))
                            }.buttonStyle(.plain).accessibilityLabel(Text(tr("editor.solidColor", index + 1)))
                                .help(Text("help.solids"))
                        }
                        ColorPicker("editor.customColor",selection:$first,supportsOpacity:false).labelsHidden().frame(width:25,height:25)
                            .overlay(RoundedRectangle(cornerRadius:5).strokeBorder(accent,lineWidth:selectedPreset == -1 ? 1.6 : 0).allowsHitTesting(false))
                            .onChange(of:first) { _ in if selectedPreset == -1 { gradient=false;third=nil;backdrop=nil } }
                            .simultaneousGesture(TapGesture().onEnded { selectedPreset = -1;gradient=false;third=nil;backdrop=nil;backdropVersion += 1 })
                            .help(Text("help.customColor"))
                    }
                }
            }
            slider("editor.padding",value:$padding,range:0...max(400,Double(max(image.width,image.height))*0.5),suffix:"px",help:"help.padding")
            slider("editor.corners",value:$radius,range:0...max(180,Double(min(image.width,image.height))*0.25),suffix:"px",help:"help.corners")
            slider("editor.shadow",value:$shadow,range:0...90,suffix:"px",help:"help.shadow")
            HStack(spacing:8) {
                Text("editor.ratio").font(.system(size:10)).frame(width:66,alignment:.leading)
                Spacer(minLength:0)
                ReferenceSegments(values:[(tr("editor.ratioAuto"),0),("1:1",1),("16:9",16/9),("4:5",4/5)],selection:$aspect).frame(width:190)
            }.help(Text("help.ratio"))
        }
    }
    private var compressionControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            slider("editor.quality", value: $quality, range: 0.05...1, suffix: "%", multiplier: 100, help: "help.quality")
            slider("editor.scale", value: $scale, range: 0.1...1, suffix: "%", multiplier: 100, help: "help.scale")
            Text("\(Int(Double(image.width) * scale)) × \(Int(Double(image.height) * scale)) px")
                .font(.system(size: 12, design: .monospaced))
            Text(tr("editor.estimatedSize", ByteCountFormatter.string(fromByteCount: Int64(compressedBytes), countStyle: .file)))
                .font(.subheadline)
            // Labelled like the sliders: with a value always present the field's
            // own placeholder never shows, which left it unexplained before.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("editor.targetSize").font(.system(size:10)).frame(width:66,alignment:.leading)
                    TextField("editor.targetSize", value: $targetKB, format: .number)
                        .labelsHidden().textFieldStyle(.plain).multilineTextAlignment(.trailing)
                        .padding(.horizontal,7).frame(width:70,height:23)
                        .background(.white.opacity(0.7),in:RoundedRectangle(cornerRadius:5))
                    Text(targetKB <= 0 ? tr("editor.targetSizeOff") : "KB")
                        .font(.system(size:10)).foregroundStyle(.secondary)
                    Spacer()
                }
                Text("editor.targetSizeHint").font(.system(size:9.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.help(Text("help.targetSize"))
        }
    }
    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>,
                        suffix: String, multiplier: Double = 1, help: LocalizedStringKey) -> some View {
        HStack(spacing:8) {
            Text(title).font(.system(size:10)).frame(width:66,alignment:.leading)
            Slider(value:value,in:range).tint(accent).controlSize(.small)
            Text("\(Int(value.wrappedValue * multiplier)) \(suffix)").font(.system(size:10)).monospacedDigit().frame(width:49,alignment:.trailing)
        }.help(Text(help))
    }
    private func color(_ rgb: RGB) -> Color { Color(red: rgb.red, green: rgb.green, blue: rgb.blue) }
    private func rgb(_ color: Color) -> RGB {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .orange
        return RGB(ns.redComponent, ns.greenComponent, ns.blueComponent)
    }
    private var style: FlostedCore.BackgroundStyle {
        var style = FlostedCore.BackgroundStyle(); style.first = rgb(first); style.second = rgb(second)
        style.gradient = gradient; style.third = third; style.aspect = aspect; style.padding = padding; style.cornerRadius = radius; style.shadow = shadow
        return style
    }
    private var previewKey: String { "\(padding)|\(radius)|\(shadow)|\(gradient)|\(first)|\(second)|\(String(describing:third))|\(aspect)|\(quality)|\(scale)|\(backdropVersion)" }
    private func applyPreset(_ index:Int) {
        selectedPreset=index;gradient=true;backdrop=nil;backdropVersion += 1;first=color(presets[index].0);second=color(presets[index].1)
        third=index == 0 ? RGB(0.35,0.22,0.86) : nil
    }
    private func reset() {
        if action == .crop { ratio=0;selection=CGRect(x:0,y:0,width:1,height:1) }
        else if action == .background { padding=80;radius=28;shadow=24;aspect=0;applyPreset(0) }
        else { quality=0.8;scale=1;targetKB=0 }
    }
    private func chooseBackdrop() {
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        if panel.runModal() == .OK,let url=panel.url {
            Task {
                do { let decoded=try await Task.detached { try ImageConverter.decode(url) }.value
                    backdrop=decoded;backdropVersion += 1;selectedPreset = -2
                } catch { errorMessage=error.localizedDescription }
            }
        }
    }
    private func resizeCrop(width:Int?,height:Int?) {
        var w=Double(max(1,min(width ?? Int(selection.width*Double(image.width)),image.width)))
        var h=Double(max(1,min(height ?? Int(selection.height*Double(image.height)),image.height)))
        if ratio > 0 { if width != nil { h=w/ratio } else { w=h*ratio } }
        let fit=min(1,min(Double(image.width)/w,Double(image.height)/h));w=w*fit/Double(image.width);h=h*fit/Double(image.height)
        selection=CGRect(x:min(max(0,selection.midX-w/2),1-w),y:min(max(0,selection.midY-h/2),1-h),width:w,height:h)
    }
    private func resetSelection(ratio: Double) {
        guard ratio > 0 else { return }
        let imageRatio = Double(image.width) / Double(image.height)
        let width = min(1, ratio / imageRatio), height = min(1, imageRatio / ratio)
        selection = CGRect(x: (1-width)/2, y: (1-height)/2, width: width, height: height)
    }
    private func updatePreview() async {
        guard action != .crop else { return }
        let currentStyle = style, q = quality, s = scale, source = image, tool = action, backdropImage = backdrop
        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> (CGImage, Int) in
                if tool == .background { return (try ImageTools.background(source, style: currentStyle, backdrop:backdropImage, previewLimit: 1000), 0) }
                let scaled = try ImageTools.resize(source, scale: s)
                let data = try ImageConverter.encode(scaled, as: .jpg, quality: q)
                guard let decoded = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw ConversionError.encoding }
                return (decoded, data.count)
            }.value
            guard !Task.isCancelled else { return }
            preview = NSImage(cgImage: result.0, size: .zero); compressedBytes = result.1
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
    }
    private func save() {
        guard !saving else { return }; saving = true
        let source = image, selected = selection, currentStyle = style, q = quality, s = scale, limit = max(0, min(targetKB, 1_000_000)), tool = action, input = file, backdropImage=backdrop
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { () -> URL in
                    let data: Data, ext: String, suffix: String
                    switch tool {
                    case .crop:
                        data = try ImageConverter.encode(ImageTools.crop(source, selection: selected), as: .png); ext = "png"; suffix = "cropped"
                    case .background:
                        data = try ImageConverter.encode(ImageTools.background(source, style: currentStyle, backdrop:backdropImage), as: .png); ext = "png"; suffix = "background"
                    default:
                        let scaled = try ImageTools.resize(source, scale: s)
                        var encoded = try ImageConverter.encode(scaled, as: .jpg, quality: q)
                        if limit > 0, encoded.count > limit * 1000 {
                            var low = 0.05, high = q
                            var best = try ImageConverter.encode(scaled, as: .jpg, quality: low)
                            guard best.count <= limit * 1000 else { throw SizeLimitError() }
                            for _ in 0..<8 {
                                let mid = (low + high) / 2
                                let attempt = try ImageConverter.encode(scaled, as: .jpg, quality: mid)
                                if attempt.count <= limit * 1000 { best = attempt; low = mid } else { high = mid }
                            }
                            encoded = best
                        }
                        data = encoded; ext = "jpg"; suffix = "compressed"
                    }
                    return try OutputWriter.write(data, beside: input, suffix: suffix, extension: ext)
                }.value
                saving = false; completed(output)
            } catch { saving = false; errorMessage = error.localizedDescription }
        }
    }
}
private struct SizeLimitError: LocalizedError {
    var errorDescription: String? { tr("error.sizeLimit") }
}

struct CropCanvas: NSViewRepresentable {
    let image: CGImage
    @Binding var selection: CGRect
    let ratio: Double
    func makeNSView(context: Context) -> CropSelectionView { CropSelectionView(frame: .zero) }
    func updateNSView(_ view: CropSelectionView, context: Context) {
        view.image = image; view.selection = selection; view.ratio = ratio
        view.changed = { selection = $0 }; view.needsDisplay = true
    }
}
final class CropSelectionView: NSView {
    var image: CGImage?
    var selection = CGRect(x: 0, y: 0, width: 1, height: 1)
    var ratio = 0.0
    var changed: ((CGRect) -> Void)?
    private var anchor: CGPoint?
    private var imageRect: CGRect {
        guard let image else { return .zero }
        let factor = min(bounds.width / Double(image.width), bounds.height / Double(image.height))
        let size = CGSize(width: Double(image.width) * factor, height: Double(image.height) * factor)
        return CGRect(x: bounds.midX-size.width/2, y: bounds.midY-size.height/2, width: size.width, height: size.height)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(point) else { return }; anchor = clamped(point)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        var end = clamped(convert(event.locationInWindow, from: nil))
        if ratio > 0 {
            let dx = end.x-anchor.x, dy = end.y-anchor.y
            let width = min(abs(dx), abs(dy) * ratio)
            end = CGPoint(x: anchor.x + (dx < 0 ? -width : width), y: anchor.y + (dy < 0 ? -width/ratio : width/ratio))
        }
        let rect = CGRect(x: min(anchor.x,end.x), y: min(anchor.y,end.y), width: abs(end.x-anchor.x), height: abs(end.y-anchor.y))
        guard rect.width >= 2, rect.height >= 2 else { return }
        let area = imageRect
        selection = CGRect(x: (rect.minX-area.minX)/area.width, y: (rect.minY-area.minY)/area.height, width: rect.width/area.width, height: rect.height/area.height)
        changed?(selection); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) { anchor = nil }
    private func clamped(_ point: CGPoint) -> CGPoint {
        let rect = imageRect
        return CGPoint(x: min(rect.maxX,max(rect.minX,point.x)), y: min(rect.maxY,max(rect.minY,point.y)))
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }
        let area = imageRect
        context.draw(image, in: area)
        let crop = CGRect(x: area.minX + selection.minX*area.width, y: area.minY + selection.minY*area.height,
            width: selection.width*area.width, height: selection.height*area.height)
        let mask = NSBezierPath(rect: area); mask.appendRect(crop); mask.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.55).setFill(); mask.fill()
        let orange=NSColor(calibratedRed:0.89,green:0.23,blue:0,alpha:1)
        orange.setStroke(); let border = NSBezierPath(rect: crop); border.lineWidth = 1.5; border.stroke()
        for point in [CGPoint(x:crop.minX,y:crop.minY),CGPoint(x:crop.maxX,y:crop.minY),CGPoint(x:crop.minX,y:crop.maxY),CGPoint(x:crop.maxX,y:crop.maxY)] {
            orange.setFill(); NSBezierPath(roundedRect: CGRect(x:point.x-4,y:point.y-4,width:8,height:8), xRadius:2,yRadius:2).fill()
        }
        for rect in [CGRect(x:crop.midX-9,y:crop.minY-2,width:18,height:4),CGRect(x:crop.midX-9,y:crop.maxY-2,width:18,height:4),CGRect(x:crop.minX-2,y:crop.midY-9,width:4,height:18),CGRect(x:crop.maxX-2,y:crop.midY-9,width:4,height:18)] {
            orange.setFill();NSBezierPath(roundedRect:rect,xRadius:2,yRadius:2).fill()
        }
    }
}
