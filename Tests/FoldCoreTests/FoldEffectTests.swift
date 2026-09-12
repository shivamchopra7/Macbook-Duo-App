import Testing
@testable import FoldCore

@Test func duoIsTheDefaultAndUnknownSelectionsFallBackToIt() {
    #expect(FoldEffect.fallback == .duo)
    #expect(FoldEffect.resolve(persisted:nil) == .duo)
    #expect(FoldEffect.resolve(persisted:"") == .duo)
    #expect(FoldEffect.resolve(persisted:"Duo") == .duo)          // Identifiers are lower case.
    #expect(FoldEffect.resolve(persisted:"origami") == .duo)
    #expect(FoldEffect.resolve(persisted:"kaleidoscope") == .duo)
    #expect(FoldEffect.resolve(shaderIndex:12) == .duo)
    #expect(FoldEffect.resolve(shaderIndex:.max) == .duo)
}

@Test func persistedIdentifiersAndShaderIndicesAreStable() {
    #expect(FoldEffect.allCases.map(\.persistedIdentifier) == ["duo","ghost","roll","shutter","flex","iris","fold","accordion","louver","card","curtain","ripple"])
    #expect(FoldEffect.allCases.map(\.shaderIndex) == [0,5,1,2,3,4,6,7,8,9,10,11])
    for effect in FoldEffect.allCases {
        #expect(FoldEffect.resolve(persisted:effect.persistedIdentifier) == effect)
        #expect(FoldEffect.resolve(shaderIndex:effect.shaderIndex) == effect)
        #expect(effect.persistedIdentifier == effect.rawValue)
        #expect(effect.id == effect.rawValue)
    }
    #expect(Set(FoldEffect.allCases.map(\.shaderIndex)).count == FoldEffect.allCases.count)
    #expect(Set(FoldEffect.allCases.map(\.title)).count == FoldEffect.allCases.count)
}

@Test func everyEffectIsPresentableAndFlatEffectsKeepTheSharpPath() {
    #expect(FoldEffect.allCases.count == 12)
    for effect in FoldEffect.allCases {
        #expect(!effect.title.isEmpty)
        #expect(!effect.symbol.isEmpty)
        #expect(effect.summary.hasSuffix("."))
        #expect(effect.needsPrefilteredSource == (effect != .duo))
    }
}

/// The angle drives every effect through the same mapping, so a selection can
/// never change when the desktop is untouched or fully closed.
@Test func effectSelectionDoesNotChangeTheAngleContract() {
    for effect in FoldEffect.allCases {
        #expect(effect.shaderIndex <= 11)
        #expect(FoldMath.progress(angle:105,clearAngle:105) == 0)
        #expect(FoldMath.progress(angle:5,clearAngle:105) == 1)
    }
}

@Test func expansionEffectsAreFlaggedAndSegmentedEffectsAreKnown() {
    let originals: Set<FoldEffect> = [.duo,.ghost,.roll,.shutter,.flex,.iris]
    for effect in FoldEffect.allCases {
        #expect(effect.isExpansion == !originals.contains(effect))
        #expect(effect.symbol.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." })
    }
    #expect(FoldEffect.allCases.filter(\.usesSegments) == [.shutter,.accordion,.louver,.curtain])
    #expect(FoldEffect.allCases.filter(\.isExpansion).count == 6)
}
