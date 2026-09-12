# Attribution

Thanks to Sam Henri Gold for publicly documenting and demonstrating the MacBook lid-angle sensor in [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor), published under Apache License 2.0.

Macbook Duo builds on the MIT-licensed Mac Duo codebase; the license text is in [LICENSE](LICENSE). The lid-angle sensor reader, the effects and the controls were developed in that lineage, and Macbook Duo continues it under the same license with six additional effects, per-effect options and a redesigned settings window.

The sensor reader's device identifiers (Sensor page 0x20, Orientation usage 0x8A), feature-report ID 1, and two-byte little-endian degree value were verified against the LidAngleSensor project and against Apple-silicon MacBook hardware. No audio or other assets from that project are included.

Bendy and the public demonstrations by Adrian Abelarde and Seb Vidal are visual and architectural references, not dependencies. This project is not affiliated with those developers or Apple.

The study notes below are carried over unchanged from that lineage. The version numbers in their headings refer to the earlier project's releases, and the notices and license text they contain are retained verbatim.

## Effect study for 0.1.2

The user's supplied Bendy demonstration video was studied alongside [FrostFold](https://github.com/askmaddyy/FrostFold/tree/a9af51a5565b7d75525c7aab84f2add96d0669ae) (MIT) and [iphone-solo](https://github.com/soloiaros/iphone-solo/tree/752764bdf68ca16d55b65c76738c23d4266b1137) (no license file present in the studied tree). They informed the discussion of stationary content, tilted glass, and multiscale defocus. Their source, graphics, and videos are not bundled in the app or the source distribution. The shipped Metal implementation is original, with a bottom-anchored expansion and a binomial blur pyramid, developed after an independent Claude Opus 5 review.

These projects are independent recreations. They do not establish how Apple implemented its animation. Macbook Duo aims for its own responsive visual treatment rather than a claim of pixel-identical reproduction.

## Ghost resting-plane study for 0.1.12

Thanks to [Ansh Varshney’s Macbook-duo demonstration](https://github.com/anshvarshney1502/Macbook-duo) and the upstream [Lid Plane by Jhey](https://github.com/jh3y/lid-plane) for clarifying the stationary-viewer projection: a moving panel samples a desktop plane anchored at the last resting angle. Macbook-duo distributes a packaged app; the readable implementation is in its upstream project. No reference binaries, videos or artwork are included.

Ghost applies that geometric approach with Macbook Duo’s existing blur pyramid, separate physical-angle state, gradual onset and shared animated clearing. The upstream MIT notice is retained below for the projection study and adaptation.

> MIT License
>
> Copyright (c) 2026 Jhey
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
