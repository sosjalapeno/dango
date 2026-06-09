import SwiftUI

struct MenuBarIconView: View {

    let completedSessions: Int
    let completedBreaks: Int
    let activeProgress: Double
    let phase: PomodoroPhase
    let timerState: TimerState
    let breakProgress: Double

    // MARK: - Shared Layout Ratios (must match DangoVisualizerView)

    private let stickInsetRatio: CGFloat = 0.03
    private let blockWidthRatio: CGFloat = 0.68
    private let ballSpacingRatio: CGFloat = 0.02

    private let skewerWidth: CGFloat = 1.0
    private let ballStrokeWidth: CGFloat = 1.0
    private let sauceStrokeWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let leadingInset = size.width * stickInsetRatio
            let blockMaxX = size.width - leadingInset
            let blockWidth = size.width * blockWidthRatio
            let spacing = blockWidth * ballSpacingRatio
            let ballDiameter = (blockWidth - 3 * spacing) / 4
            let radius = ballDiameter / 2
            let blockMinX = blockMaxX - blockWidth

            let centers: [CGPoint] = (0..<4).map { i in
                CGPoint(x: blockMinX + radius + CGFloat(i) * (ballDiameter + spacing), y: midY)
            }

            let count = activeBallsCount

            drawStick(in: &context, centers: centers, radius: radius, visibleCount: count,
                      leadingInset: leadingInset, blockMaxX: blockMaxX, midY: midY)

            guard count > 0 else { return }

            let completed = completedSessions
            let breaks = completedBreaks
            let focusProgress = phase.isFocus ? activeProgress : 0.0
            let sauceProgress = phase.isBreak ? breakProgress : 0.0

            for i in 0..<count {
                let center = centers[i]

                if case .longBreak = phase {
                    drawSolidBall(in: &context, center: center, radius: radius)
                    drawSauceOverlay(in: &context, center: center, radius: radius, progress: 1.0)
                    continue
                }

                if i < completed {
                    drawSolidBall(in: &context, center: center, radius: radius)

                    if i < breaks {
                        drawSauceOverlay(in: &context, center: center, radius: radius, progress: 1.0)
                    }

                    if phase.isBreak && i == completed - 1 && i >= breaks {
                        drawSauceOverlay(in: &context, center: center, radius: radius, progress: sauceProgress)
                    }
                } else if i == completed && phase.isFocus {
                    drawFillingBall(in: &context, center: center, radius: radius, progress: focusProgress)
                }
            }
        }
        .opacity(timerState == .running ? 1.0 : 0.5)
        .animation(nil, value: timerState)
        .frame(width: 48, height: 18)
    }

    // MARK: - Canvas Drawing

    private var activeBallsCount: Int {
        switch phase {
        case .idle:
            return 0
        case .focus(let session):
            return session
        case .shortBreak(let after):
            return after
        case .longBreak:
            let ballsEaten = Int(activeProgress * 4.0)
            return max(0, 4 - ballsEaten)
        }
    }

    private func drawStick(
        in context: inout GraphicsContext,
        centers: [CGPoint],
        radius: CGFloat,
        visibleCount: Int,
        leadingInset: CGFloat,
        blockMaxX: CGFloat,
        midY: CGFloat
    ) {
        guard visibleCount > 0 else {
            drawSegment(in: &context, from: leadingInset, to: blockMaxX, y: midY)
            return
        }

        drawSegment(in: &context, from: leadingInset, to: centers[0].x - radius, y: midY)

        for i in 0..<(visibleCount - 1) {
            drawSegment(in: &context, from: centers[i].x + radius, to: centers[i + 1].x - radius, y: midY)
        }

        drawSegment(in: &context, from: centers[visibleCount - 1].x + radius, to: blockMaxX, y: midY)
    }

    private func drawSegment(in context: inout GraphicsContext, from x1: CGFloat, to x2: CGFloat, y: CGFloat) {
        guard x2 > x1 else { return }
        let segment = Path { p in
            p.move(to: CGPoint(x: x1, y: y))
            p.addLine(to: CGPoint(x: x2, y: y))
        }
        context.stroke(segment, with: .color(.black), lineWidth: skewerWidth)
    }

    private func circlePath(center: CGPoint, radius: CGFloat, insetForStroke lineWidth: CGFloat = 0) -> Path {
        let r = radius - lineWidth / 2
        return Path(ellipseIn: CGRect(
            x: center.x - r,
            y: center.y - r,
            width: r * 2,
            height: r * 2
        ))
    }

    private func drawSolidBall(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        context.fill(circlePath(center: center, radius: radius), with: .color(.black))
    }

    private func drawFillingBall(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, progress: Double) {
        let strokePath = circlePath(center: center, radius: radius, insetForStroke: ballStrokeWidth)
        context.stroke(strokePath, with: .color(.black), lineWidth: ballStrokeWidth)

        guard progress > 0 else { return }

        let fillWidth = radius * 2 * CGFloat(progress)
        let clipRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: fillWidth,
            height: radius * 2
        )

        var layerCtx = context
        layerCtx.clip(to: Path(clipRect))
        layerCtx.blendMode = .copy
        layerCtx.fill(circlePath(center: center, radius: radius), with: .color(.black))
    }

    private func drawSauceOverlay(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, progress: Double) {
        guard progress > 0 else { return }

        let startY = center.y - radius
        let endY = center.y + radius
        let cpYOffset = radius * 0.333
        let cpXOffset = radius * 0.6

        var wavePath = Path()
        wavePath.move(to: CGPoint(x: center.x, y: startY))

        wavePath.addCurve(
            to: CGPoint(x: center.x, y: center.y),
            control1: CGPoint(x: center.x + cpXOffset, y: startY + cpYOffset),
            control2: CGPoint(x: center.x + cpXOffset, y: center.y - cpYOffset)
        )
        wavePath.addCurve(
            to: CGPoint(x: center.x, y: endY),
            control1: CGPoint(x: center.x - cpXOffset, y: center.y + cpYOffset),
            control2: CGPoint(x: center.x - cpXOffset, y: endY - cpYOffset)
        )

        let trimmedPath = wavePath.trimmedPath(from: 0, to: CGFloat(progress))

        var eraseCtx = context
        eraseCtx.clip(to: circlePath(center: center, radius: radius))
        eraseCtx.blendMode = .destinationOut

        let style = StrokeStyle(lineWidth: sauceStrokeWidth, lineCap: .round, lineJoin: .round)
        eraseCtx.stroke(trimmedPath, with: .color(.black), style: style)
    }
}
