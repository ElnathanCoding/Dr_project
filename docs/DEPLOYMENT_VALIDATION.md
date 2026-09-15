# Deployment validation

## Frozen pipeline

`Fundus -> Modality -> Image quality -> DR scope -> P0 -> E03`

A stopped image never receives an issued DR stage. Research-only shadow E03
output does not override an abstention.

## Platform runtimes

Android:
- TensorFlow Lite 2.16.1
- OpenCV 5.0.0
- 4 inference threads

Windows:
- TensorFlow Lite `2.20.0-dev0+selfbuilt`
- OpenCV 5.0.0
- SELECT_TF_OPS / Flex enabled

## TRAIN-only deployment parity

A deterministic 25-image TRAIN-only set passed:
- decision parity
- gate-score strict tolerance `<= 1e-4`
- E03/shadow class-index parity
- P0 geometry parity

No validation or locked-test images were accessed for this parity checkpoint.

## Final release identities

- `main.dart`: `2E1043170F5E0929FB7E646FF64932FB46F78DBB8AB26BE5EA26BF0B2573F5FF`
- Windows release tree: `D0EEF8B179AB8C0E7E6180A1E852522B3FFB1B89113C893647563D9D3AF69804`
- Windows ZIP: `1B7450B5C91D6A1D99041970094510957AF7EA2F8C3DC23C65EED62B6045402E`
- Android APK: `C4DCA6AB7D7A956C6E122850FDA19A635CA8C9A3CF3647CC5AE60587B40ACCF9`

Probability outputs are not claimed to be bit-exact across operating systems.
