// Copyright © 2023 Vyr Cossont. All rights reserved.

import Combine
import Foundation

public class OrbOfShame: ObservableObject {
    @Published public var shame: CGFloat = 0

    private var internalShame: Double = 0
    private var newShame: Double = 0

    private var maxReportedShame: Double = 10
    private var clampUnder: Double = 1
    private var alpha: Double = 0.1

    private var cancellables: Set<AnyCancellable> = Set()

    public init() {
        Timer
            .publish(every: 0.1, on: .main, in: .default)
            .autoconnect()
            .sink { [self] _ in
                internalShame = alpha * newShame + (1 - alpha) * internalShame
                newShame = 0
                let clampedToMax = min(
                    internalShame,
                    maxReportedShame
                )
                shame = CGFloat(
                    clampedToMax < clampUnder
                        ? 0
                        : clampedToMax
                )
            }
            .store(in: &cancellables)
    }

    public func increment() {
        newShame += 100
    }
}

class OrbDelegate: NSObject, URLSessionTaskDelegate {
    private let orb: OrbOfShame

    init(orb: OrbOfShame) {
        self.orb = orb
        super.init()
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        orb.increment()
    }
}
