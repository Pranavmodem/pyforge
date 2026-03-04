# Passport Studio

Crop, rotate, and resize a portrait on a Mac. PNG is convenient for a preview.
JPEG export uses a white background. The encoder writes a new image without
copying the input metadata.

```sh
swiftc passport.swift -o passport-studio
./passport-studio input.jpg preview.png 600 600
./passport-studio input.jpg output.jpg 600 600 1
```

The last argument is an optional number of clockwise quarter-turns. After
rotation, optionally supply a top-left crop as `X,Y,W,H` in source pixels.
Without a crop, the tool uses the largest centered crop at the output ratio.
Set dimensions from the requirements applicable to the intended submission.
This tool checks crop geometry and pixel dimensions.

Run the local export test with `sh tests/smoke.sh`.
