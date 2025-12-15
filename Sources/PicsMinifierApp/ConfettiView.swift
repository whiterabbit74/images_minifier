import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    let counter: Int // Change this to trigger new burst

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                var contextCopy = context
                let rect = CGRect(x: particle.x, y: particle.y, width: particle.size, height: particle.size)
                
                contextCopy.opacity = particle.opacity
                contextCopy.translateBy(x: rect.midX, y: rect.midY)
                contextCopy.rotate(by: Angle(degrees: particle.rotation))
                contextCopy.translateBy(x: -rect.midX, y: -rect.midY)
                
                contextCopy.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(particle.color)
                )
            }
        }
        .onReceive(timer) { _ in
            updateParticles()
        }
        .onChange(of: counter) { _ in
            burst()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func burst() {
        for _ in 0..<100 {
            particles.append(ConfettiParticle())
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            particles[i].x += particles[i].speedX
            particles[i].y += particles[i].speedY
            particles[i].rotation += particles[i].spin
            particles[i].speedY += 0.5 // Gravity
            particles[i].opacity -= 0.01 // Fade out
        }
        particles.removeAll(where: { $0.y > 2000 || $0.opacity <= 0 })
    }
}

struct ConfettiParticle {
    var x: Double = Double.random(in: 0...1000) // Will be reset on init properly if passed size, but simplified here
    var y: Double = -100
    var size: Double = Double.random(in: 6...12)
    var speedX: Double = Double.random(in: -5...5)
    var speedY: Double = Double.random(in: 5...15)
    var rotation: Double = Double.random(in: 0...360)
    var spin: Double = Double.random(in: -5...5)
    var opacity: Double = 1.0
    var color: Color = [.red, .blue, .green, .yellow, .pink, .purple, .orange].randomElement()!
    
    init() {
        x = Double.random(in: 0...600)
        y = Double.random(in: -100...0)
    }
}
