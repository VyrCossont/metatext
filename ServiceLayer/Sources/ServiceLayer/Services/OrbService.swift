// Copyright © 2023 Vyr Cossont. All rights reserved.

public struct OrbService {
    public let orb: OrbOfShame

    public init(environment: AppEnvironment) {
        self.orb = environment.orb
    }
}
