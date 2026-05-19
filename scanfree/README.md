# ScanFree

Convert ordered page images to a searchable PDF on a Mac. The PDF keeps
the page images and adds a text layer recognized locally by Apple Vision.

```sh
swiftc scan.swift -o scanfree
./scanfree document.pdf page-one.png page-two.png
```

Input images are oriented from their image metadata and scaled to a working
resolution. Input order controls page order. OCR quality depends on lighting,
legibility, and the supported recognition languages. The command accepts
image files from disk.

Pass `--grayscale` before the output path for monochrome pages. Run the
local PDF test with `sh tests/smoke.sh`.
