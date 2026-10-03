import StageKit
import StageCore

// The round's executable: the Stage with this round's specimens.
//   swift run HatchStageToast --demo
// opens the Stage on the sample manifest with the in-memory data source, so it runs without Hatch.
MainActor.assumeIsolated {
    StageApp.run(provider: ToastProvider(), manifest: ToastManifest.load())
}
